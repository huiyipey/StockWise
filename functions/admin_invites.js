const {HttpsError} = require('firebase-functions/v2/https');

function createAdminInviteHandler({db, auth, serverTimestamp}) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const storeId = request.data?.storeId;
    if (typeof storeId !== 'string' || !/^[\w-]{1,128}$/.test(storeId)) {
      throw new HttpsError('invalid-argument', 'Select a store.');
    }
    const store = db.collection('stores').doc(storeId);
    const caller = (await store.collection('members').doc(request.auth.uid).get()).data();
    if (caller?.isActive !== true || !['owner', 'admin'].includes(caller.role)) {
      throw new HttpsError('permission-denied', 'Store admin access is required.');
    }
    const email = typeof request.data?.email === 'string' ? request.data.email.trim().toLowerCase() : '';
    if (!/^[^@\s/]+@[^@\s/]+\.[^@\s/]+$/.test(email) || email.length > 254) {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }
    const missingEmail = () => new HttpsError('not-found',
      'This email does not exist. Please enter a valid email.', {reason: 'email-not-found'});
    let account;
    try {
      account = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') throw missingEmail();
      throw error;
    }
    if (account.disabled) throw missingEmail();
    if (account.uid === request.auth.uid) {
      throw new HttpsError('already-exists', 'You already have store access.');
    }
    const member = (await store.collection('members').doc(account.uid).get()).data();
    if (member?.isActive === true) {
      throw new HttpsError('already-exists', 'This person already has store access.');
    }
    await store.collection('adminInvites').doc(email).set({
      storeId,
      emailLowercase: email,
      role: 'admin',
      status: 'pending',
      invitedBy: request.auth.uid,
      invitedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, {merge: true});
    return {invited: true};
  };
}

module.exports = {createAdminInviteHandler};
