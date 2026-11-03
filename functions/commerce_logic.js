const {DateTime} = require('luxon');
const zone = 'Asia/Kuala_Lumpur';
const date = value => value?.toDate ? value.toDate() : value instanceof Date ? value : new Date(value);
const cents = value => Number.isSafeInteger(value) && value >= 0;
const positive = value => Number.isSafeInteger(value) && value > 0;
const titleCase = value => String(value || '').trim().replace(/\s+/gu, ' ').replace(/(^|[\s-])(\S)/gu, (_,a,b)=>a+b.toUpperCase());
function operatingHours(value) {
  const hours = value || {opens:540,closes:1260};
  if (!Number.isInteger(hours.opens) || !Number.isInteger(hours.closes) || hours.opens < 0 || hours.closes > 1440 || hours.closes <= hours.opens + 30) throw Error('Set operating hours with at least 30 minutes for orders.');
  return {opens:hours.opens,closes:hours.closes};
}
function orderingOpen(store, now = new Date()) {
  const h=operatingHours(store.operatingHours), local=DateTime.fromJSDate(now).setZone(zone);
  const minute=local.hour*60+local.minute;
  return store.status==='active' && minute>=h.opens && minute<h.closes-30;
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
  if (minute<h.opens || minute>=h.closes) return null;
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
  const byId=new Map(inventory.map(b=>[b.id,b])), stock=new Map(), lines=[];
  const sellable=b=>b&&b.status==='active'&&date(b.expiryAt)>now&&b.quantityOnHand-b.quantityReserved>0;
  function reserve(b, quantity) {
    if (!sellable(b)||!positive(quantity)) throw Error('A product is no longer available. Refresh your cart.');
    const used=(stock.get(b.id)||0)+quantity;
    if (used>b.quantityOnHand-b.quantityReserved) throw Error(`Not enough ${titleCase(b.productName)} available for this order and its bundles.`);
    stock.set(b.id,used);
  }
  function line(b,quantity,price,extra={}) {
    reserve(b,quantity);
    const full=sellingPrice(b);
    lines.push({batchId:b.id,productId:b.productId,productName:b.productName,categoryId:b.categoryId||'others',imagePath:b.imagePath||null,
      regularUnitPriceCents:b.basePriceCents,expiryAt:date(b.expiryAt),unitLabel:b.unitLabel||'unit',quantity,unitPriceCents:price,lineTotalCents:price*quantity,
      discountCents:Math.max(0,(full-price)*quantity),...extra});
  }
  for (const item of cart) { const b=byId.get(item.batchId); if(!b) throw Error('A product is no longer available.'); line(b,item.quantity,sellingPrice(b),{kind:'purchase',promotionLabel:b.promotionEnabled&&b.promotion?.type==='bundle'?b.promotion.label||'Buy X Get Y offer':''}); }
  for (const item of cart) {
    const b=byId.get(item.batchId), p=b.promotion;
    if (!b.promotionEnabled||p?.type!=='bundle') continue;
    validatePromotion(p,b.basePriceCents);
    const groups=p.requirement==='spend'?Math.floor(sellingPrice(b)*item.quantity/p.thresholdSpendCents):Math.floor(item.quantity/p.thresholdQuantity);
    if (!groups) continue;
    const targets=inventory.filter(t=>t.productId===p.targetProductId&&sellable(t)).sort((a,b)=>date(a.expiryAt)-date(b.expiryAt)||a.id.localeCompare(b.id));
    let remaining=groups*p.giftQuantity;
    for(const target of targets) {
      const quantity=Math.min(remaining,target.quantityOnHand-target.quantityReserved-(stock.get(target.id)||0));
      if(quantity<=0)continue;
      const full=sellingPrice(target), price=p.reward==='free'?0:p.reward==='percentage'?Math.max(1,Math.round(full*(100-p.rewardPercentage)/100)):Math.max(0,full-p.rewardAmountCents);
      line(target,quantity,price,{kind:'bundle',sourceBatchId:b.id,promotionLabel:p.label||'Buy X Get Y offer'});remaining-=quantity;
      if(!remaining)break;
    }
    if(remaining)throw Error('The bundle product does not have enough stock. Please contact the store.');
  }
  return {lines,stock:[...stock].map(([id,quantity])=>({id,quantity})),subtotalCents:lines.reduce((a,l)=>a+l.lineTotalCents,0),discountCents:lines.reduce((a,l)=>a+l.discountCents,0)};
}
module.exports={titleCase,operatingHours,orderingOpen,shelfLife,expiryStage,validatePromotion,sellingPrice,deliveryFee,quoteCart};
