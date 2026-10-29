const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');

const WINDOW_MS = 10 * 60 * 1000;
const MAX_LOOKUPS = 60;

function createEmailRegistrationHandler({db, auth, now = Date.now}) {
  return async request => {
    const email = typeof request.data?.email === 'string'
      ? request.data.email.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }
    // Use the server's connection metadata, never an IP supplied in callable data.
    const ip = request.rawRequest?.ip;
    if (typeof ip !== 'string' || !ip) {
      throw new HttpsError('unavailable', 'Unable to check this email. Please try again.');
    }
    const key = createHash('sha256').update(ip).digest('hex');
    const quota = db.collection('authLookupLimits').doc(key);
    const time = now();
    await db.runTransaction(async tx => {
      const current = (await tx.get(quota)).data();
      const active = Number.isFinite(current?.windowStart)
        && current.windowStart <= time && current.windowStart > time - WINDOW_MS;
      const count = active && Number.isInteger(current.count) ? current.count : 0;
      if (count >= MAX_LOOKUPS) {
        throw new HttpsError('resource-exhausted', 'Too many attempts. Please try again later.');
      }
      // Private server-only record: no raw IP, email, UID or account information.
      tx.set(quota, {
        windowStart: active ? current.windowStart : time,
        count: count + 1,
        expiresAt: new Date(time + WINDOW_MS),
      });
    });
    try {
      await auth.getUserByEmail(email);
      return {registered: true};
    } catch (failure) {
      if (failure.code === 'auth/user-not-found') return {registered: false};
      throw new HttpsError('unavailable', 'Unable to check this email. Please try again.');
    }
  };
}

module.exports = {createEmailRegistrationHandler, WINDOW_MS, MAX_LOOKUPS};
