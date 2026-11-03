const {DateTime} = require('luxon');

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, character => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[character]);
const money = cents => Number.isSafeInteger(cents) ? `MYR ${(cents / 100).toFixed(2)}` : '—';
const statuses = {
  to_pay: 'To Pay', to_ship: 'To Ship', to_receive: 'To Receive',
  completed: 'Completed', cancelled: 'Cancelled', refunded: 'Refunded',
};

function orderConfirmation(shop, order, items, {customerName, imagesByPath = new Map(), orderId = '', preview = false} = {}) {
  const shopName = shop.name || 'Your StockWise store';
  const number = order.orderNumber || orderId;
  const receiver = order.receiver || {};
  const greeting = customerName || receiver.name || 'there';
  const date = order.placedAt?.toDate ? order.placedAt.toDate() : order.placedAt;
  const localDate = date instanceof Date ? DateTime.fromJSDate(date).setZone('Asia/Kuala_Lumpur') : null;
  const placed = localDate?.isValid ? `${localDate.toFormat('d MMMM yyyy, h:mm a')} (Malaysia time)` : '';
  const status = statuses[order.status] || 'To Pay';
  const paymentStatus = order.paymentStatus === 'paid' ? 'Paid' : order.paymentStatus === 'refunded' ? 'Refunded' : 'Unpaid';
  const paymentMethod = order.payment?.methodLabel || 'Bank transfer';
  const address = [receiver.addressLine1, receiver.addressLine2,
    [receiver.postalCode, receiver.city].filter(Boolean).join(' '), receiver.state].filter(Boolean);
  const needsReceipt = paymentStatus === 'Unpaid' && (order.status || 'to_pay') === 'to_pay' && !order.receiptPath;
  const nextStep = needsReceipt
    ? 'Open StockWise, go to Orders and select this order to upload your payment receipt.'
    : 'Open StockWise and go to Orders to view this order and its latest status.';
  const text = [
    preview ? 'STOCKWISE TEST EMAIL — sample order only. No order has been placed.' : '',
    'StockWise', shopName, '', preview ? 'Order confirmation preview' : 'Your order has been placed.',
    `Hi ${greeting},`, `Your order ${number} was placed successfully. Here is your order summary.`,
    `Order ID: ${number}`, placed ? `Placed: ${placed}` : '',
    `Payment status: ${paymentStatus}`, `Order status: ${status}`, `Payment method: ${paymentMethod}`, '', 'Order Summary',
    ...items.map(item => `${item.productName} — ${item.quantity} ${item.unitLabel || 'unit'} × ${money(item.unitPriceCents)} = ${money(item.lineTotalCents)}${item.promotionLabel ? '\n  ' + item.promotionLabel : ''}`),
    '', `Subtotal: ${money(order.subtotalCents)}`, `Delivery fee: ${money(order.shippingFeeCents)}`,
    `Total: ${money(order.totalCents)}`, '', 'Delivery Details', receiver.name || '', receiver.phone || '',
    ...address, '', nextStep, '', `Sent by ${shopName} via StockWise.`,
  ].filter((line, index, all) => line !== '' || all[index - 1] !== '').join('\n');

  const productRows = items.map(item => {
    const image = imagesByPath.get(item.imagePath);
    const photo = image
      ? `<img src="cid:${escapeHtml(image)}" width="64" height="64" alt="${escapeHtml(item.productName)}" style="display:block;width:64px;height:64px;object-fit:cover;border-radius:10px;" />`
      : '<table role="presentation" width="64" height="64" cellpadding="0" cellspacing="0" bgcolor="#EAF3E8" style="border-radius:10px;"><tr><td align="center" style="font-size:11px;color:#5F8C5B;">Product</td></tr></table>';
    const promotion = item.promotionLabel
      ? `<div style="margin-top:6px;font-size:12px;line-height:18px;color:#5F8C5B;">${escapeHtml(item.promotionLabel)}</div>` : '';
    const regular = Number.isSafeInteger(item.regularUnitPriceCents) && item.regularUnitPriceCents > item.unitPriceCents
      ? `<span style="text-decoration:line-through;color:#7A817A;">${money(item.regularUnitPriceCents)}</span> ` : '';
    return `<tr>
      <td width="76" valign="top" style="width:76px;padding:18px 12px 18px 0;border-bottom:1px solid #E4E8E2;">${photo}</td>
      <td valign="top" style="padding:18px 10px 18px 0;border-bottom:1px solid #E4E8E2;overflow-wrap:anywhere;word-break:break-word;">
        <div style="font-size:16px;line-height:23px;font-weight:bold;color:#242824;">${escapeHtml(item.productName)}</div>
        <div style="margin-top:5px;font-size:13px;line-height:20px;color:#687368;">Qty: ${escapeHtml(item.quantity)} ${escapeHtml(item.unitLabel || 'unit')}</div>
        <div style="font-size:12px;line-height:19px;color:#687368;">${regular}${money(item.unitPriceCents)} each</div>${promotion}
      </td>
      <td width="110" align="right" valign="top" style="width:110px;padding:18px 0;border-bottom:1px solid #E4E8E2;font-size:15px;line-height:23px;font-weight:bold;color:#244B39;">${money(item.lineTotalCents)}</td>
    </tr>`;
  }).join('');
  const metadataRow = (label, value) => `<tr><td valign="top" style="padding:5px 12px 5px 0;font-size:13px;line-height:20px;color:#687368;">${label}</td><td align="right" valign="top" style="padding:5px 0;font-size:13px;line-height:20px;font-weight:bold;color:#244B39;overflow-wrap:anywhere;">${escapeHtml(value)}</td></tr>`;

  // Table layout and inline styles keep the message readable in Gmail and Outlook.
  // All customer/store/product values are escaped; images are trusted CID attachments only.
  const html = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>StockWise order confirmation</title>
<style>body{margin:0;padding:0;}table{border-collapse:collapse;}@media only screen and (max-width:480px){.outer{padding:12px 0!important;}.content{padding:26px 20px!important;}.heading{font-size:28px!important;line-height:34px!important;}.shell{border-radius:0!important;}}</style></head>
<body style="margin:0;padding:0;background-color:#F5F6F3;font-family:Arial,Helvetica,sans-serif;color:#242824;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all;">${preview ? 'Test email only. ' : ''}${escapeHtml(shopName)} · Order ${escapeHtml(number)} · ${money(order.totalCents)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F5F6F3"><tr><td class="outer" align="center" style="padding:32px 12px;">
<table role="presentation" class="shell" width="600" cellpadding="0" cellspacing="0" bgcolor="#FFFFFF" style="width:100%;max-width:600px;border:1px solid #E4E8E2;border-radius:20px;">
<tr><td style="padding:26px 30px;background-color:#244B39;border-radius:20px 20px 0 0;">
  <div style="font-size:28px;line-height:34px;font-weight:bold;letter-spacing:-0.5px;color:#FFFFFF;">StockWise<span style="color:#B8D6AD;">.</span></div>
  <div style="margin-top:6px;font-size:13px;line-height:20px;color:#D6E8D0;">Fresh stock, less waste</div>
</td></tr>
<tr><td class="content" style="padding:32px 30px;">
  ${preview ? '<div style="padding:12px 14px;margin-bottom:22px;background-color:#FFF2DB;color:#845014;font-size:13px;line-height:20px;font-weight:bold;">TEST EMAIL · This is a sample order. No order has been placed.</div>' : ''}
  <div style="font-size:12px;line-height:18px;font-weight:bold;letter-spacing:1.5px;color:#5F8C5B;">ORDER CONFIRMATION</div>
  <h1 class="heading" style="margin:12px 0 22px;font-size:34px;line-height:40px;letter-spacing:-0.6px;color:#244B39;">${preview ? 'Your email preview<br>is ready.' : 'Your order<br>has been placed.'}</h1>
  <p style="margin:0 0 12px;font-size:16px;line-height:25px;">Hi ${escapeHtml(greeting)},</p>
  <p style="margin:0 0 24px;font-size:15px;line-height:24px;color:#687368;">Thank you for shopping with <strong style="color:#244B39;">${escapeHtml(shopName)}</strong>. Your order has been placed successfully. Here are the details.</p>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F5F6F3" style="border-radius:12px;"><tr><td style="padding:16px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      ${metadataRow('Shop', shopName)}${metadataRow('Order ID', number)}${placed ? metadataRow('Placed', placed) : ''}
      ${metadataRow('Payment status', paymentStatus)}${metadataRow('Order status', status)}${metadataRow('Payment method', paymentMethod)}
    </table>
  </td></tr></table>
  <h2 style="margin:30px 0 2px;font-size:22px;line-height:29px;color:#244B39;">Order Summary</h2>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="table-layout:fixed;">${productRows}</table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:16px;">
    <tr><td style="padding:6px 0;font-size:15px;line-height:22px;color:#687368;">Subtotal</td><td align="right" style="padding:6px 0;font-size:15px;line-height:22px;">${money(order.subtotalCents)}</td></tr>
    <tr><td style="padding:6px 0 20px;font-size:15px;line-height:22px;color:#687368;">Delivery fee</td><td align="right" style="padding:6px 0 20px;font-size:15px;line-height:22px;">${money(order.shippingFeeCents)}</td></tr>
    <tr><td style="padding:18px 0;border-top:2px solid #E4E8E2;font-size:21px;line-height:28px;font-weight:bold;color:#244B39;">Total</td><td align="right" style="padding:18px 0;border-top:2px solid #E4E8E2;font-size:23px;line-height:28px;font-weight:bold;color:#244B39;">${money(order.totalCents)}</td></tr>
  </table>
  <h2 style="margin:22px 0 12px;font-size:18px;line-height:26px;color:#244B39;">Delivery Details</h2>
  <div style="font-size:14px;line-height:23px;color:#687368;">${[receiver.name, receiver.phone, ...address].filter(Boolean).map(escapeHtml).join('<br>')}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#EAF3E8" style="margin-top:26px;border-radius:12px;"><tr><td style="padding:18px;">
    <div style="margin-bottom:6px;font-size:14px;line-height:21px;font-weight:bold;color:#244B39;">${needsReceipt ? 'Next: upload your payment receipt' : 'Your order in StockWise'}</div>
    <div style="font-size:13px;line-height:21px;color:#456641;">${escapeHtml(nextStep)}</div>
  </td></tr></table>
</td></tr>
<tr><td align="center" style="padding:20px 24px;border-top:1px solid #E4E8E2;font-size:12px;line-height:20px;color:#7A817A;">Sent by ${escapeHtml(shopName)} via <strong style="color:#5F8C5B;">StockWise</strong>.<br>Keep this email for your order records.</td></tr>
</table></td></tr></table></body></html>`;
  return {subject: `${preview ? '[TEST] ' : ''}${String(shopName).replace(/[\r\n]/g, ' ')}: order ${String(number).replace(/[\r\n]/g, ' ')} placed successfully`, text, html};
}

module.exports = {orderConfirmation};
