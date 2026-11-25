// Historical demo imports must not contact real customers or administrators.
function isImportedDemoOrder(order) {
  return order?.importedDemo === true &&
    order.demoSeedId === 'stockwise-demo-2026-11-16-v1';
}

module.exports = {isImportedDemoOrder};
