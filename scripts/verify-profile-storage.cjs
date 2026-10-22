// Only generated test resources are created/deleted. No report email is sent.
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const req=require('node:module').createRequire(require('node:path').join(__dirname,'../functions/package.json'));
const {Firestore,Timestamp}=req('@google-cloud/firestore');
const {GoogleAuth,OAuth2Client}=req('google-auth-library');
const {initializeApp}=req('firebase-admin/app');
const {getAuth}=req('firebase-admin/auth');
const {token,project}=require('./cloud-access.cjs');
const config=require('../android/app/google-services.json');
const apiKey=config.client[0].api_key[0].current_key;
const bucket=config.project_info.storage_bucket;
const client=new OAuth2Client();
const db=new Firestore({projectId:project,preferRest:true,auth:new GoogleAuth({authClient:client})});
initializeApp({projectId:project,credential:{getAccessToken:async()=>({access_token:await token(),expires_in:3500})}});
const id='profile_test_'+randomUUID().replaceAll('-','');
const users=[],objects=[];
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aPioAAAAASUVORK5CYII=','base64');
async function signUp(){
 const r=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:id+randomUUID()+'@example.invalid',password:randomUUID()+'Aa9!',returnSecureToken:true})});
 const d=await r.json();assert.equal(r.status,200,JSON.stringify(d));users.push(d);return d;
}
async function upload(path,user,body=png,type='image/png'){
 objects.push(path);
 return fetch(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o?name=${encodeURIComponent(path)}`,{method:'POST',headers:{Authorization:`Firebase ${user.idToken}`,'Content-Type':type},body});
}
async function patch(path,user,fields){
 return fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}`,{method:'PATCH',headers:{Authorization:`Bearer ${user.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({fields})});
}
(async()=>{
 client.setCredentials({access_token:await token(),expiry_date:Date.now()+3500000});
 try{
  const customer=await signUp(),staff=await signUp(),outsider=await signUp();
  const store=db.collection('stores').doc(id);
  await store.set({status:'active',name:'Temporary profile/storage test',ownerUid:staff.localId});
  await store.collection('members').doc(staff.localId).set({userId:staff.localId,role:'staff',isActive:true});
  await store.collection('orders').doc('order').set({userId:customer.localId,status:'to_pay',placedAt:Timestamp.now()});
  const receipt=`stores/${id}/order-attachments/order/receipt.png`;
  const own=await upload(receipt,customer);
  assert.equal(own.status,200,'Customer receipt upload: '+own.status+' '+await own.text());
  assert.equal((await upload(receipt,outsider)).status,403,'Unrelated user must not replace receipt');
  const read=await fetch(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(receipt)}?alt=media`,{headers:{Authorization:`Firebase ${staff.idToken}`}});
  assert.equal(read.status,200,'Active staff receipt read');
  const outsiderRead=await fetch(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(receipt)}?alt=media`,{headers:{Authorization:`Firebase ${outsider.idToken}`}});
  assert.equal(outsiderRead.status,403,'Outsider receipt read denied');
  assert.equal((await upload(`stores/${id}/order-attachments/order/bad.txt`,customer,Buffer.from('not an image'),'text/plain')).status,403);
  assert.equal((await upload(`stores/${id}/order-attachments/order/large.png`,customer,Buffer.alloc(5*1024*1024),'image/png')).status,403);
  assert.equal((await patch(`stores/${id}/orders/order`,customer,{userId:{stringValue:customer.localId},status:{stringValue:'to_pay'},placedAt:{timestampValue:(await store.collection('orders').doc('order').get()).data().placedAt.toDate().toISOString()},receiptPath:{stringValue:receipt},updatedAt:{timestampValue:new Date().toISOString()},receiptUploadedAt:{timestampValue:new Date().toISOString()}})).status,200,'Receipt link update');
  const avatar=`user-avatars/${customer.localId}/test.png`;
  assert.equal((await upload(avatar,customer)).status,200,'Own avatar upload');
  assert.equal((await upload(avatar,outsider)).status,403,'Other avatar write denied');
  const profile=`users/${customer.localId}`;
  assert.equal((await patch(profile,customer,{displayName:{stringValue:'Edited test username'},phone:{stringValue:'123'},photoPath:{stringValue:avatar}})).status,200);
  assert.equal((await patch(profile,outsider,{displayName:{stringValue:'Not permitted'}})).status,403);
  const pref=`users/${staff.localId}/storePreferences/${id}`;
  assert.equal((await patch(pref,staff,{reportEmails:{booleanValue:false}})).status,200,'Own opt-out');
  assert.equal((await patch(pref,customer,{reportEmails:{booleanValue:true}})).status,403,'Other user preference denied');
  assert.equal((await patch(pref,staff,{reportEmails:{stringValue:'false'}})).status,403,'Non-boolean denied');
  assert.equal((await patch(pref,staff,{reportEmails:{booleanValue:true}})).status,200,'Own opt-in');
  console.log('PASS: receipt upload/read/link, cross-user denials, size/type rejection, avatars, profile ownership and email preferences.');
 } finally{
  for(const path of new Set(objects)){
   assert.ok(path.startsWith(`stores/${id}/`) || users.some(u=>path===`user-avatars/${u.localId}/test.png`));
   const r=await fetch(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(path)}`,{method:'DELETE',headers:{Authorization:`Bearer ${await token()}`}});
   assert.ok([204,404].includes(r.status),'Cleanup object failed: '+r.status);
  }
  await db.recursiveDelete(db.collection('stores').doc(id));
  for(const u of users){await db.recursiveDelete(db.collection('users').doc(u.localId));await getAuth().deleteUser(u.localId);}
  console.log('Temporary test images, store and accounts removed.');
 }
})().catch(e=>{console.error(e.message);process.exitCode=1});
