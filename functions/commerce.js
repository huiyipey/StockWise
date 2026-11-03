const {HttpsError}=require('firebase-functions/v2/https');
const {createHash}=require('node:crypto');
const {quoteCart,deliveryFee,orderingOpen,titleCase,operatingHours}=require('./commerce_logic');
const postcodes=require('./data/malaysia_postcodes.json');
const roles=['owner','admin','manager','staff'];
function storeRef(db,request) {
  if(!request.auth)throw new HttpsError('unauthenticated','Please sign in.');
  const id=request.data?.storeId;
  if(typeof id!=='string'||!/^[-\w]{1,128}$/.test(id))throw new HttpsError('invalid-argument','Select a store.');
  return db.collection('stores').doc(id);
}
async function team(tx,store,uid,owner=false) {
  const member=(await tx.get(store.collection('members').doc(uid))).data();
  if(member?.isActive!==true||!(owner?['owner','admin']:roles).includes(member.role))throw new HttpsError('permission-denied','Store team access is required.');
  return member;
}
function receiverDetails(value) {
  const result={};
  for(const key of ['name','phone','email','addressLine1','addressLine2','city','state','postalCode'])result[key]=typeof value?.[key]==='string'?value[key].trim():'';
  if(!result.name||!result.phone||!result.addressLine1||!result.city||!postcodes[result.postalCode]||Object.values(result).some(x=>x.length>250))throw new HttpsError('invalid-argument','Enter complete delivery details and a valid Malaysian postcode.');
  result.state=postcodes[result.postalCode][1];return result;
}
function commerceHandlers({db,serverTimestamp,Timestamp,now=()=>new Date(),bucket}) {
  const wrap=fn=>async request=>{try{return await fn(request);}catch(e){if(e instanceof HttpsError)throw e;throw new HttpsError('failed-precondition',e.message||'Please refresh and try again.');}};
  async function readQuote(tx,store,uid) {
    const [shop,settings,cart,batches]=await Promise.all([tx.get(store),tx.get(store.collection('settings').doc('commerce')),
      tx.get(store.collection('carts').doc(uid).collection('items')),tx.get(store.collection('inventoryBatches').where('status','==','active'))]);
    if(!shop.exists||shop.data().status!=='active')throw new HttpsError('not-found','This store is unavailable.');
    const source=cart.docs.map(d=>({id:d.id,...d.data()}));
    if(!source.length)throw new HttpsError('failed-precondition','Your cart is empty.');
    const inventory=batches.docs.map(d=>({id:d.id,...d.data()}));
    return {shop:shop.data(),settings:settings.data()||{},cart,inventory,quote:quoteCart(source,inventory,{now:now()})};
  }
  return {
    quoteCart:wrap(async request=>{
      const store=storeRef(db,request);
      return db.runTransaction(async tx=>{
        const data=await readQuote(tx,store,request.auth.uid), fee=deliveryFee(data.settings,request.data.postcode);
        const open=orderingOpen(data.shop,now());
        return {...data.quote,lines:data.quote.lines.map(l=>({...l,expiryAt:l.expiryAt.toISOString(),receivedAt:l.receivedAt.toISOString()})),deliveryFeeCents:fee,
          totalCents:fee===null?null:data.quote.subtotalCents+fee,canOrder:open&&fee!==null,orderingOpen:open,deliveryAvailable:fee!==null,
          message:!open?'Ordering is closed. Orders close 30 minutes before the store closes.':fee===null?'Delivery is not configured for this postcode. Please contact the store.':null};
      });
    }),
    placeOrder:wrap(async request=>{
      const store=storeRef(db,request), uid=request.auth.uid;
      const receiver=receiverDetails(request.data.receiver), payment=request.data.paymentMethod;
      if(!['Bank transfer','Touch n Go'].includes(payment))throw new HttpsError('invalid-argument','Choose a payment method.');
      const requestId=request.data.requestId;
      if(typeof requestId!=='string'||!/^[-\w]{1,80}$/.test(requestId))throw new HttpsError('invalid-argument','Refresh checkout.');
      const id=`${createHash('sha256').update(uid).digest('hex').slice(0,16)}-${requestId}`, order=store.collection('orders').doc(id);
      return db.runTransaction(async tx=>{
        const old=await tx.get(order);if(old.exists)return {id,orderNumber:old.data().orderNumber};
        const data=await readQuote(tx,store,uid);
        if(!orderingOpen(data.shop,now()))throw new HttpsError('failed-precondition','Ordering is closed. Orders close 30 minutes before the store closes.');
        const fee=deliveryFee(data.settings,receiver.postalCode);
        if(fee===null)throw new HttpsError('failed-precondition','Delivery is not configured for this postcode. Please contact the store.');
        if(data.quote.promotionWarnings.length && request.data.acceptedPromotionReviewToken!==data.quote.promotionReviewToken)
          throw new HttpsError('failed-precondition','Promotion availability changed. Review the unavailable offers before placing your order.');
        const total=data.quote.subtotalCents+fee;
        if(request.data.expectedTotalCents!==total)throw new HttpsError('failed-precondition','Your order total changed. Refresh checkout and review the new total.');
        const timestamp=serverTimestamp(), orderNumber=`SW-${now().getTime().toString().slice(-10)}`;
        for(const change of data.quote.stock){
          const batch=data.inventory.find(b=>b.id===change.id), remaining=batch.quantityOnHand-change.quantity;
          tx.update(store.collection('inventoryBatches').doc(change.id),{quantityOnHand:remaining,status:remaining===0?'depleted':'active',updatedAt:timestamp});
          tx.set(store.collection('inventoryEvents').doc(`${id}-${change.id}`),{storeId:store.id,batchId:change.id,productId:batch.productId,
            productName:batch.productName,categoryId:batch.categoryId,eventType:'sold',quantity:change.quantity,quantityDelta:-change.quantity,actorUid:uid,orderId:id,occurredAt:timestamp});
        }
        data.quote.lines.forEach((line,index)=>tx.set(order.collection('items').doc(String(index)),{...line,storeId:store.id,expiryAt:Timestamp.fromDate(line.expiryAt)}));
        data.cart.docs.forEach(doc=>tx.delete(doc.ref));
        tx.set(order,{storeId:store.id,orderNumber,userId:uid,status:'to_pay',paymentStatus:'unpaid',fulfillmentType:'delivery',receiver,
          payment:{methodLabel:payment},subtotalCents:data.quote.subtotalCents,shippingFeeCents:fee,totalCents:total,discountCents:data.quote.discountCents,
          unavailablePromotionsAccepted:data.quote.promotionWarnings,
          currency:'MYR',placedAt:timestamp,updatedAt:timestamp});
        return {id,orderNumber};
      });
    }),
    updateOrderStatus:wrap(async request=>{
      const store=storeRef(db,request), order=store.collection('orders').doc(request.data.orderId);
      return db.runTransaction(async tx=>{
        await team(tx,store,request.auth.uid);
        const saved=await tx.get(order);if(!saved.exists)throw new HttpsError('not-found','This order no longer exists.');
        const data=saved.data(), next=request.data.status;
        if(data.status===next)return {status:next};
        if(request.data.expectedStatus!==data.status)throw new HttpsError('aborted','This order changed. Refresh and try again.');
        const statuses=['to_pay','to_ship','to_receive','completed'];
        if(['cancelled','completed'].includes(data.status)||!['cancelled',...statuses].includes(next)||
          (next==='cancelled'?data.status!=='to_pay':statuses.indexOf(next)<statuses.indexOf(data.status)))throw new HttpsError('failed-precondition','This order cannot move to that status.');
        if(next!=='cancelled'&&!data.receiptPath)throw new HttpsError('failed-precondition','A payment receipt is required before shipping.');
        const reason=typeof request.data.reason==='string'?request.data.reason.trim():'';
        if(next==='cancelled'&&(!reason||reason.length>500))throw new HttpsError('invalid-argument','Enter a cancellation reason of 1-500 characters.');
        const rows=next==='cancelled'?(await tx.get(order.collection('items'))).docs.map(d=>d.data()):[];
        const quantities=new Map();for(const line of rows)quantities.set(line.batchId,(quantities.get(line.batchId)||0)+line.quantity);
        const savedBatches=new Map();for(const id of quantities.keys())savedBatches.set(id,await tx.get(store.collection('inventoryBatches').doc(id)));
        const archives=new Map();for(const [id,snap]of savedBatches)if(!snap.exists)archives.set(id,(await tx.get(store.collection('inventoryArchive').doc(id))).data());
        const stamp=serverTimestamp();
        for(const [id,quantity]of quantities){
          const snap=savedBatches.get(id), line=rows.find(l=>l.batchId===id), old=snap.data();
          if(snap.exists)tx.update(snap.ref,{quantityOnHand:old.quantityOnHand+quantity,status:'active',updatedAt:stamp});
          else tx.set(snap.ref,{...(archives.get(id)||{}),storeId:store.id,productId:line.productId,productName:line.productName,categoryId:line.categoryId||'others',imagePath:line.imagePath||null,
            expiryAt:line.expiryAt,unitLabel:line.unitLabel||'unit',basePriceCents:Math.max(1,archives.get(id)?.basePriceCents||line.regularUnitPriceCents||line.unitPriceCents),quantityOnHand:quantity,quantityReserved:0,
            promotionEnabled:false,promotionPriceCents:null,status:'active',createdAt:stamp,updatedAt:stamp,notifyOnExpiry:true});
          tx.set(store.collection('inventoryEvents').doc(`cancel-${order.id}-${id}`),{storeId:store.id,batchId:id,productId:line.productId,productName:line.productName,
            categoryId:line.categoryId||old?.categoryId||'others',eventType:'returned',quantity,quantityDelta:quantity,orderId:order.id,actorUid:request.auth.uid,occurredAt:stamp});
        }
        const paymentStatus=next==='cancelled'?data.paymentStatus:next==='to_pay'?'unpaid':'paid';
        tx.update(order,{status:next,paymentStatus,...(next==='cancelled'?{cancellationReason:reason,cancelledAt:stamp}:{}),updatedAt:stamp});
        tx.set(store.collection('notifications').doc(`order-${order.id}-${next}`),{storeId:store.id,recipientUid:data.userId,type:'order_status',
          title:`Order ${data.orderNumber} updated`,body:`Status: ${titleCase(next.replaceAll('_',' '))}${next==='cancelled'?`. ${reason}`:''}`,
          relatedCollection:'orders',relatedDocumentId:order.id,isRead:false,createdAt:stamp});
        return {status:next,paymentStatus,cancellationReason:reason};
      });
    }),
    discardInventory:wrap(async request=>{
      const store=storeRef(db,request), ref=store.collection('inventoryBatches').doc(request.data.batchId), quantity=request.data.quantity;
      if(!Number.isInteger(quantity)||quantity<1)throw new HttpsError('invalid-argument','Enter a valid quantity.');
      return db.runTransaction(async tx=>{
        await team(tx,store,request.auth.uid);const snap=await tx.get(ref);
        if(!snap.exists)throw new HttpsError('not-found','This inventory no longer exists.');
        const b=snap.data(),available=b.quantityOnHand-(b.quantityReserved||0);
        if(quantity>available)throw new HttpsError('failed-precondition',`Only ${available} units are available to discard.`);
        const remaining=b.quantityOnHand-quantity,stamp=serverTimestamp();
        tx.update(ref,{quantityOnHand:remaining,status:remaining===0?'depleted':'active',updatedAt:stamp});
        tx.set(store.collection('inventoryEvents').doc(),{storeId:store.id,batchId:ref.id,productId:b.productId,productName:b.productName,categoryId:b.categoryId,
          eventType:'discarded',quantity,quantityDelta:-quantity,actorUid:request.auth.uid,occurredAt:stamp});
        return {quantityOnHand:remaining};
      });
    }),
    removeInventory:wrap(async request=>{
      const store=storeRef(db,request),ref=store.collection('inventoryBatches').doc(request.data.batchId);
      return db.runTransaction(async tx=>{
        await team(tx,store,request.auth.uid);const snap=await tx.get(ref);if(!snap.exists)return {removed:true};
        const b=snap.data(),expired=b.expiryAt.toDate()<=now(),quantity=b.quantityOnHand;
        if(expired&&quantity>0)tx.set(store.collection('inventoryEvents').doc(`expiry-${ref.id}`),{storeId:store.id,batchId:ref.id,productId:b.productId,
          productName:b.productName,categoryId:b.categoryId,eventType:'expired',quantity,quantityDelta:-quantity,actorUid:request.auth.uid,occurredAt:serverTimestamp()});
        tx.set(store.collection('inventoryArchive').doc(ref.id),{...b,removedAt:serverTimestamp(),removalReason:'deleted'});
        tx.delete(ref);return {removed:true,wasteRecorded:expired&&quantity>0};
      });
    }),
    saveDeliveryFees:wrap(async request=>{
      const store=storeRef(db,request),mode=request.data.mode,fees=request.data.postcodeFees||{},fixed=request.data.fixedCents;
      if(!['fixed','postcode'].includes(mode)||!Number.isSafeInteger(fixed)||fixed<0||fixed>1000000||typeof fees!=='object'||Array.isArray(fees)||Object.keys(fees).length>5000||
        Object.entries(fees).some(([p,v])=>!postcodes[p]||!Number.isSafeInteger(v)||v<0||v>1000000))throw new HttpsError('invalid-argument','Enter valid delivery fees and Malaysian postcodes.');
      await db.runTransaction(async tx=>{await team(tx,store,request.auth.uid,true);tx.set(store.collection('settings').doc('commerce'),
        {storeId:store.id,deliveryFeeMode:mode,deliveryFeeCents:fixed,postcodeFees:fees,updatedAt:serverTimestamp()},{merge:true});});
      return {saved:true};
    }),
    deleteStore:wrap(async request=>{
      const store=storeRef(db,request);const data=await db.runTransaction(async tx=>{
        const member=await team(tx,store,request.auth.uid,true),snap=await tx.get(store);
        if(!snap.exists)throw new HttpsError('not-found','This store no longer exists.');
        if(member.role!=='owner'||snap.data().ownerUid!==request.auth.uid)throw new HttpsError('permission-denied','Only the store owner can delete this store.');
        if(request.data.confirmName!==snap.data().name)throw new HttpsError('invalid-argument','Confirm the store name before deleting.');
        tx.update(store,{status:'deleting',updatedAt:serverTimestamp()});return snap.data();
      });
      if(bucket)await bucket.deleteFiles({prefix:`stores/${store.id}/`});
      await db.recursiveDelete(store);
      if(data.nameKey){const name=db.collection('storeNames').doc(data.nameKey);await db.runTransaction(async tx=>{const snap=await tx.get(name);if(snap.data()?.storeId===store.id)tx.delete(name);});}
      return {deleted:true};
    }),
  };
}
module.exports={commerceHandlers,receiverDetails,storeRef,team};
