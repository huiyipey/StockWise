const {test} = require('node:test');
const assert = require('node:assert/strict');
const {range, report, csv, duePeriods, recommendations} = require('../reporting');
test('Malaysia inclusive range excludes adjacent dates and invalid ranges', () => {
  const r = range('2026-09-01', '2026-09-01');
  assert.equal(r.start.toISOString(), '2026-08-31T16:00:00.000Z');
  assert.equal(r.end.toISOString(), '2026-09-01T16:00:00.000Z');
  assert.throws(() => range('invalid', '2026-09-01'));
  assert.throws(() => range('2026-09-02', '2026-09-01'));
  assert.throws(() => range('2020-01-01', '2026-01-01'));
});
test('sales includes paid orders only, excludes cancelled/refunded, separates delivery', () => {
  const order = {placedAt: '2026-09-01T00:00:00Z', paymentStatus: 'paid', status: 'completed', subtotalCents: 1234, shippingFeeCents: 500};
  const data = report('sales', [order, {...order, paymentStatus: 'unpaid'}, {...order, status: 'cancelled'}, {...order, status: 'refunded'}, {...order, placedAt: '2026-09-01T16:00:00Z'}], '2026-09-01', '2026-09-01');
  assert.equal(data.count, 1); assert.equal(data.revenueCents, 1234); assert.equal(data.deliveryCents, 500); assert.equal(data.totalCents, 1734);
});
test('waste excludes receipts, sales, and out-of-range events; retains renamed categories', () => {
  const event = {occurredAt: '2026-09-02T01:00:00Z', eventType: 'discarded', quantity: 4, categoryId: 'dairy'};
  const data = report('waste', [event, {...event, eventType: 'expired', quantity: 2}, {...event, eventType: 'received'}, {...event, eventType: 'sold'}], '2026-09-01', '2026-09-03', {dairy: 'Chilled foods'});
  assert.equal(data.units, 6); assert.equal(data.categories['Chilled foods'], 6); assert.equal(data.daily[0].value, 0); assert.equal(data.daily[1].value, 6);
});
test('weekly and monthly schedules handle year boundaries and overlap', () => {
  const periods = duePeriods(new Date('2026-06-01T01:00:00Z'));
  assert.equal(periods.length, 2);
  assert.deepEqual(periods[0], {cadence: 'weekly', start: '2026-05-25', end: '2026-05-31'});
  assert.equal(periods[1].start, '2026-05-01');
  assert.equal(duePeriods(new Date('2026-01-01T01:00:00Z'))[0].start, '2025-12-01');
  assert.equal(duePeriods(new Date('2026-06-02T01:00:00Z')).length, 0);
});
test('CSV escapes quotes, commas and spreadsheet formulas', () => {
  const data = report('waste', [{occurredAt: '2026-09-01T01:00:00Z', eventType: 'discarded', quantity: 1, productName: '=HYPERLINK("evil")'}], '2026-09-01', '2026-09-01');
  const text = csv(data, 'Store, A');
  assert.ok(text.includes('"Store, A"')); assert.ok(text.includes("'=HYPERLINK")); assert.ok(text.includes('""evil""'));
});
test('recommendations prioritize purchase history and only return catalog items', () => {
  const catalog = [{id: 'milk', name: 'Milk', promotion: false}, {id: 'bread', name: 'Bread', promotion: true}];
  assert.equal(recommendations(catalog, [{productName: 'Milk', quantity: 2}, {productName: 'Missing', quantity: 100}])[0].id, 'milk');
  assert.equal(recommendations(catalog, [])[0].id, 'bread');
  assert.deepEqual(recommendations([], []), []);
});
