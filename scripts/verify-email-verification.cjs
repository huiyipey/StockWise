// Temporary .invalid accounts only. Never sends email to a real inbox.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {createRequire} = require('node:module');
const backendRequire = createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {Firestore} = backendRequire('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
const {api, token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId:project,credential:{getAccessToken:async()=>({access_token:await token(),expires_in:3500})}});
const auth = getAuth(), users=[];
const client = new OAuth2Client();
const db = new Firestore({projectId:project,preferRest:true,auth:new GoogleAuth({authClient:client})});
const base=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const activeStores={structuredQuery:{from:[{collectionId:'stores'}],where:{fieldFilter:{field:{fieldPath:'status'},op:'EQUAL',value:{stringValue:'active'}}},limit:1}};
async function request(url,body,idToken,method='POST') {
  const r=await fetch(url,{method,headers:{'Content-Type':'application/json',...(idToken?{Authorization:`Bearer ${idToken}`}:{})},body:body?JSON.stringify(body):undefined});
  const data=await r.json(); return {status:r.status,data};
}
const identity=(method,data)=>request(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${apiKey}`,data);
async function signup() {
  const email=`stockwise-verification-test-${randomUUID()}@example.invalid`,password='Verify1!'+randomUUID();
  const r=await identity('signUp',{email,password,returnSecureToken:true});
  assert.equal(r.status,200,'Temporary account creation failed.');
  const user={...r.data,email,password}; users.push(user); return user;
}
async function login(user) {
  const r=await identity('signInWithPassword',{email:user.email,password:user.password,returnSecureToken:true});
  assert.equal(r.status,200,'Temporary sign-in failed.'); user.idToken=r.data.idToken;
}
const call=(action,user,data={})=>request(`https://asia-southeast1-${project}.cloudfunctions.net/manageEmailVerification`,{data:{action,...data}},user?.idToken);
async function redeem(link) {
  const code=new URL(link).searchParams.get('oobCode'); assert.ok(code);
  const applied=await identity('update',{oobCode:code}); assert.equal(applied.status,200,'Native Firebase action failed.');
  const reused=await identity('update',{oobCode:code}); assert.equal(reused.status,400,'The verification action must be single-use.');
}
async function actionLink(email, newEmail) {
  // Generate a fixture action without delivering it to a real inbox.
  const result = await api('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode', 'POST', {
    targetProjectId: project, requestType: newEmail ? 'VERIFY_AND_CHANGE_EMAIL' : 'VERIFY_EMAIL', email,
    returnOobLink: true, ...(newEmail ? {newEmail} : {}),
  });
  return result.oobLink;
}
(async()=>{
  client.setCredentials({access_token:await token()});
  try {
    assert.equal((await call('status')).status,401);
    const user=await signup(), other=await signup();
    assert.notEqual((await auth.getUser(user.localId)).customClaims?.stockwise_legacy_account,true);
    const initial=await call('status',user,{verified:true,uid:other.localId});
    assert.equal(initial.status,200); assert.equal(initial.data.result.verified,false); assert.equal(initial.data.result.attempted,false);
    assert.equal((await request(base+':runQuery',activeStores,user.idToken)).status,403,'Unverified accounts cannot read stores.');
    assert.equal((await request(base+'/users/'+user.localId,{fields:{emailVerified:{booleanValue:true}}},user.idToken,'PATCH')).status,403,'Client cannot bypass verification with a profile.');
    const create=(u)=>request(`https://asia-southeast1-${project}.cloudfunctions.net/createStore`,{data:{name:'',shopAddress:''}},u.idToken);
    assert.equal((await create(user)).status,403,'Unverified accounts cannot call store APIs.');
    const sent=await call('send',user);
    const sentAt=Date.now();
    assert.equal(sent.status,200,JSON.stringify(sent.data)); assert.equal(sent.data.result.attempted,true); assert.equal(sent.data.result.verified,false);
    assert.ok(sent.data.result.resendAfter>0); assert.equal(sent.data.result.oobCode,undefined);
    assert.equal((await call('send',user)).status,429,'Resend cooldown must hold across clients.');
    assert.equal((await call('change',other,{email:user.email})).status,409,'An existing account address cannot be stolen.');
    const newEmail=`stockwise-verification-new-${randomUUID()}@example.invalid`;
    const oldEmail=other.email;
    const changed=await call('change',other,{email:newEmail});
    assert.equal(changed.status,200,JSON.stringify(changed.data)); assert.equal(changed.data.result.email,newEmail);
    const saved=await auth.getUser(other.localId);
    assert.equal(saved.email,newEmail,'Save must immediately change the actual signup email.');
    assert.equal(saved.emailVerified,false,'The saved address must still require verification.');
    const renewed=await identity('signInWithCustomToken',{token:changed.data.result.signInToken,returnSecureToken:true});
    assert.equal(renewed.status,200,'Same-account session continuation must work.');
    const resumedClaims=JSON.parse(Buffer.from(renewed.data.idToken.split('.')[1],'base64url').toString());
    assert.equal(resumedClaims.user_id,other.localId);
    other.email=newEmail;other.idToken=renewed.data.idToken;
    assert.equal((await call('send',other)).status,200,'The new email must receive an ordinary verification link.');
    assert.equal((await identity('signInWithPassword',{email:oldEmail,password:other.password,returnSecureToken:true})).status,400,'The former signup email must stop signing in.');
    await login(other);
    assert.equal((await call('status',other)).data.result.email,newEmail,'The new address must survive another session.');
    assert.equal((await create(other)).status,403,'An updated but unverified email must remain gated.');
    console.log('PASS: immediate same-account email save, unchanged password, former-email rejection, resend and verification gate.');
    const waitMs=Math.max(0,sentAt+65000-Date.now());
    if(waitMs) {console.log('Allowing the managed email provider cooldown to expire before generating test links.');await new Promise(resolve=>setTimeout(resolve,Math.min(waitMs,60000)));}
    await redeem(await actionLink(user.email));
    await login(user);
    assert.equal((await call('status',user)).data.result.verified,true);
    assert.equal((await request(base+':runQuery',activeStores,user.idToken)).status,200,'Verified accounts can enter stores.');
    assert.equal((await create(user)).status,400,'Verified callers reach ordinary input validation.');
    await redeem(await actionLink(other.email));
    await login(other);
    const confirmed=await auth.getUser(other.localId);
    assert.equal(confirmed.email,newEmail); assert.equal(confirmed.emailVerified,true);
    assert.equal((await call('status',other)).data.result.verified,true);
    // A separately created temporary legacy fixture exercises the exemption without touching real accounts.
    const legacy=await signup();
    await auth.setCustomUserClaims(legacy.localId,{stockwise_legacy_account:true}); await login(legacy);
    assert.equal((await request(base+':runQuery',activeStores,legacy.idToken)).status,200);
    assert.equal((await create(legacy)).status,400);
    const policy=(await db.collection('authPolicies').doc('emailVerification').get()).data();
    assert.ok(policy.cutoff);
    console.log('PASS: live signup gate, managed email requests, cooldown, address correction, single-use links, verified store access and legacy access.');
  } finally {
    for(const user of users) {
      assert.ok(user.localId);
      await db.collection('emailVerificationSessions').doc(user.localId).delete();
      await db.collection('users').doc(user.localId).delete();
      await auth.deleteUser(user.localId);
    }
    console.log('Temporary accounts removed. No real inbox emails or store records were changed.');
  }
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
