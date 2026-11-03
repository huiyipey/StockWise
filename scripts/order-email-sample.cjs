const {orderConfirmation} = require('../functions/order_email_template');

function sampleConfirmation(options = {}) {
  return orderConfirmation({name: 'StockWise Demo Store'}, {
    orderNumber: 'SW-PREVIEW-001', status: 'to_pay', paymentStatus: 'unpaid',
    placedAt: new Date(), payment: {methodLabel: 'Bank transfer'},
    subtotalCents: 3350, shippingFeeCents: 500, totalCents: 3850,
    receiver: {name: 'StockWise Customer', phone: 'Sample phone number',
      addressLine1: 'Sample delivery address', postalCode: '50000', city: 'Kuala Lumpur', state: 'Kuala Lumpur'},
  }, [
    {productName: 'Fresh Milk', quantity: 2, unitLabel: 'packs', regularUnitPriceCents: 1500,
      unitPriceCents: 1250, lineTotalCents: 2500, promotionLabel: 'Promotional price'},
    {productName: 'Wholemeal Bread', quantity: 1, unitLabel: 'loaf', unitPriceCents: 850, lineTotalCents: 850},
    {productName: 'Wholemeal Bread', quantity: 1, unitLabel: 'loaf', regularUnitPriceCents: 850,
      unitPriceCents: 0, lineTotalCents: 0, promotionLabel: 'Buy 2 Fresh Milk, get 1 Wholemeal Bread free'},
  ], {...options, preview: true});
}

module.exports = {sampleConfirmation};
if (require.main === module) {
  const fs = require('node:fs'), path = require('node:path');
  const folder = path.resolve(__dirname, '../output/order-confirmation-email');
  fs.mkdirSync(folder, {recursive: true});
  const message = sampleConfirmation();
  fs.writeFileSync(path.join(folder, 'stockwise-order-confirmation-preview.html'), message.html);
  fs.writeFileSync(path.join(folder, 'stockwise-order-confirmation-preview.txt'), message.text);
  console.log(`Email preview saved in ${folder}`);
}
