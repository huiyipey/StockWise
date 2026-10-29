const {HttpsError} = require('firebase-functions/v2/https');

const LEGACY_CLAIM = 'stockwise_legacy_account';
const COOLDOWN_MS = 60 * 1000;
const WINDOW_MS = 60 * 60 * 1000;
const MAX_SENDS = 10;
const RECENT_SIGN_IN_MS = 5 * 60 * 1000;

function canAccessAccount(user) {
  return !user.disabled && (user.emailVerified === true || user.customClaims?.[LEGACY_CLAIM] === true);
}

function withVerifiedAccount(auth, handler) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const user = await auth.getUser(request.auth.uid);
    if (!canAccessAccount(user)) {
      throw new HttpsError('permission-denied', 'Verify your email before continuing.', {reason: 'email-unverified'});
    }
    return handler(request);
  };
}

function statusFor(user, state, time) {
  return {
    email: user.email,
    verified: user.emailVerified === true,
    attempted: state?.attempted === true,
    deliveryFailed: state?.deliveryFailed === true,
    resendAfter: Math.max(0, Math.ceil(((state?.nextSendAt || 0) - time) / 1000)),
  };
}

function deliveryError(message) {
  if (/TOO_MANY_ATTEMPTS|QUOTA_EXCEEDED|TOO_MANY_REQUESTS/.test(message)) {
    return new HttpsError('resource-exhausted', 'Too many requests. Please try again later.', {retryAfter: 60});
  }
  if (/CREDENTIAL_TOO_OLD|TOKEN_EXPIRED|REQUIRES_RECENT_LOGIN/.test(message)) {
    return new HttpsError('failed-precondition', 'Please confirm your password to change your email.', {reason: 'requires-recent-login'});
  }
  if (/EMAIL_EXISTS|EMAIL_ALREADY_IN_USE/.test(message)) {
    return new HttpsError('already-exists', 'An account already uses this email.', {field: 'email'});
  }
  if (/INVALID_NEW_EMAIL|INVALID_EMAIL/.test(message)) {
    return new HttpsError('invalid-argument', 'Enter a valid email address.', {field: 'email'});
  }
  if (/USER_DISABLED|USER_NOT_FOUND|INVALID_ID_TOKEN/.test(message)) {
    return new HttpsError('unauthenticated', 'Please sign in again.');
  }
  return new HttpsError('unavailable', 'Could not send the email. Please try again.');
}

