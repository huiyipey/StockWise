// Creates only uniquely named test resources, sends no email, removes them in finally.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {Firestore, Timestamp} = backendRequire('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const config = require('../android/app/google-services.json');
const apiKey = config.client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const authClient = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient})});
const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
const ids = [`feature_test_${suffix}_a`, `feature_test_${suffix}_b`];
const users = [];
async function signUp() {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({email:`stockwise-test-${randomUUID()}@example.invalid`, password:randomUUID()+'Aa9!', returnSecureToken:true})});
  const data = await response.json();
  if (!response.ok) throw Error(data.error?.message || 'Test sign-in failed');
  users.push(data); return data;
}
async function call(name, data, user) {
  const response = await fetch(`https://asia-southeast1-${project}.cloudfunctions.net/${name}`, {method:'POST', headers:{'Content-Type':'application/json', ...(user ? {Authorization:`Bearer ${user.idToken}`} : {})}, body:JSON.stringify({data})});
  const result = await response.json();
  return {status: response.status, ...result};
}
(async () => {
  authClient.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  try {
    const [owner, outsider, staff] = await Promise.all([signUp(), signUp(), signUp()]);
    const store = db.collection('stores').doc(ids[0]);
    const other = db.collection('stores').doc(ids[1]);
    const at = Timestamp.fromDate(new Date('2026-09-14T01:00:00Z'));
    await store.set({name:'Temporary feature verification', status:'active', ownerUid:owner.localId, testRun:suffix});
    await other.set({name:'Temporary isolation verification', status:'active', ownerUid:outsider.localId, testRun:suffix});
    await store.collection('members').doc(owner.localId).set({userId:owner.localId,storeId:store.id,role:'owner',isActive:true});
    await store.collection('members').doc(staff.localId).set({userId:staff.localId,storeId:store.id,role:'staff',isActive:true});
    await store.collection('categories').doc('dairy').set({storeId:store.id,name:'Chilled foods',isActive:true});
    await store.collection('orders').doc('paid-test').set({userId:owner.localId, orderNumber:'TEST-001', placedAt:at,paymentStatus:'paid',status:'completed',subtotalCents:1234,shippingFeeCents:500});
    await store.collection('orders').doc('paid-test').collection('items').doc('milk').set({productName:'Test Milk', quantity:2});
    await store.collection('orders').doc('unpaid-test').set({userId:owner.localId,orderNumber:'TEST-002',placedAt:at,paymentStatus:'unpaid',status:'to_pay',subtotalCents:9999,shippingFeeCents:500});
    await store.collection('inventoryEvents').doc('discard-test').set({occurredAt:at,eventType:'discarded',quantity:3,productName:'Test Milk',categoryId:'dairy'});
    await store.collection('inventoryBatches').doc('milk').set({productName:'Test Milk',categoryId:'dairy',status:'active',quantityOnHand:9,quantityReserved:0,expiryAt:Timestamp.fromDate(new Date(Date.now()+7*86400000)),promotionEnabled:false,basePriceCents:617,unitLabel:'bottle'});
    const input={storeId:store.id,kind:'sales',start:'2026-09-14',end:'2026-09-14'};
    assert.equal((await call('getStoreReport',input)).status,401);
    assert.equal((await call('getStoreReport',{...input,storeId:other.id},owner)).status,403);
    assert.equal((await call('getStoreReport',input,outsider)).status,403);
    const sales=await call('getStoreReport',input,owner);
    assert.equal(sales.status,200,JSON.stringify(sales));
    assert.equal(sales.result.revenueCents,1234); assert.equal(sales.result.count,1);
    assert.ok(sales.result.csv.includes('TEST-001')); assert.ok(!sales.result.csv.includes('TEST-002'));
    const waste=await call('getStoreReport',{...input,kind:'waste'},staff);
    assert.equal(waste.status,200,JSON.stringify(waste)); assert.equal(waste.result.units,3); assert.equal(waste.result.categories['Chilled foods'],3);
    console.log('PASS: authenticated reports, cross-store denials, staff access, paid sales, waste and CSV.');
    const picks=await call('shoppingAssistant',{storeId:store.id,question:''},owner);
    assert.equal(picks.status,200,JSON.stringify(picks)); assert.equal(picks.result.hasHistory,true); assert.equal(picks.result.recommendations[0].id,'milk');
    const fresh=await call('shoppingAssistant',{storeId:store.id,question:''},outsider);
    assert.equal(fresh.status,200,JSON.stringify(fresh)); assert.equal(fresh.result.hasHistory,false);
    const answer=await call('shoppingAssistant',{storeId:store.id,question:'What is the price of Test Milk?',productIds:['milk']},owner);
    assert.equal(answer.status,200,JSON.stringify(answer));
    console.log(`AI provider available: ${answer.result.aiAvailable}`);
    assert.equal(answer.result.aiAvailable,true,answer.result.answer);
    assert.match(answer.result.answer,/6[.,]17/);
    console.log('PASS: history isolation, recommendations and live AI price answer.');
    const write = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/stores/${store.id}/categories/not-allowed`, {method:'PATCH',headers:{Authorization:`Bearer ${outsider.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({fields:{storeId:{stringValue:store.id},name:{stringValue:'No access'},isActive:{booleanValue:true}}})});
    assert.equal(write.status,403);
    console.log('PASS: customer category write denied.');
  } finally {
    for (const id of ids) {
      assert.ok(id.startsWith(`feature_test_${suffix}_`));
      await db.recursiveDelete(db.collection('stores').doc(id));
    }
    for (const user of users) {
      await db.collection('assistantUsage').doc(user.localId).delete();
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary test stores/accounts removed.');
  }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
