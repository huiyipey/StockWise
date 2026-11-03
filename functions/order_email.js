// Customer order confirmations use the authenticated account address, never a client-supplied recipient.
const {orderConfirmation}=require('./order_email_template');
const {orderImages}=require('./order_email_images');
function orderEmailHandlers({db,auth,transportFactory,serverTimestamp,bucket,now=()=>Date.now()}){
 async function deliver(storeId,orderId){
  const store=db.collection('stores').doc(storeId),queue=store.collection('orderEmails').doc(orderId);
  const claimed=await db.runTransaction(async tx=>{const saved=(await tx.get(queue)).data();
   if(saved&&['sent','sending','uncertain','skipped'].includes(saved.status))return false;
   if(saved?.status==='preparing'&&saved.leaseUntilMs>now())return false;
   tx.set(queue,{storeId,orderId,status:'preparing',leaseUntilMs:now()+10*60*1000,updatedAt:serverTimestamp()},{merge:true});return true;});
  if(!claimed)return;
  let mail,started=false;
  try{
   const [shop,orderDoc,rows]=await Promise.all([store.get(),store.collection('orders').doc(orderId).get(),store.collection('orders').doc(orderId).collection('items').get()]);
   if(!shop.exists||!orderDoc.exists){await queue.update({status:'skipped',updatedAt:serverTimestamp()});return;}
   const order=orderDoc.data(),user=await auth.getUser(order.userId);
   if(user.disabled||!user.email||user.email.endsWith('.invalid')){await queue.update({status:'skipped',updatedAt:serverTimestamp()});return;}
   mail=await transportFactory();
   const items=rows.docs.map(doc=>doc.data());
   const {imagesByPath,attachments}=await orderImages(bucket,storeId,items);
   const message=orderConfirmation(shop.data(),order,items,{customerName:user.displayName,imagesByPath,orderId});
   await queue.update({status:'sending',updatedAt:serverTimestamp()});started=true;
   const result=await mail.transport.sendMail({from:mail.from,to:user.email,...message,attachments});
   if(!result?.accepted?.some(address=>(typeof address==='string'?address:address.address)?.toLowerCase()===user.email.toLowerCase()))throw Error('Mail provider did not accept the recipient.');
   await queue.update({status:'sent',deliveryStatus:'accepted_by_mail_provider',messageId:result.messageId||null,sentAt:serverTimestamp(),updatedAt:serverTimestamp()});
  }catch(e){
   // Do not automatically repeat an ambiguous SMTP attempt; it could duplicate an accepted email.
   await queue.update({status:started?'uncertain':'configuration_required',updatedAt:serverTimestamp()});
   console.warn(started?'Order confirmation delivery requires review.':'Order confirmation sender requires configuration.');
  }finally{mail?.transport?.close();}
 }
 return {
  created:event=>event.data?deliver(event.params.storeId,event.params.orderId):Promise.resolve(),
  retry:async()=>{try{const sender=await transportFactory();sender.transport.close();}catch(_){return;}const stores=await db.collection('stores').where('status','==','active').get();for(const store of stores.docs){const pending=await store.ref.collection('orderEmails').where('status','in',['configuration_required','preparing']).limit(50).get();for(const doc of pending.docs)await deliver(store.id,doc.id);}},
 };
}
module.exports={orderConfirmation,orderEmailHandlers};
