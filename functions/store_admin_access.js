const {HttpsError} = require('firebase-functions/v2/https');
const {isAdminRole, isActiveStoreAdmin} = require('./store_roles');

function setStoreAdminActiveHandler({db, serverTimestamp}) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const {storeId, userId, isActive} = request.data ?? {};
    if (typeof storeId !== 'string' || !/^[\w-]{1,128}$/.test(storeId)
        || typeof userId !== 'string' || !userId || userId.length > 128 || userId.includes('/')
        || typeof isActive !== 'boolean') {
      throw new HttpsError('invalid-argument', 'Select an admin and a valid access setting.');
    }
    const store = db.collection('stores').doc(storeId);
    const members = store.collection('members');
    return db.runTransaction(async tx => {
      const [caller, target] = await Promise.all([
        tx.get(members.doc(request.auth.uid)), tx.get(members.doc(userId)),
      ]);
      if (!isActiveStoreAdmin(caller.data())) {
        throw new HttpsError('permission-denied', 'Store admin access is required.');
      }
      if (!target.exists || !isAdminRole(target.data()?.role)) {
        throw new HttpsError('not-found', 'This admin no longer has a membership in this store.');
      }
      if (!isActive && userId === request.auth.uid) {
        throw new HttpsError('failed-precondition', 'You cannot disable your own admin access. Ask another admin to manage it.');
      }
      if (!isActive && target.data().isActive === true) {
        // The query participates in the transaction, so simultaneous changes
        // cannot each act on an outdated count of administrators.
        const current = await tx.get(members);
        if (current.docs.filter(doc => isActiveStoreAdmin(doc.data())).length <= 1) {
          throw new HttpsError('failed-precondition', 'Keep at least one active admin for this store.');
        }
      }
      tx.update(target.ref, {role: 'admin', isActive, updatedAt: serverTimestamp()});
      return {saved: true, isActive};
    });
  };
}

module.exports = {setStoreAdminActiveHandler};
