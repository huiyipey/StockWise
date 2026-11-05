const {DateTime} = require('luxon');
const zone = 'Asia/Kuala_Lumpur';
const date = value => value?.toDate ? value.toDate() : value instanceof Date ? value : new Date(value);
const cents = value => Number.isSafeInteger(value) && value >= 0;
const positive = value => Number.isSafeInteger(value) && value > 0;
const titleCase = value => String(value || '').trim().replace(/\s+/gu, ' ').replace(/(^|[\s-])(\S)/gu, (_,a,b)=>a+b.toUpperCase());
function operatingHours(value) {
  const hours = value || {opens:540,closes:1260};
  if (!Number.isInteger(hours.opens) || !Number.isInteger(hours.closes) || hours.opens < 0 || hours.closes > 1440 || hours.closes <= hours.opens + 30) throw Error('Set operating hours with at least 30 minutes for orders.');
  const closedDays = hours.closedDays ?? [];
  if (!Array.isArray(closedDays) || closedDays.length > 7 || closedDays.some(day => !Number.isInteger(day) || day < 1 || day > 7)) throw Error('Choose closed days from Monday through Sunday.');
  return {opens:hours.opens,closes:hours.closes,closedDays:[...new Set(closedDays)].sort((a,b)=>a-b)};
}
function orderingOpen(store, now = new Date()) {
  const h=operatingHours(store.operatingHours), local=DateTime.fromJSDate(now).setZone(zone);
  const minute=local.hour*60+local.minute;
  return store.status==='active' && !h.closedDays.includes(local.weekday) && minute>=h.opens && minute<h.closes-30;
}
function orderingClosedMessage(store, now = new Date()) {
  const local=DateTime.fromJSDate(now).setZone(zone);
  return operatingHours(store.operatingHours).closedDays.includes(local.weekday)
    ? 'The store is closed today. Please return on an open day.'
    : 'Ordering is closed. Orders close 30 minutes before the store closes.';
}
function shelfLife(batch, now=new Date()) {
  const expiry=DateTime.fromJSDate(date(batch.expiryAt)).setZone(zone).startOf('day');
  const received=DateTime.fromJSDate(date(batch.receivedAt||batch.createdAt||now)).setZone(zone).startOf('day');
  const days=Math.max(0,Math.round(expiry.diff(received,'days').days));
  const type=days<8?'short':days<=90?'medium':'long';
  const left=Math.round(expiry.diff(DateTime.fromJSDate(now).setZone(zone).startOf('day'),'days').days);
  const [orange, red]=type==='short'?[3,1]:type==='medium'?[20,6]:[60,29];
  return {totalShelfLifeDays:days,shelfLifeType:type,daysLeft:left,colour:left>orange?'green':left<=red?'red':'orange',orange,red};
}
function expiryStage(batch, store, now=new Date()) {
  if (batch.notifyOnExpiry===false || batch.status!=='active' || batch.quantityOnHand<=0 || date(batch.expiryAt)<=now) return null;
  const life=shelfLife(batch,now), h=operatingHours(store.operatingHours), local=DateTime.fromJSDate(now).setZone(zone);
  const minute=local.hour*60+local.minute;
  if (h.closedDays.includes(local.weekday) || minute<h.opens || minute>=h.closes) return null;
  const middle=Math.floor((life.orange+life.red+1)/2);
  if (life.daysLeft<=1 && minute>=h.closes-30) return 4;
  if (life.daysLeft<=life.red) return 3;
  if (life.daysLeft<=middle) return 2;
  return life.daysLeft<=life.orange?1:null;
}
function validatePromotion(p, base) {
  if (!p) return null;
  if (!['percentage','fixed','bundle'].includes(p.type)) throw Error('Choose a promotion type.');
  if (p.type==='percentage' && !(Number.isFinite(p.percentage)&&p.percentage>0&&p.percentage<100)) throw Error('Enter a percentage greater than 0 and less than 100.');
  if (p.type==='fixed' && !(positive(p.amountCents)&&p.amountCents<base)) throw Error('Discount must be positive and lower than the regular price.');
  if (p.type==='bundle') {
    if (!['quantity','spend'].includes(p.requirement) || !(p.requirement==='quantity'?positive(p.thresholdQuantity):positive(p.thresholdSpendCents))) throw Error('Enter a valid bundle requirement.');
    if (typeof p.targetProductId!=='string'||!p.targetProductId||!positive(p.giftQuantity)) throw Error('Choose the bundle product and quantity.');
    if (!['free','percentage','fixed'].includes(p.reward)) throw Error('Choose the bundle discount.');
    if (p.reward==='percentage'&&!(p.rewardPercentage>0&&p.rewardPercentage<100)) throw Error('Enter a valid bundle percentage.');
    if (p.reward==='fixed'&&!positive(p.rewardAmountCents)) throw Error('Enter a positive bundle discount.');
  }
  return p;
}
function sellingPrice(batch) {
  if (!batch.promotionEnabled) return batch.basePriceCents;
  const p=batch.promotion;
  if (p?.type==='percentage') return Math.max(1,Math.round(batch.basePriceCents*(100-p.percentage)/100));
  if (p?.type==='fixed') return Math.max(1,batch.basePriceCents-p.amountCents);
  return p?.type==='bundle'?batch.basePriceCents:batch.promotionPriceCents??batch.basePriceCents;
}
function deliveryFee(settings, postcode) {
  if (settings?.deliveryFeeMode!=='postcode') return settings?.deliveryFeeCents??500;
  if (!/^\d{5}$/.test(postcode||'')) return null;
  const fee=settings.postcodeFees?.[postcode];
  return cents(fee)?fee:null;
}
function quoteCart(cart, inventory, {now=new Date()}={}) {
  return require('./bundle_quote').bundleQuote(cart, inventory, {now, sellingPrice, validatePromotion, titleCase, shelfLife});
}

module.exports={titleCase,operatingHours,orderingOpen,orderingClosedMessage,shelfLife,expiryStage,validatePromotion,sellingPrice,deliveryFee,quoteCart};
