const {HttpsError} = require('firebase-functions/v2/https');
const {storeRef, team} = require('./commerce');

// Delete only categories that have no current or historical references.
function deleteCategoryHandler({db}) {
  return async request => {
    const store = storeRef(db, request);
    const id = request.data?.categoryId;
    if (typeof id !== 'string' || !id.trim() || id.length > 256 || id.includes('/') || ['.', '..'].includes(id)) {
      throw new HttpsError('invalid-argument', 'Choose a valid category.');
    }
    const category = store.collection('categories').doc(id);
    // Check category references before the transaction deletes anything.
    return db.runTransaction(async tx => {
      await team(tx, store, request.auth.uid);
      const saved = await tx.get(category);
      if (!saved.exists) return {deleted: true, alreadyDeleted: true};
      // Return the message used when a category must be archived.
      const inUse = () => new HttpsError('failed-precondition',
        'This category is used by products or stock history. Archive it instead to preserve those records.',
        {reason: 'category-in-use'});
      // Include legacy rows that implicitly belong to Others.
      const referencesCategory = row => row.categoryId === id || (id === 'others' && !row.categoryId);
      // Find records that reference the category being deleted.
      const linkedRows = collection => id === 'others'
        ? collection.select('categoryId')
        : collection.where('categoryId', '==', id).limit(1);
      const references = await Promise.all(
        ['inventoryBatches', 'products', 'inventoryArchive', 'inventoryEvents'].map(name =>
          tx.get(linkedRows(store.collection(name)))),
      );
      // Legacy rows without a category are displayed/restored as Others.
      if (references.some(result => result.docs.some(doc => referencesCategory(doc.data())))) throw inUse();
      // Older order items may predate inventory events or lack storeId. Query
      // only this shop's orders, including legacy history, without a global scan.
      let lastOrder;
      while (true) {
        let orders = store.collection('orders').select().limit(100);
        if (lastOrder) orders = orders.startAfter(lastOrder);
        const page = await tx.get(orders);
        for (let offset = 0; offset < page.docs.length; offset += 20) {
          const rows = await Promise.all(page.docs.slice(offset, offset + 20).map(order =>
            tx.get(linkedRows(order.ref.collection('items')))));
          if (rows.some(result => result.docs.some(doc => referencesCategory(doc.data())))) throw inUse();
        }
        if (page.docs.length < 100) break;
        lastOrder = page.docs.at(-1);
      }
      tx.delete(category);
      return {deleted: true};
    }).catch(error => {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('unavailable', 'Could not delete the category. Please try again.');
    });
  };
}

// Export the helpers used by the app backend and tests.
module.exports = {deleteCategoryHandler};
