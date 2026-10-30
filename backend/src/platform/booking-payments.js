const express=require('express')
const {z}=require('zod')
const {createHash}=require('node:crypto')
const {handler,reply,fail,atomic,compareAndSet,requireRecord,requestIdentity,id}=require('./core')
const {paise,notify,notifyAdmins}=require('./business')
const {mobileAuth}=require('./mobileAuth')

function createBookingPaymentsRouter({db,razorpay}){
 const router=express.Router()
 router.post('/payments/razorpay/webhook',handler(async(req,res)=>{
  if(!razorpay)fail(503,'RAZORPAY_NOT_CONFIGURED','Razorpay is not configured.')
  if(!razorpay.verifyWebhook(req.rawBody,req.get('x-razorpay-signature')))fail(401,'INVALID_WEBHOOK_SIGNATURE','Webhook signature is invalid.')
  let event
  try{event=JSON.parse(req.rawBody.toString('utf8'))}catch{fail(400,'INVALID_WEBHOOK','Invalid webhook payload.')}
  if(!['qr_code.credited','payment.captured'].includes(event.event))return reply(req,res,{received:true})
  const payment=event.payload?.payment?.entity
  const qrCodeId=event.payload?.qr_code?.entity?.id||payment?.qr_code_id
  if(!payment||!qrCodeId||payment.status!=='captured')return reply(req,res,{received:true})
  if(typeof payment.id!=='string'||!payment.id.startsWith('pay_'))fail(400,'INVALID_PAYMENT','Invalid payment identifier.')
  // A deterministic transaction identity makes duplicate webhook delivery harmless.
  const paymentId=id(createHash('sha256').update('razorpay:'+payment.id).digest('hex').slice(0,24))
  const webhookReq={...req,auth:{user:{_id:paymentId}},actorType:'razorpay',body:{event:event.event}}
  await atomic(db,webhookReq,'payment.razorpay_verified','payments',async session=>{
   const qr=await db.collection('payment_qr_codes').findOne({providerQrCodeId:qrCodeId},{session})
   if(!qr)fail(404,'PAYMENT_QR_NOT_FOUND','Payment QR was not found.')
   if(paise(payment.amount)!==paise(qr.amountPaise)||payment.currency!=='INR')fail(400,'PAYMENT_AMOUNT_MISMATCH','Payment amount or currency does not match the final bill.')
   const previous=await db.collection('payments').findOne({_id:paymentId},{session})
   if(previous){if(String(previous.bookingId)!==String(qr.bookingId))fail(409,'PAYMENT_CONFLICT','Payment belongs to another booking.');return previous}
   const booking=await requireRecord(db,'bookings',qr.bookingId,session)
   if(!['in_progress','completed'].includes(booking.status)||booking.paymentQrCodeId!==qrCodeId||paise(booking.totalPaise)!==paise(qr.amountPaise))fail(409,'BOOKING_AMOUNT_CHANGED','Booking no longer matches this QR.')
   if(booking.paymentStatus==='paid')fail(409,'PAYMENT_ALREADY_RECEIVED','Booking already has a recorded payment.')
   const now=new Date()
   const result={_id:paymentId,bookingId:booking._id,customerId:booking.customerId,workerId:booking.workerId,amountPaise:paise(qr.amountPaise),method:'upi',provider:'razorpay',providerPaymentId:payment.id,status:'paid',verification:'provider_verified',paidAt:now,createdAt:now,isActive:true}
   await db.collection('payments').insertOne(result,{session})
   await compareAndSet(db,'bookings',booking,{paymentStatus:'paid',paymentMethod:'razorpay_qr',paidAt:now},session)
   await db.collection('payment_qr_codes').updateOne({_id:qr._id},{$set:{status:'paid',providerPaymentId:payment.id,paidAt:now,updatedAt:now}},{session})
   await db.collection('booking_events').insertOne({_id:paymentId,bookingId:booking._id,type:'payment_verified_awaiting_completion_otp',providerPaymentId:payment.id,createdAt:now},{session})
   await notify(db,session,booking.customerId,'booking.payment_received',booking._id,payment.id)
   await notify(db,session,booking.workerUserId,'booking.payment_received',booking._id,payment.id)
   await notifyAdmins(db,session,'booking.payment_received',booking._id,'payments.read')
   return result
  })
  reply(req,res,{received:true})
 }))
 const worker=express.Router()
 worker.post('/bookings/:id/payment-qr',mobileAuth({db}).forApp('worker'),handler(async(req,res)=>{
  z.object({}).strict().parse(req.body||{})
  if(!razorpay?.isConfigured())fail(503,'RAZORPAY_NOT_CONFIGURED','Razorpay QR payments are not configured.')
  const identity=requestIdentity(req,'booking.payment-qr.'+req.params.id)
  const booking=await atomic(db,req,'booking.payment.prepare','bookings',async session=>{
   const profile=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
   if(!profile)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
   const before=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id})
   if(!['in_progress','completed'].includes(before.status))fail(409,'INVALID_TRANSITION','Finish the service before requesting payment.')
   if(before.paymentMethod==='cash'&&(before.status!=='in_progress'||before.serviceFinishedAt))fail(409,'CASH_RECONCILIATION_REQUIRED','Cash bookings must be reported and reconciled by an administrator.')
   if(before.paymentStatus==='paid')fail(409,'PAYMENT_ALREADY_RECEIVED','This booking has already been paid.')
   if(before.durationExtension?.status==='pending')fail(409,'EXTENSION_DECISION_PENDING','Wait for the customer extension decision.')
   if(before.durationExtension?.status==='approved'&&!before.durationExtension.adminOtpVerifiedAt)fail(409,'EXTENSION_OTP_REQUIRED','Verify the admin continuation OTP before finalizing the bill.')
   if(await db.collection('booking_extra_services').countDocuments({bookingId:before._id,status:'pending'},{session}))fail(409,'EXTRA_SERVICE_APPROVAL_PENDING','Resolve pending extra services before generating the final bill.')
   if(paise(before.totalPaise)<=0)fail(400,'INVALID_BOOKING_AMOUNT','Booking total must be positive.')
   if(before.serviceFinishedAt)return before
   const now=new Date()
   const updated=await compareAndSet(db,'bookings',before,{serviceFinishedAt:now,paymentStatus:'pending',paymentMethod:'razorpay_qr'},session)
   await db.collection('booking_events').insertOne({bookingId:before._id,type:'service_finished_awaiting_payment',amountPaise:paise(before.totalPaise),createdAt:now,actorUserId:req.auth.user._id},{session})
   return updated
  })
  const qrReply=record=>({id:record.providerQrCodeId,imageUrl:record.imageUrl,amountPaise:paise(record.amountPaise),status:record.status})
  const existing=await db.collection('payment_qr_codes').findOne({bookingId:booking._id,status:'created'})
  if(existing){if(paise(existing.amountPaise)!==paise(booking.totalPaise))fail(409,'BOOKING_AMOUNT_CHANGED','Existing QR does not match the bill.');return reply(req,res,qrReply(existing))}
  // Reserve creation without keeping a database transaction open over provider I/O.
  const reserved=await db.collection('bookings').updateOne({_id:booking._id,paymentStatus:{$ne:'paid'},paymentQrCodeId:{$exists:false},paymentQrRequestId:{$exists:false}},{$set:{paymentQrRequestId:identity._id},$inc:{_revision:1}})
  if(!reserved.modifiedCount)fail(409,'PAYMENT_QR_IN_PROGRESS','QR creation is already in progress. Refresh the booking before retrying.')
  let providerQr
  try{
   providerQr=await razorpay.createQrCode({bookingId:String(booking._id),amountPaise:paise(booking.totalPaise)})
   const uri=new URL(providerQr.image_url)
   if(uri.protocol!=='https:'||!providerQr.id?.startsWith('qr_'))fail(502,'INVALID_PAYMENT_QR','Provider returned invalid QR metadata.')
   const record={_id:id(createHash('sha256').update('qr:'+providerQr.id).digest('hex').slice(0,24)),providerQrCodeId:providerQr.id,bookingId:booking._id,workerUserId:req.auth.user._id,amountPaise:paise(booking.totalPaise),currency:'INR',imageUrl:providerQr.image_url,status:'created',createdAt:new Date(),isActive:true}
   await atomic(db,req,'booking.payment.qr_created','bookings',async session=>{
    const current=await requireRecord(db,'bookings',booking._id,session,{paymentQrRequestId:identity._id,paymentStatus:{$ne:'paid'}})
    await db.collection('payment_qr_codes').insertOne(record,{session})
    return compareAndSet(db,'bookings',current,{paymentQrCodeId:providerQr.id},session)
   })
   reply(req,res,qrReply(record),201)
  }catch(error){
   // After provider success keep the reservation: uncertain creation must never
   // silently issue a second payable QR. An operator must reconcile that case.
   req.log?.error({errorCode:error.code||'QR_CREATION_UNCERTAIN'},'Payment QR creation requires reconciliation')
   fail(503,'PAYMENT_QR_RECONCILIATION_REQUIRED','QR creation could not be confirmed. Ask an administrator to reconcile the provider request before retrying; payment has not been marked received.')
  }
 }))
 router.use('/worker',worker)
 return router
}
module.exports={createBookingPaymentsRouter}
