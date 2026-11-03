const {createHash}=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const {shelfLife,expiryStage}=require('./commerce_logic');
const key=token=>createHash('sha256').update(token).digest('hex');
function notificationHandlers({db,messaging,serverTimestamp,Timestamp}) {
  async function tokens(uid,type){
    const profile=(await db.collection('users').doc(uid).get()).data()||{};
    const flag=type==='expiry'?'expiryAlerts':'orders';if((type==='expiry'?profile.preferences?.expiryAlerts:(profile.preferences?.orderUpdates??profile.preferences?.orders))===false)return [];
    const devices=await db.collection('users').doc(uid).collection('devices').get();const result=[];
    for(const device of devices.docs){const token=device.data().token;if(typeof token!=='string')continue;
      const owner=await db.collection('pushInstallations').doc(key(token)).get();if(owner.data()?.uid===uid)result.push(token);}
    return result;
  }
  async function notify(uid,title,body,data,type){
    const list=await tokens(uid,type);if(!list.length)return;
    for(let i=0;i<list.length;i+=500){const chunk=list.slice(i,i+500);const reply=await messaging.sendEachForMulticast({tokens:chunk,notification:{title,body},
      data:Object.fromEntries(Object.entries({...data,recipientUid:uid}).map(([k,v])=>[k,String(v)])),android:{priority:'high',notification:{channelId:'stockwise_updates',sound:'default'}},apns:{payload:{aps:{sound:'default'}}}});
      for(let j=0;j<reply.responses.length;j++)if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(reply.responses[j].error?.code)){
        await db.collection('users').doc(uid).collection('devices').doc(key(chunk[j])).delete();await db.collection('pushInstallations').doc(key(chunk[j])).delete();
      }
    }
  }
  async function recipients(store){const members=await store.collection('members').get();return members.docs.filter(m=>m.data().isActive===true&&['owner','admin','manager','staff'].includes(m.data().role)).map(m=>m.id);}
  async function cleanup(store,ref,now=new Date()){
    return db.runTransaction(async tx=>{const snap=await tx.get(ref);if(!snap.exists)return;
      const b=snap.data();if(!b.expiryAt?.toDate||b.expiryAt.toDate()>now)return;
      tx.set(store.collection('inventoryArchive').doc(ref.id),{...b,removedAt:serverTimestamp(),removalReason:'expired'});
      if(b.quantityOnHand>0)tx.set(store.collection('inventoryEvents').doc(`expiry-${ref.id}`),{storeId:store.id,batchId:ref.id,productId:b.productId,
        productName:b.productName,categoryId:b.categoryId||'others',eventType:'expired',quantity:b.quantityOnHand,quantityDelta:-b.quantityOnHand,actorUid:'system',occurredAt:serverTimestamp()});
      tx.delete(ref);
    });
  }
  return {
    registerPushToken:async request=>{
      const token=request.data?.token,uid=request.auth?.uid;
      if(!uid)throw new HttpsError('unauthenticated','Please sign in.');
      if(typeof token!=='string'||token.length<20||token.length>4096)throw new HttpsError('invalid-argument','Invalid device registration.');
      const id=key(token);await db.runTransaction(async tx=>{const ref=db.collection('pushInstallations').doc(id),previous=await tx.get(ref);
        if(previous.exists&&previous.data().uid!==uid)tx.delete(db.collection('users').doc(previous.data().uid).collection('devices').doc(id));
        tx.set(ref,{uid,updatedAt:serverTimestamp()});tx.set(db.collection('users').doc(uid).collection('devices').doc(id),{token,updatedAt:serverTimestamp(),platform:request.data.platform||'android'});
      });return {registered:true};
    },
    unregisterPushToken:async request=>{const uid=request.auth?.uid,token=request.data?.token;if(!uid||typeof token!=='string')return {removed:false};
      const ref=db.collection('pushInstallations').doc(key(token));await db.runTransaction(async tx=>{const snap=await tx.get(ref);if(snap.data()?.uid===uid)tx.delete(ref);tx.delete(db.collection('users').doc(uid).collection('devices').doc(key(token)));});return {removed:true};},
    newOrder:async event=>{const data=event.data?.data();if(!data)return;const store=db.collection('stores').doc(event.params.storeId);
      const shop=(await store.get()).data();if(shop?.status!=='active')return;
      for(const uid of await recipients(store))await notify(uid,'New order',`${data.orderNumber} was placed in ${shop.name}.`,{storeId:store.id,orderId:event.params.orderId,type:'new_order'},'order');
    },
    chatMessage:async event=>{const data=event.data?.data();if(!data)return;const store=db.collection('stores').doc(event.params.storeId);
      const shop=(await store.get()).data();if(shop?.status!=='active')return;
      const team=await store.collection('members').get();
      const uids=data.senderRole==='customer'?team.docs.filter(d=>d.data().isActive===true&&['owner','admin'].includes(d.data().role)).map(d=>d.id):[event.params.customerId];
      for(const uid of uids)if(uid!==data.senderId)await notify(uid,`${data.senderName} · ${shop.name}`,data.text||'Sent an attachment',
        {storeId:store.id,customerId:event.params.customerId,type:'chat'},'order');
    },
    inventoryWritten:async event=>{const after=event.data?.after;if(!after?.exists)return;
      const b=after.data(),now=new Date(),store=db.collection('stores').doc(event.params.storeId);
      if(b.expiryAt?.toDate&&b.expiryAt.toDate()<=now){await cleanup(store,after.ref,now);return;}
      if(!b.expiryAt?.toDate)return;const life=shelfLife(b,now);
      if(b.totalShelfLifeDays!==life.totalShelfLifeDays||b.shelfLifeType!==life.shelfLifeType)await after.ref.update({totalShelfLifeDays:life.totalShelfLifeDays,shelfLifeType:life.shelfLifeType,receivedAt:b.receivedAt||b.createdAt||Timestamp.fromDate(now)});
    },
    inventoryClock:async()=>{
      const now=new Date(),stores=await db.collection('stores').where('status','==','active').get();
      for(const shop of stores.docs){const store=shop.ref,inventory=await store.collection('inventoryBatches').get();
        for(const doc of inventory.docs){const b=doc.data();if(!b.expiryAt?.toDate)continue;
          if(b.expiryAt.toDate()<=now){await cleanup(store,doc.ref,now);continue;}
          const life=shelfLife(b,now);if(b.totalShelfLifeDays!==life.totalShelfLifeDays||b.shelfLifeType!==life.shelfLifeType)await doc.ref.update({totalShelfLifeDays:life.totalShelfLifeDays,shelfLifeType:life.shelfLifeType,receivedAt:b.receivedAt||b.createdAt||Timestamp.fromDate(now)});
          const stage=expiryStage(b,shop.data(),now);if(!stage)continue;
          const marker=store.collection('expiryNotifications').doc(`${doc.id}-${b.expiryAt.toMillis()}-${stage}`);
          const claimed=await db.runTransaction(async tx=>{const snap=await tx.get(marker);if(snap.exists)return false;tx.create(marker,{batchId:doc.id,stage,createdAt:serverTimestamp()});return true;});
          if(!claimed)continue;
          const title=stage===4?'Last expiry reminder':`${b.productName} expires soon`;
          const body=stage===4?`${b.productName}: review remaining stock before closing.`:`${b.productName}: ${life.daysLeft} day${life.daysLeft===1?'':'s'} left.`;
          try{for(const uid of await recipients(store))await notify(uid,title,body,{storeId:store.id,batchId:doc.id,type:'expiry',stage},'expiry');}
          catch(e){await marker.delete();throw e;}
        }
      }
    },
  };
}
module.exports={notificationHandlers};
