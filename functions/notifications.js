const {createHash}=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const {shelfLife,titleCase}=require('./commerce_logic');
const {isActiveStoreAdmin}=require('./store_roles');
const {isImportedDemoOrder}=require('./demo_data');
const {inventoryExpiry}=require('./inventory_expiry');
// Hash identifiers used by notification delivery records.
const key=token=>createHash('sha256').update(token).digest('hex');
// Create shop and account notification handlers.
function notificationHandlers({db,messaging,serverTimestamp,Timestamp}) {
  // Read eligible device tokens after applying account preferences.
  async function tokens(uid,type){
    const profile=(await db.collection('users').doc(uid).get()).data()||{};
    const enabled=type==='expiry'?profile.preferences?.expiryAlerts:type==='promotion'?profile.preferences?.promotions:(profile.preferences?.orderUpdates??profile.preferences?.orders);if(enabled===false)return [];
    const devices=await db.collection('users').doc(uid).collection('devices').get();const result=[];
    for(const device of devices.docs){const token=device.data().token;if(typeof token!=='string')continue;
      const owner=await db.collection('pushInstallations').doc(key(token)).get();if(owner.data()?.uid===uid)result.push(token);}
    return result;
  }
  // Send the alert and remove device tokens rejected by FCM.
  async function notify(uid,title,body,data,type){
    const list=await tokens(uid,type);if(!list.length)return;
    for(let i=0;i<list.length;i+=500){const chunk=list.slice(i,i+500);const reply=await messaging.sendEachForMulticast({tokens:chunk,notification:{title,body},
      data:Object.fromEntries(Object.entries({...data,recipientUid:uid}).map(([k,v])=>[k,String(v)])),android:{priority:'high',notification:{channelId:'stockwise_updates',sound:'default'}},apns:{payload:{aps:{sound:'default'}}}});
      for(let j=0;j<reply.responses.length;j++)if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(reply.responses[j].error?.code)){
        await db.collection('users').doc(uid).collection('devices').doc(key(chunk[j])).delete();await db.collection('pushInstallations').doc(key(chunk[j])).delete();
      }
    }
  }
  // Claim the event before sending its notification.
  async function once(store, id, action) {
    const ref=store.collection('pushDeliveries').doc(key(id));
    const claimed=await db.runTransaction(async tx=>{const saved=await tx.get(ref);if(saved.exists)return false;tx.set(ref,{createdAt:serverTimestamp()});return true;});
    if(!claimed)return;
    try{await action();}catch(e){await ref.delete();throw e;}
  }
  // Find the active Admin accounts of this shop.
  async function recipients(store){const members=await store.collection('members').get();return members.docs.filter(m=>isActiveStoreAdmin(m.data())).map(m=>m.id);}
  const expiry = inventoryExpiry({db, Timestamp, serverTimestamp, sendReminder: async ({store, batchId, batch, stage, now}) => {
    const days = shelfLife(batch, now).daysLeft;
    const title = stage === 4 ? 'Last expiry reminder' : `${batch.productName} expires soon`;
    const body = stage === 4 ? `${batch.productName}: review remaining stock before closing.`
      : `${batch.productName}: ${days} day${days === 1 ? '' : 's'} left.`;
    for (const uid of await recipients(store)) {
      await notify(uid, title, body, {storeId: store.id, batchId, type: 'expiry', stage}, 'expiry');
    }
  }});
  return {
    // Associate this notification token with the signed-in account.
    registerPushToken:async request=>{
      const token=request.data?.token,uid=request.auth?.uid;
      if(!uid)throw new HttpsError('unauthenticated','Please sign in.');
      if(typeof token!=='string'||token.length<20||token.length>4096)throw new HttpsError('invalid-argument','Invalid device registration.');
      const id=key(token);await db.runTransaction(async tx=>{const ref=db.collection('pushInstallations').doc(id),previous=await tx.get(ref);
        if(previous.exists&&previous.data().uid!==uid)tx.delete(db.collection('users').doc(previous.data().uid).collection('devices').doc(id));
        tx.set(ref,{uid,updatedAt:serverTimestamp()});tx.set(db.collection('users').doc(uid).collection('devices').doc(id),{token,updatedAt:serverTimestamp(),platform:request.data.platform||'android'});
      });return {registered:true};
    },
    // Remove the signed-in account notification token.
    unregisterPushToken:async request=>{const uid=request.auth?.uid,token=request.data?.token;if(!uid||typeof token!=='string')return {removed:false};
      const ref=db.collection('pushInstallations').doc(key(token));await db.runTransaction(async tx=>{const snap=await tx.get(ref);if(snap.data()?.uid===uid)tx.delete(ref);tx.delete(db.collection('users').doc(uid).collection('devices').doc(key(token)));});return {removed:true};},
    // Notify active admins about this new order.
    newOrder:async event=>{const data=event.data?.data();if(!data||isImportedDemoOrder(data))return;const store=db.collection('stores').doc(event.params.storeId);
      const shop=(await store.get()).data();if(shop?.status!=='active')return;
      for(const uid of await recipients(store))await notify(uid,'New order',`${data.orderNumber} was placed in ${shop.name}.`,{storeId:store.id,orderId:event.params.orderId,type:'new_order'},'order');
    },
    // Notify the recipient while keeping the conversation shop-scoped.
    chatMessage:async event=>{const data=event.data?.data();if(!data)return;const store=db.collection('stores').doc(event.params.storeId);
      const shop=(await store.get()).data();if(shop?.status!=='active')return;
      const team=await store.collection('members').get();
      const uids=data.senderRole==='customer'?team.docs.filter(d=>isActiveStoreAdmin(d.data())).map(d=>d.id):[event.params.customerId];
      for(const uid of uids)if(uid!==data.senderId)await notify(uid,`${data.senderName} · ${shop.name}`,data.text||'Sent an attachment',
        {storeId:store.id,customerId:event.params.customerId,type:'chat'},'order');
    },
    // Notify the customer about a changed order status.
    orderStatus:async event=>{
      const before=event.data?.before?.data(),after=event.data?.after?.data();
      if(!before||!after||before.status===after.status||!after.userId)return;
      const store=db.collection('stores').doc(event.params.storeId),shop=(await store.get()).data();if(shop?.status!=='active')return;
      await once(store,`status-${store.id}-${event.params.orderId}-${after.status}`,()=>notify(after.userId,`Order ${after.orderNumber} updated`,
        `${titleCase(after.status.replaceAll('_',' '))}${after.cancellationReason?': '+after.cancellationReason:''}`,
        {storeId:store.id,orderId:event.params.orderId,type:'order_status'},'order'));
    },
    // Notify eligible customers about the current promotion.
    promotion:async event=>{
      const before=event.data?.before?.data(),after=event.data?.after?.data();
      if(!after||!after.promotionEnabled||after.status!=='active'||after.quantityOnHand<=0||!after.expiryAt?.toDate||after.expiryAt.toDate()<=new Date())return;
      // Build a stable key for this promotion notification.
      const signature=b=>JSON.stringify([b?.promotionEnabled,b?.promotion||null,b?.basePriceCents,b?.promotionPriceCents]);
      if(before&&signature(before)===signature(after))return;
      const store=db.collection('stores').doc(event.params.storeId),shop=(await store.get()).data();if(shop?.status!=='active')return;
      const [customers,members]=await Promise.all([db.collection('users').where('activeStoreId','==',store.id).get(),store.collection('members').get()]);
      const team=new Set(members.docs.filter(d=>isActiveStoreAdmin(d.data())).map(d=>d.id));
      await once(store,`promotion-${event.id||store.id+'-'+event.params.batchId+'-'+signature(after)}`,async()=>{
        for(const user of customers.docs)if(!team.has(user.id))await notify(user.id,`New promotion · ${shop.name}`,`${after.productName}${after.promotion?.label?': '+after.promotion.label:' is on promotion.'}`,{storeId:store.id,batchId:event.params.batchId,type:'promotion'},'promotion');
      });
    },
    inventoryWritten: async event => {
      const before = event.data?.before?.data(), after = event.data?.after?.data();
      if (before && after?.expiryAt?.toMillis && after.expiryAt.toMillis() > Date.now()) {
        const received = batch => (batch.receivedAt || batch.createdAt)?.toMillis?.();
        const life = shelfLife(after);
        if (before.expiryAt?.toMillis?.() === after.expiryAt.toMillis() && received(before) === received(after) &&
            before.status === after.status && before.notifyOnExpiry === after.notifyOnExpiry &&
            (before.quantityOnHand > 0) === (after.quantityOnHand > 0) &&
            after.totalShelfLifeDays === life.totalShelfLifeDays && after.shelfLifeType === life.shelfLifeType) return;
      }
      const store = db.collection('stores').doc(event.params.storeId);
      return expiry.sync(store, store.collection('inventoryBatches').doc(event.params.batchId), {classify: true});
    },
    storeHoursWritten: async event => {
      const before = event.data?.before?.data(), after = event.data?.after?.data();
      if (!after || (before?.status === after.status &&
          JSON.stringify(before?.operatingHours) === JSON.stringify(after.operatingHours))) return;
      return expiry.rescheduleStore(event.data.after.ref);
    },
    inventoryClock: expiry.runDue,
  };
}
// Export the helpers used by the app backend and tests.
module.exports={notificationHandlers};
