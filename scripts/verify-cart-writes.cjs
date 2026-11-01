// Reproduces cart permissions with isolated, temporary fixtures. Sends no email.
// Existing stores, stock, customer carts and deployed security rules are untouched.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {createRequire} = require('node:module');
const path = require('node:path');
const backend = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp} = backend('firebase-admin/app');
const {getAuth} = backend('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const key = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const suffix = randomUUID();
const store = `cart_write_test_${suffix}`;
const uid = `cart-write-test-${suffix}`;
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
const cleanup = new Set();
let createdUser = false, access;
const fields = data => Object.fromEntries(Object.entries(data).map(([k,v]) => [k,
  v instanceof Date ? {timestampValue: v.toISOString()} : v === null ? {nullValue: null} :
  typeof v === 'number' ? {integerValue: String(v)} : typeof v === 'boolean' ? {booleanValue:v} : {stringValue:v}]));
async function request(url, body, auth, method = 'POST') {
  const r = await fetch(url, {method, headers: {'Content-Type':'application/json', ...(auth ? {Authorization:`Bearer ${auth}`} : {})}, body: body ? JSON.stringify(body) : undefined});
  const text = await r.text(); return {status:r.status, data:text ? JSON.parse(text) : null};
}
async function seed(doc, data) {
  assert.ok(doc.startsWith(`stores/${store}`)); cleanup.add(doc);
  assert.equal((await request(`${base}/${doc}`, {fields:fields(data)}, access, 'PATCH')).status,200,'Fixture seed failed');
}
const patch = (doc, data, transforms = []) => ({update:{name:`${prefix}/${doc}`,fields:data}, updateMask:{fieldPaths:Object.keys(data)},
  ...(transforms.length ? {updateTransforms: transforms.map(fieldPath => ({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})});
const commit = (auth, writes) => request(`${base}:commit`, {writes}, auth);

(async()=>{
  try {
    access = await token();
    await getAuth().createUser({uid,email:`${uid}@example.invalid`,password:`${suffix}Aa9!`,emailVerified:true}); createdUser=true;
    const signIn=await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,
      {email:`${uid}@example.invalid`,password:`${suffix}Aa9!`,returnSecureToken:true});
    assert.equal(signIn.status,200,'Temporary verified sign-in failed');
    const auth=signIn.data.idToken;
    await seed(`stores/${store}`,{name:'Temporary cart verification',status:'active',ownerUid:uid});
    const expiry=new Date(Date.now()+14*86400000);
    for(const [id,name,promotion,baseCents,promoCents] of [
      ['cream','green cream',true,2500,2000], ['milk','fresh milk',false,750,null], ['single','T',false,0,null]]) {
      await seed(`stores/${store}/inventoryBatches/${id}`,{storeId:store,productId:id,productName:name,
        imagePath:null,expiryAt:expiry,quantityOnHand:5,quantityReserved:1,status:'active',promotionEnabled:promotion,
        promotionPriceCents:promoCents,basePriceCents:baseCents});
      const cart=`stores/${store}/carts/${uid}`, item=`${cart}/items/${id}`;
      const raw=(await request(`${base}/stores/${store}/inventoryBatches/${id}`,null,auth,'GET')).data.fields;
      const canonical={...fields({storeId:store,batchId:id,quantity:1}),productId:raw.productId,productName:raw.productName,
        imagePath:raw.imagePath,expiryAt:raw.expiryAt,unitPriceCents:promotion&&promoCents!==null ? raw.promotionPriceCents : raw.basePriceCents};
      const parent=patch(cart,fields({storeId:store,ownerUid:uid}),['updatedAt']);
      const display=name.replace(/(^|[\s-])(\S)/gu,(_,a,b)=>a+b.toUpperCase());
      if(display!==name) {
        const before=await commit(auth,[parent,patch(item,{...canonical,productName:fields({name:display}).name},['addedAt','updatedAt'])]);
        assert.equal(before.status,403,'Formatted names must reproduce the original permission rejection');
        console.log(`PASS: original formatted-name write rejected for ${name}.`);
      }
      cleanup.add(cart);cleanup.add(item);
      assert.equal((await commit(auth,[parent,patch(item,canonical,['addedAt','updatedAt'])])).status,200,'Canonical create failed');
      const more={...canonical,quantity:{integerValue:'2'}};
      assert.equal((await commit(auth,[parent,patch(item,more,['updatedAt'])])).status,200,'Canonical repeat add failed');
      assert.equal((await commit(auth,[patch(item,{quantity:{integerValue:'5'}},['updatedAt'])])).status,403,'Stock/reservation limit must remain enforced');
      assert.equal((await commit(auth,[patch(item,{unitPriceCents:{integerValue:'1'}},['updatedAt'])])).status,403,'Price tampering must stay blocked');
      const other=`stores/${store}/carts/not-${uid}/items/${id}`;
      assert.equal((await commit(auth,[patch(other,canonical,['addedAt','updatedAt'])])).status,403,'Another cart must remain private');
      console.log(`PASS: ${name} create/repeat add, current price, stock limit and ownership.`);
    }
    // The live snapshot must win when a rendered card still has an older price.
    await seed(`stores/${store}/inventoryBatches/changed`,{storeId:store,productId:'changed',productName:'fresh cream',
      expiryAt:expiry,imagePath:null,quantityOnHand:4,quantityReserved:0,status:'active',promotionEnabled:true,
      promotionPriceCents:1800,basePriceCents:2500});
    const item=`stores/${store}/carts/${uid}/items/changed`; cleanup.add(item);
    const data=fields({storeId:store,batchId:'changed',productId:'changed',productName:'fresh cream',imagePath:null,expiryAt:expiry,quantity:1,unitPriceCents:2000});
    assert.equal((await commit(auth,[patch(item,data,['addedAt','updatedAt'])])).status,403,'A stale card price must be rejected');
    data.unitPriceCents={integerValue:'1800'};
    assert.equal((await commit(auth,[patch(item,data,['addedAt','updatedAt'])])).status,200,'Current snapshot price must work');
    console.log('PASS: current snapshot pricing succeeds where stale display pricing fails.');
  } finally {
    if(access) {
      for(const doc of [...cleanup].sort((a,b)=>b.split('/').length-a.split('/').length)) {
        assert.ok(doc===`stores/${store}`||doc.startsWith(`stores/${store}/`));
        const r=await request(`${base}/${doc}`,null,access,'DELETE');assert.ok([200,204,404].includes(r.status),'Temporary document cleanup failed');
      }
    }
    if(createdUser) { await getAuth().deleteUser(uid); }
    console.log('Temporary test store, cart items and Auth account removed; no email sent.');
  }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
