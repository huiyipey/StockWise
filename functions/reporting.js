const {DateTime} = require('luxon');
const ZONE = 'Asia/Kuala_Lumpur';
const day = (value) => DateTime.fromISO(value, {zone: ZONE});
function range(start, end) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start || '') || !/^\d{4}-\d{2}-\d{2}$/.test(end || '')) throw Error('Choose valid dates.');
  const a = day(start), b = day(end).plus({days: 1});
  if (!a.isValid || !b.isValid || b <= a || b.diff(a, 'days').days > 366) throw Error('Choose a range of 1 to 366 days.');
  return {start: a.toJSDate(), end: b.toJSDate()};
}
function report(kind, records, start, end, names = {}) {
  const bounds = range(start, end);
  const daily = {};
  for (let d = day(start); d < day(end).plus({days: 1}); d = d.plus({days: 1})) daily[d.toISODate()] = 0;
  const rows = [], categories = {};
  let revenue = 0, delivery = 0, units = 0;
  for (const record of records) {
    const rawDate = kind === 'sales' ? record.placedAt : record.occurredAt;
    const date = rawDate?.toDate ? rawDate.toDate() : new Date(rawDate);
    if (!(date >= bounds.start && date < bounds.end)) continue;
    const dateLabel = DateTime.fromJSDate(date, {zone: ZONE}).toISODate();
    if (kind === 'sales') {
      if (record.paymentStatus !== 'paid' || ['cancelled', 'refunded'].includes(record.status)) continue;
      const cents = Math.round(Number(record.subtotalCents) || 0);
      const shipping = Math.round(Number(record.shippingFeeCents) || 0);
      revenue += cents; delivery += shipping; daily[dateLabel] += cents;
      rows.push([dateLabel, record.orderNumber || record.id, cents / 100, shipping / 100, (cents + shipping) / 100]);
    } else {
      if (!['expired', 'discarded'].includes(record.eventType)) continue;
      const quantity = Math.max(0, Math.round(Number(record.quantity) || 0));
      const category = names[record.categoryId] || record.categoryId || 'Others';
      units += quantity; daily[dateLabel] += quantity;
      categories[category] = (categories[category] || 0) + quantity;
      rows.push([dateLabel, record.productName || 'Product', category, record.eventType, quantity]);
    }
  }
  rows.sort((a, b) => a[0].localeCompare(b[0]));
  return {kind, start, end, timezone: ZONE, currency: 'MYR', count: rows.length, revenueCents: revenue,
    deliveryCents: delivery, totalCents: revenue + delivery, units,
    daily: Object.entries(daily).map(([date, value]) => ({date, value})),
    categories, headers: kind === 'sales' ? ['Date', 'Order', 'Product sales (MYR)', 'Delivery (MYR)', 'Total (MYR)'] : ['Date', 'Product', 'Category', 'Reason', 'Units'], rows};
}
function csvCell(value) {
  let s = String(value ?? '');
  if (typeof value === 'string' && /^[\s]*[=+@-]/.test(s)) s = "'" + s;
  return '"' + s.replaceAll('"', '""') + '"';
}
function csv(data, storeName) {
  return '\uFEFF' + [[storeName, data.kind + ' report'], ['From', data.start, 'Through', data.end],
    ['Timezone', data.timezone],
    data.kind === 'sales' ? ['Paid orders', data.count, 'Product sales MYR', data.revenueCents / 100, 'Delivery MYR', data.deliveryCents / 100] : ['Waste units', data.units],
    [], data.headers, ...data.rows].map(row => row.map(csvCell).join(',')).join('\r\n');
}
function duePeriods(now = new Date()) {
  const today = DateTime.fromJSDate(now, {zone: ZONE}).startOf('day');
  const result = [];
  if (today.weekday === 1) result.push({cadence: 'weekly', start: today.minus({weeks: 1}).toISODate(), end: today.minus({days: 1}).toISODate()});
  if (today.day === 1) result.push({cadence: 'monthly', start: today.minus({months: 1}).startOf('month').toISODate(), end: today.minus({days: 1}).toISODate()});
  return result;
}
function recommendations(catalog, history) {
  const bought = new Map();
  for (const line of history) {
    const key = (line.productName || '').toLowerCase();
    bought.set(key, (bought.get(key) || 0) + Math.max(0, Number(line.quantity) || 0));
  }
  return catalog.map(item => {
    const purchases = bought.get(item.name.toLowerCase()) || 0;
    return {id: item.id, reason: purchases ? 'You bought this product before.' : item.promotion ? 'Available on promotion in this store.' : 'Available in this store.', score: purchases * 10 + (item.promotion ? 2 : 0)};
  }).sort((a, b) => b.score - a.score || a.id.localeCompare(b.id)).slice(0, 6);
}
module.exports = {range, report, csv, duePeriods, recommendations};