function createVerificationHandler({db, auth, sendEmail, now = Date.now}) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const user = await auth.getUser(request.auth.uid);
    if (user.disabled || !user.email) throw new HttpsError('unauthenticated', 'Please sign in again.');
    const action = request.data?.action;
    const ref = db.collection('emailVerificationSessions').doc(user.uid);
    if (action === 'status') return statusFor(user, (await ref.get()).data(), now());
    if (!['send', 'change'].includes(action)) throw new HttpsError('invalid-argument', 'Choose a verification action.');
    if (user.emailVerified) return statusFor(user, null, now());
    if (request.auth.token?.email?.toLowerCase() !== user.email.toLowerCase()) {
      throw new HttpsError('unauthenticated', 'Please sign in again.');
    }

    let newEmail;
    if (action === 'change') {
      newEmail = request.data?.email;
      if (typeof newEmail !== 'string') throw new HttpsError('invalid-argument', 'Enter a valid email address.', {field: 'email'});
      newEmail = newEmail.trim().toLowerCase();
      if (newEmail.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(newEmail)) {
        throw new HttpsError('invalid-argument', 'Enter a valid email address.', {field: 'email'});
      }
      if (user.customClaims?.[LEGACY_CLAIM] === true) {
        throw new HttpsError('failed-precondition', 'This action is only available while completing signup.');
      }
      const authenticatedAt = request.auth.token?.auth_time * 1000;
      if (!Number.isFinite(authenticatedAt) || now() - authenticatedAt > RECENT_SIGN_IN_MS
          || authenticatedAt > now() + 60000) {
        throw new HttpsError('failed-precondition', 'Please confirm your password to change your email.', {reason: 'requires-recent-login'});
      }
      // Auth.updateUser also checks uniqueness atomically when saving the address.
      try {
        const existing = await auth.getUserByEmail(newEmail);
        if (existing.uid !== user.uid) throw new HttpsError('already-exists', 'An account already uses this email.', {field: 'email'});
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
      }
    }

    const time = now();
    const claimed = await db.runTransaction(async tx => {
      const state = (await tx.get(ref)).data() || {};
      if (state.nextSendAt > time) {
        throw new HttpsError('resource-exhausted', 'Please wait before requesting another email.', {
          reason: 'cooldown', retryAfter: Math.ceil((state.nextSendAt-time)/1000),
        });
      }
      const sameWindow = time - (state.windowStart || 0) < WINDOW_MS;
      const count = sameWindow ? (state.sendCount || 0) : 0;
      const reservedDelivery = action === 'send' && state.deliveryPending === true && state.pendingEmail === user.email;
      if (count >= MAX_SENDS && !reservedDelivery) {
        throw new HttpsError('resource-exhausted', 'Too many requests. Please try again later.', {
          retryAfter: Math.ceil((state.windowStart+WINDOW_MS-time)/1000),
        });
      }
      const attempt = (state.attempt || 0) + 1;
      const next = {...state, attempted: true, attempt, nextSendAt: time+COOLDOWN_MS,
        deliveryPending: false,
        windowStart: sameWindow ? state.windowStart : time, sendCount: count+(reservedDelivery ? 0 : 1)};
      tx.set(ref, next);
      return {attempt, target: newEmail || user.email};
    });
    try {
      if (action === 'change' && claimed.target !== user.email.toLowerCase()) {
        // Mint first so a signing configuration failure cannot leave the caller's
        // email changed without a way to continue the same authenticated session.
        const signInToken = await auth.createCustomToken(user.uid);
        const updatedUser = await auth.updateUser(user.uid, {email: claimed.target, emailVerified: false});
        await db.runTransaction(async tx => {
          const state = (await tx.get(ref)).data();
          if (state?.attempt === claimed.attempt) {
            tx.set(ref, {...state, pendingEmail: updatedUser.email, attempted: false,
              deliveryPending: true, deliveryFailed: false, nextSendAt: 0});
          }
        });
        // Updating an Auth email revokes its former session. The app exchanges
        // this UID-bound token, then sends VERIFY_EMAIL using the new identity.
        return {...statusFor(updatedUser, (await ref.get()).data(), now()), signInToken};
      }
      // Use the caller's validated token. No client-supplied UID, token or verification flag is trusted.
      const bearer = request.rawRequest?.headers?.authorization;
      if (typeof bearer !== 'string' || !bearer.startsWith('Bearer ')) throw new HttpsError('unauthenticated', 'Please sign in again.');
      await sendEmail({idToken: bearer.slice(7), newEmail: claimed.target !== user.email.toLowerCase() ? claimed.target : undefined});
      await db.runTransaction(async tx => {
        const state = (await tx.get(ref)).data();
        if (state?.attempt === claimed.attempt) {
          tx.set(ref, {...state, pendingEmail: claimed.target, deliveryFailed: false});
        }
      });
      return statusFor(user, (await ref.get()).data(), now());
    } catch (error) {
      const failure = error instanceof HttpsError ? error
        : error.code === 'auth/email-already-exists'
          ? new HttpsError('already-exists', 'An account already uses this email.', {field: 'email'})
          : deliveryError(error.message || '');
      await db.runTransaction(async tx => {
        const state = (await tx.get(ref)).data();
        if (state?.attempt === claimed.attempt) {
          tx.set(ref, {...state, deliveryFailed: true, nextSendAt: failure.code === 'resource-exhausted'
            ? now()+(failure.details?.retryAfter || 60)*1000 : 0});
        }
      });
      throw failure;
    }
  };
}

function identityEmailSender({apiKey, fetchImpl = fetch}) {
  return async ({idToken, newEmail}) => {
    const response = await fetchImpl(`https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`, {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({requestType: newEmail ? 'VERIFY_AND_CHANGE_EMAIL' : 'VERIFY_EMAIL', idToken,
        continueUrl: 'https://stockwise-190a9.web.app/?mode=returnToApp',
        ...(newEmail ? {newEmail} : {})}), signal: AbortSignal.timeout(20000),
    });
    const result = await response.json();
    if (!response.ok) throw deliveryError(result.error?.message || '');
  };
}

module.exports = {LEGACY_CLAIM, COOLDOWN_MS, WINDOW_MS, MAX_SENDS, canAccessAccount,
  withVerifiedAccount, createVerificationHandler, identityEmailSender};
