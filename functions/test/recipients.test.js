const {test} = require('node:test');
const assert = require('node:assert/strict');
const {wantsReportEmail} = require('../recipients');
test('report email defaults on and respects explicit per-store opt-out', () => {
  assert.equal(wantsReportEmail(), true);
  assert.equal(wantsReportEmail({}), true);
  assert.equal(wantsReportEmail({reportEmails:true}), true);
  assert.equal(wantsReportEmail({reportEmails:false}), false);
  const shops = {a:{reportEmails:false}, b:{reportEmails:true}};
  assert.equal(wantsReportEmail(shops.a),false);
  assert.equal(wantsReportEmail(shops.b),true);
});
