// Exercises deployed chat rules with temporary accounts/stores only. Sends no real messages or email.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const users = [];
const storeIds = [`chat_test_${randomUUID()}`, `chat_test_${randomUUID()}`];
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
const strings = data => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, {stringValue: value}]));
async function request(url, body, idToken, method = 'POST') {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(idToken ? {Authorization: `Bearer ${idToken}`} : {})}, body: body ? JSON.stringify(body) : undefined});
  const text = await response.text();
  return {status: response.status, data: text ? JSON.parse(text) : null};
}
async function signUp(name) {
  const email = `stockwise-chat-test-${randomUUID()}@example.invalid`;
  const password = randomUUID() + 'Aa9!';
  const result = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {email, password, returnSecureToken: true});
  assert.equal(result.status, 200, 'Temporary sign-up failed');
  const user = {...result.data, password, name}; users.push(user);
  await adminSet(`users/${user.localId}`, {displayName: name});
  return user;
}
async function commit(user, writes) { return request(base + ':commit', {writes}, user.idToken); }
const conversationPath = (store, customer) => `stores/${store}/conversations/${customer.localId}`;
const read = (user, path) => request(`${base}/${path}`, null, user.idToken, 'GET');
const patch = (path, data, transforms = []) => ({
  update: {name: `${prefix}/${path}`, fields: data}, updateMask: {fieldPaths: Object.keys(data)},
  ...(transforms.length ? {updateTransforms: transforms.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {}),
});
async function adminSet(path, data) {
  const fields = Object.fromEntries(Object.entries(data).map(([key, value]) => [key,
    typeof value === 'boolean' ? {booleanValue: value} : {stringValue: value}]));
  const result = await request(`${base}/${path}`, {fields}, await token(), 'PATCH');
  assert.equal(result.status, 200, 'Temporary fixture setup failed');
}
async function adminDelete(path, access) {
  const result = await request(`${base}/${path}`, null, access, 'DELETE');
  assert.ok([200, 204, 404].includes(result.status), 'Temporary fixture cleanup failed');
}
async function deleteTestStore(store) {
  assert.ok(store.startsWith('chat_test_'));
  const access = await token();
  for (const collection of ['members', 'conversations']) {
    const result = await request(`${base}/stores/${store}/${collection}?pageSize=1000`, null, access, 'GET');
    assert.equal(result.status, 200, 'Temporary fixture listing failed');
    assert.ok(!result.data.nextPageToken, 'Unexpected test fixture volume');
    for (const doc of result.data.documents || []) {
      const path = doc.name.slice(prefix.length + 1);
      assert.ok(path.startsWith(`stores/${store}/${collection}/`));
      if (collection === 'conversations') {
        const messages = await request(`${base}/${path}/messages?pageSize=1000`, null, access, 'GET');
        assert.equal(messages.status, 200);
        assert.ok(!messages.data.nextPageToken);
        for (const message of messages.data.documents || []) {
          const messagePath = message.name.slice(prefix.length + 1);
          assert.ok(messagePath.startsWith(`${path}/messages/`));
          await adminDelete(messagePath, access);
        }
      }
      await adminDelete(path, access);
    }
  }
  await adminDelete(`stores/${store}`, access);
}
function sendWrites(store, customer, sender, text, {first = false, role = sender === customer ? 'customer' : 'admin', senderId = sender.localId, senderName = sender.name} = {}) {
  const path = conversationPath(store, customer);
  const messageId = randomUUID();
  const metadata = strings({lastMessageId: messageId, lastMessage: text, lastSenderId: senderId, lastSenderRole: role});
  if (role === 'customer') metadata.customerName = {stringValue: senderName};
  if (first) Object.assign(metadata, strings({storeId: store, customerId: customer.localId}), {adminReadAt: {nullValue: null}});
  return [
    patch(`${path}/messages/${messageId}`, strings({senderId, senderName, senderRole: role, text}), ['sentAt']),
    patch(path, metadata, ['lastMessageAt', role === 'admin' ? 'adminReadAt' : 'customerReadAt']),
  ];
}
async function expectSend(user, writes, expected = 200) {
  const result = await commit(user, writes);
  assert.equal(result.status, expected, `Chat commit expected ${expected}, got ${result.status}: ${result.data?.error?.message || ''}`);
  return result;
}
async function query(user, store, customer) {
  return request(`${base}/${customer ? conversationPath(store, customer) : `stores/${store}`}:runQuery`, {
    structuredQuery: {from: [{collectionId: customer ? 'messages' : 'conversations'}], orderBy: [{field: {fieldPath: customer ? 'sentAt' : 'lastMessageAt'}, direction: 'DESCENDING'}]},
  }, user.idToken);
}
(async () => {
  try {
    const customer = await signUp('Chat Customer');
    const other = await signUp('Other Customer');
    const admin = await signUp('Chat Admin');
    const staff = await signUp('Chat Staff');
    const [store, otherStore] = storeIds;
    await adminSet(`stores/${store}`, {name: 'Temporary chat test', ownerUid: admin.localId, status: 'active'});
    await adminSet(`stores/${otherStore}`, {name: 'Other temporary chat test', ownerUid: other.localId, status: 'active'});
    await adminSet(`stores/${store}/members/${admin.localId}`, {userId: admin.localId, role: 'admin', isActive: true});
    await adminSet(`stores/${store}/members/${staff.localId}`, {userId: staff.localId, role: 'staff', isActive: true});
    await adminSet(`stores/${otherStore}/members/${other.localId}`, {userId: other.localId, role: 'owner', isActive: true});
    const path = conversationPath(store, customer);
    assert.equal((await read(customer, path)).status, 404, 'Customer can open missing own chat');
    assert.equal((await query(customer, store, customer)).status, 200, 'Empty own history can be queried');
    await expectSend(admin, sendWrites(store, customer, admin, 'Unsolicited chat', {first: true}), 403);
    await expectSend(customer, sendWrites(store, customer, customer, 'Hello store admin', {first: true}));
    let thread = (await read(admin, path)).data.fields;
    assert.equal(thread.customerName.stringValue, customer.name);
    assert.equal(thread.lastMessage.stringValue, 'Hello store admin');
    assert.equal(thread.adminReadAt.nullValue, null);
    assert.equal(thread.customerReadAt.timestampValue, thread.lastMessageAt.timestampValue);
    assert.equal((await query(admin, store)).status, 200, 'Admin inbox ordered query');
    assert.equal((await query(customer, store)).status, 403, 'Customer cannot list inbox');
    assert.equal((await read(other, path)).status, 403, 'Other customer/store owner cannot read');
    assert.equal((await query(other, store, customer)).status, 403);
    assert.equal((await query(staff, store)).status, 403, 'Staff has no admin inbox');
    assert.equal((await read(staff, path)).status, 403);
    await expectSend(admin, [patch(path, {adminReadAt: thread.lastMessageAt})]);
    thread = (await read(admin, path)).data.fields;
    assert.equal(thread.adminReadAt.timestampValue, thread.lastMessageAt.timestampValue);
    await expectSend(customer, sendWrites(store, customer, customer, 'Customer impersonates admin', {role: 'admin'}), 403);
    await expectSend(other, sendWrites(store, customer, other, 'Other customer attack', {role: 'customer'}), 403);
    await expectSend(staff, sendWrites(store, customer, staff, 'Staff impersonates admin', {role: 'admin'}), 403);
    await expectSend(customer, sendWrites(store, customer, customer, 'Spoof sender', {senderId: admin.localId}), 403);
    await expectSend(customer, sendWrites(store, customer, customer, 'Spoof name', {senderName: admin.name}), 403);
    await expectSend(customer, sendWrites(store, customer, customer, 'x'.repeat(2001)), 403);
    await expectSend(customer, sendWrites(store, customer, customer, ''), 403);
    await expectSend(customer, [patch(path, strings({lastMessage: 'Forged preview'}), ['lastMessageAt'])], 403);
    await expectSend(admin, sendWrites(store, customer, admin, 'Hello customer, how can we help?'));
    const replies = await query(customer, store, customer);
    assert.equal(replies.status, 200);
    assert.equal(replies.data.filter(row => row.document).length, 2);
    assert.equal(replies.data[0].document.fields.senderRole.stringValue, 'admin');
    const messagePath = replies.data[0].document.name.slice(prefix.length + 1);
    await expectSend(admin, [patch(messagePath, strings({text: 'Edit history'}))], 403);
    await expectSend(customer, [{delete: `${prefix}/${messagePath}`}], 403);
    thread = (await read(customer, path)).data.fields;
    assert.notEqual(thread.customerReadAt.timestampValue, thread.lastMessageAt.timestampValue, 'Admin reply remains unread');
    await expectSend(admin, [patch(path, {customerReadAt: thread.lastMessageAt})], 403);
    await expectSend(customer, [patch(path, {customerReadAt: {timestampValue: '2099-01-01T00:00:00Z'}})], 403);
    await expectSend(customer, [patch(path, {customerReadAt: thread.lastMessageAt})]);
    const login = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {email: customer.email, password: customer.password, returnSecureToken: true});
    assert.equal(login.status, 200);
    const persisted = (await read({...customer, idToken: login.data.idToken}, path)).data.fields;
    assert.equal(persisted.lastMessage.stringValue, 'Hello customer, how can we help?');
    assert.equal(persisted.customerReadAt.timestampValue, persisted.lastMessageAt.timestampValue);
    await expectSend(customer, sendWrites(otherStore, customer, customer, 'Separate store conversation', {first: true}));
    assert.equal((await read(admin, conversationPath(otherStore, customer))).status, 403, 'Admin cannot read another store');
    await expectSend(customer, sendWrites(store, customer, customer, 'Another question'));
    await adminSet(`stores/${store}/members/${admin.localId}`, {userId: admin.localId, role: 'admin', isActive: false});
    await expectSend(admin, sendWrites(store, customer, admin, 'Revoked admin'), 403);
    assert.equal((await read(admin, path)).status, 403);
    console.log('PASS: live private customer/admin chat, inbox/history queries, persistent replies/read markers, roles and spoof/edit protections.');
  } finally {
    for (const store of storeIds) {
      assert.ok(store.startsWith('chat_test_'));
      await deleteTestStore(store);
    }
    for (const user of users) {
      assert.ok(user.email.startsWith('stockwise-chat-test-'));
      await adminDelete(`users/${user.localId}`, await token());
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary chat stores, messages, accounts and profiles removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
