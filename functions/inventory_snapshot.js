// Preserve stock snapshots without the retired search-name mirror.
function inventorySnapshot(data) {
  const snapshot = {...data};
  delete snapshot.productNameLowercase;
  return snapshot;
}

module.exports = {inventorySnapshot};
