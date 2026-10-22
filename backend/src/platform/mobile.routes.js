const express=require('express')
const { z }=require('zod')
const { idSchema,id,money,fail,reply,handler,list,atomic,requestIdentity,compareAndSet,requireRecord }=require('./core')
const {cartSchema,quote,reserveCoupon,notify,notifyAdmins,ensureTransition}=require('./business')
const {mobileAuth}=require('./mobileAuth')
const reason=z.string().trim().min(3).max(1000)
function createMobileRouter({db,scheduling,serviceOtp,storage}){
 const router=express.Router(),auth=mobileAuth({db})
 for(const app of ['customer','worker']){
  const area=express.Router();area.use(auth.forApp(app))
  area.get('/profile',handler(async(req,res)=>reply(req,res,{user:req.auth.user,profile:await db.collection(app==='customer'?'customers':'workers').findOne({userId:req.auth.user._id})})))
  area.patch('/profile',handler(async(req,res)=>{
   const input=z.object({fullName:z.string().trim().min(2).max(120),email:z.email().optional()}).strict().parse(req.body)
   const result=await atomic(db,req,app+'.profile','users',async session=>{
    const user=await requireRecord(db,'users',req.auth.user._id,session)
    const updated=await compareAndSet(db,'users',user,input,session)
    await db.collection(app==='customer'?'customers':'workers').updateOne({userId:user._id},{$set:{fullName:input.fullName,email:input.email,updatedAt:new Date()}},{session})
    return {_id:updated._id,fullName:updated.fullName,email:updated.email}
   });reply(req,res,result)
  }))
  area.post('/logout',handler(async(req,res)=>{
   await db.collection('auth_sessions').updateOne({_id:req.auth.session._id},{$set:{isActive:false,revokedAt:new Date()}})
   reply(req,res,{loggedOut:true})
  }))
  area.get('/bookings',handler(async(req,res)=>reply(req,res,await list(db,'bookings',req.query,{scope:app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id},fields:['_id']}))))
  area.get('/bookings/:id',handler(async(req,res)=>{
   const scope=app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id}
   reply(req,res,await requireRecord(db,'bookings',req.params.id,undefined,scope))
  }))
  area.get('/notifications',handler(async(req,res)=>reply(req,res,await list(db,'notifications',req.query,{scope:{recipientUserId:req.auth.user._id},fields:['type']}))))
  area.patch('/notifications/:id/read',handler(async(req,res)=>{
   const notification=await db.collection('notifications').findOneAndUpdate({_id:id(req.params.id),recipientUserId:req.auth.user._id},{$set:{isRead:true}},{returnDocument:'after'})
   if(!notification)fail(404,'NOT_FOUND','Notification not found.');reply(req,res,notification)
  }))
  area.post('/support',handler(async(req,res)=>{
   const input=z.object({subject:reason,bookingId:idSchema,category:z.enum(['booking','assignment','payment','quality','other'])}).strict().parse(req.body)
   const identity=requestIdentity(req,app+'.support')
   const result=await atomic(db,req,'support.create','support_tickets',async session=>{
    const booking=await requireRecord(db,'bookings',input.bookingId,session,app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id})
    const previous=await db.collection('support_tickets').findOne({_id:identity._id},{session})
    if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
    const ticket={...identity,...input,bookingId:booking._id,userId:req.auth.user._id,appType:app,status:'open',priority:'normal',createdAt:new Date(),isActive:true}
    await db.collection('support_tickets').insertOne(ticket,{session});await notifyAdmins(db,session,'support.created',ticket._id,'support.read');return ticket
   });reply(req,res,result,201)
  }))
  area.get('/support',handler(async(req,res)=>reply(req,res,await list(db,'support_tickets',req.query,{scope:{userId:req.auth.user._id},fields:['subject']}))))
  if(app==='worker'){
   area.post('/media',express.raw({type:['image/jpeg','image/png','image/webp','application/pdf'],limit:'5mb'}),handler(async(req,res)=>{
    // Worker verification documents are private regardless of caller-supplied headers.
    const wrapped=Object.assign(Object.create(req),{get(name){return name.toLowerCase()==='x-media-visibility'?'private':req.get(name)}})
    reply(req,res,await storage.upload(wrapped),201)
   }))
   area.post('/registration',handler(async(req,res)=>{
    const input=z.object({experienceYears:z.number().min(0).max(80),serviceIds:z.array(idSchema).min(1).max(100),serviceAreaIds:z.array(idSchema).min(1).max(100),
     documents:z.array(z.object({mediaAssetId:idSchema,kind:z.enum(['identity','certificate'])}).strict()).min(1).max(10)}).strict().parse(req.body)
    if(!input.documents.some(d=>d.kind==='identity'))fail(400,'IDENTITY_REQUIRED','Identity proof is mandatory. Certificates are optional.')
    const result=await atomic(db,req,'worker.register','workers',async session=>{
     if(await db.collection('workers').findOne({userId:req.auth.user._id},{session}))fail(409,'ALREADY_REGISTERED','This worker already has a registration.')
     const {validateRelationships}=require('./resources.routes')
     await validateRelationships(db,'workers',input,session,storage)
     for(const doc of input.documents){
      if(!await db.collection('media_assets').findOne({_id:id(doc.mediaAssetId),uploadedBy:req.auth.user._id,visibility:'private',uploadStatus:'ready',isActive:true},{session}))fail(400,'INVALID_DOCUMENT','Select your own persistent private documents.')
     }
     const worker={_id:req.auth.user._id,userId:req.auth.user._id,fullName:req.auth.user.fullName,mobileNumber:req.auth.user.mobileNumber,
      experienceYears:input.experienceYears,serviceIds:input.serviceIds.map(id),serviceAreaIds:input.serviceAreaIds.map(id),status:'pending',isOnline:false,isActive:true,createdAt:new Date(),schemaVersion:1}
     await db.collection('workers').insertOne(worker,{session})
     for(const doc of input.documents)await db.collection('worker_documents').insertOne({_id:new(require('mongoose').Types.ObjectId)(),workerId:worker._id,mediaAssetId:id(doc.mediaAssetId),kind:doc.kind,isActive:true,createdAt:new Date()},{session})
     await notifyAdmins(db,session,'worker.registration',worker._id,'workers.read');return worker
    });reply(req,res,result,201)
   }))
   area.get('/assignments',handler(async(req,res)=>reply(req,res,await list(db,'booking_assignments',req.query,{scope:{workerUserId:req.auth.user._id},fields:['status']}))))
   area.post('/assignments/:id/respond',handler(async(req,res)=>{
    const input=z.object({decision:z.enum(['accept','reject']),reason:reason.optional()}).strict().parse(req.body)
    if(input.decision==='reject'&&!input.reason)fail(400,'REASON_REQUIRED','A rejection reason is required.')
    const result=await atomic(db,req,'assignment.'+input.decision,'booking_assignments',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Only approved workers can respond.')
     const assignment=await requireRecord(db,'booking_assignments',req.params.id,session,{workerUserId:req.auth.user._id,status:'offered'})
     if(assignment.expiresAt<=new Date())fail(409,'OFFER_EXPIRED','Assignment offer has expired.')
     const booking=await requireRecord(db,'bookings',assignment.bookingId,session,{assignmentId:assignment._id,status:'assigned'})
     await compareAndSet(db,'bookings',booking,{assignmentStatus:input.decision==='accept'?'accepted':'rejected',
      ...(input.decision==='reject'?{status:'confirmed',workerId:null,workerUserId:null}: {})},session)
     const updated=await compareAndSet(db,'booking_assignments',assignment,{status:input.decision==='accept'?'accepted':'rejected',reason:input.reason||'',respondedAt:new Date()},session)
     await notifyAdmins(db,session,'assignment.'+input.decision,assignment._id,'bookings.read');return updated
    });reply(req,res,result)
   }))
   area.post('/bookings/:id/progress',handler(async(req,res)=>{
    const input=z.object({action:z.enum(['travel','arrive','start','complete']),otp:z.string().regex(/^\d{6}$/).optional()}).strict().parse(req.body)
    if(input.action==='start'&&!serviceOtp)fail(503,'SERVICE_OTP_NOT_CONFIGURED','Service OTP verification is not configured.')
    const result=await atomic(db,req,'service.'+input.action,'bookings',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
     const booking=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id})
     const status=ensureTransition(booking.status,input.action,'worker',{...booking,actorUserId:worker._id})
     if(input.action==='start'&&!await serviceOtp.verify({bookingId:booking._id,workerUserId:req.auth.user._id,code:input.otp,session}))fail(401,'INVALID_SERVICE_OTP','Arrival OTP is invalid.')
     const updated=await compareAndSet(db,'bookings',booking,{status,...(status==='completed'?{completedAt:new Date()}: {})},session)
     await db.collection('service_events').insertOne({bookingId:booking._id,workerId:worker._id,type:status,createdAt:new Date()},{session})
     await notify(db,session,booking.customerId,'booking.'+status,booking._id,req.id)
     await notifyAdmins(db,session,'booking.'+status,booking._id,'bookings.read');return updated
    });reply(req,res,result)
   }))
   area.post('/bookings/:id/cash-collection',handler(async(req,res)=>{
    const input=z.object({amountPaise:money,reference:reason}).strict().parse(req.body),identity=requestIdentity(req,'cash.report')
    const result=await atomic(db,req,'cash.report','payment_events',async session=>{
     const booking=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id,status:'completed'})
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Active worker approval required.')
     if(Number(booking.totalPaise.toString())!==input.amountPaise)fail(400,'AMOUNT_MISMATCH','Cash must match the booking snapshot.')
     const previous=await db.collection('payment_events').findOne({_id:identity._id},{session});if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key already used.');return previous}
     const record={...identity,bookingId:booking._id,workerId:worker._id,amountPaise:input.amountPaise,reference:input.reference,type:'cash_reported',verification:'pending_reconciliation',createdAt:new Date()}
     await db.collection('payment_events').insertOne(record,{session});await notifyAdmins(db,session,'cash.reported',record._id,'payments.read');return record
    });reply(req,res,result,201)
   }))
   area.get('/settlements',handler(async(req,res)=>reply(req,res,await list(db,'worker_settlements',req.query,{scope:{workerId:req.auth.user._id},fields:['status']}))))
   area.put('/availability',handler(async(req,res)=>{
    if(!scheduling)fail(503,'SCHEDULING_NOT_CONFIGURED','An approved availability strategy is required.')
    const input=z.object({isOnline:z.boolean()}).strict().parse(req.body)
    const result=await atomic(db,req,'worker.availability','workers',async session=>{
     const before=await requireRecord(db,'workers',req.auth.user._id,session,{status:'approved'})
     return compareAndSet(db,'workers',before,input,session)
    });reply(req,res,result)
   }))
   area.post('/leaves',handler(async(req,res)=>{
    const input=z.object({startsAt:z.iso.datetime({offset:true}),endsAt:z.iso.datetime({offset:true}),reason}).strict().refine(v=>v.startsAt<v.endsAt).parse(req.body)
    const identity=requestIdentity(req,'leave')
    const result=await atomic(db,req,'leave.request','worker_leaves',async session=>{
     const worker=await requireRecord(db,'workers',req.auth.user._id,session,{status:'approved'})
     const previous=await db.collection('worker_leaves').findOne({_id:identity._id},{session})
     if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
     const record={...identity,workerId:worker._id,startsAt:new Date(input.startsAt),endsAt:new Date(input.endsAt),reason:input.reason,status:'pending',createdAt:new Date(),isActive:true}
     await db.collection('worker_leaves').insertOne(record,{session});return record
    });reply(req,res,result,201)
   }))
  } else {
   const addressSchema=z.object({label:z.string().min(1).max(50),line1:z.string().min(5).max(300),line2:z.string().max(300).optional(),city:z.literal('Latur'),postalCode:z.string().regex(/^\d{6}$/),serviceAreaId:idSchema}).strict()
   area.get('/addresses',handler(async(req,res)=>reply(req,res,await list(db,'customer_addresses',req.query,{scope:{customerId:req.auth.user._id,isActive:true},fields:['label']}))))
   area.post('/addresses',handler(async(req,res)=>{
    const input=addressSchema.parse(req.body),identity=requestIdentity(req,'address')
    const result=await atomic(db,req,'address.create','customer_addresses',async session=>{
     const previous=await db.collection('customer_addresses').findOne({_id:identity._id},{session})
     if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
     const areaRecord=await requireRecord(db,'service_areas',input.serviceAreaId,session,{isActive:true,isServiceable:true})
     if(!areaRecord.postalCodes.includes(input.postalCode))fail(400,'INVALID_POSTAL_CODE','Postal code is outside the service area.')
     const record={...identity,...input,serviceAreaId:areaRecord._id,customerId:req.auth.user._id,createdAt:new Date(),isActive:true}
     await db.collection('customer_addresses').insertOne(record,{session});return record
    });reply(req,res,result,201)
   }))
   area.patch('/addresses/:id',handler(async(req,res)=>{
    const input=addressSchema.parse(req.body)
    const result=await atomic(db,req,'address.update','customer_addresses',async session=>{
     const before=await requireRecord(db,'customer_addresses',req.params.id,session,{customerId:req.auth.user._id,isActive:true})
     const serviceArea=await requireRecord(db,'service_areas',input.serviceAreaId,session,{isServiceable:true,isActive:true})
     if(!serviceArea.postalCodes.includes(input.postalCode))fail(400,'INVALID_POSTAL_CODE','Address is outside the service area.')
     return compareAndSet(db,'customer_addresses',before,{...input,serviceAreaId:serviceArea._id},session)
    });reply(req,res,result)
   }))
   area.delete('/addresses/:id',handler(async(req,res)=>{
    const result=await atomic(db,req,'address.archive','customer_addresses',async session=>{
     const before=await requireRecord(db,'customer_addresses',req.params.id,session,{customerId:req.auth.user._id})
     return compareAndSet(db,'customer_addresses',before,{isActive:false},session)
    });reply(req,res,result)
   }))
   area.put('/cart',handler(async(req,res)=>{
    const input=cartSchema.parse(req.body)
    const result=await atomic(db,req,'cart.update','carts',async session=>{
     const priced=await quote(db,req.auth.user._id,input,session)
     const record={_id:req.auth.user._id,customerId:req.auth.user._id,input,quote:priced,updatedAt:new Date(),isActive:true}
     await db.collection('carts').replaceOne({_id:record._id},record,{session,upsert:true});return record
    });reply(req,res,result)
   }))
   area.get('/cart',handler(async(req,res)=>{
    const record=await db.collection('carts').findOne({_id:req.auth.user._id})
    if(!record)return reply(req,res,{items:[]})
    reply(req,res,{...record,quote:await quote(db,req.auth.user._id,record.input)})
   }))
   area.post('/quote',handler(async(req,res)=>reply(req,res,await quote(db,req.auth.user._id,cartSchema.parse(req.body)))))
   area.post('/bookings',handler(async(req,res)=>{
    if(!scheduling)fail(503,'SCHEDULING_NOT_CONFIGURED','Approved booking slot rules are required.')
    const input=z.object({cart:cartSchema,addressId:idSchema,startsAt:z.iso.datetime({offset:true}),method:z.enum(['cash','upi'])}).strict().parse(req.body)
    const identity=requestIdentity(req,'booking.create')
    const result=await atomic(db,req,'booking.create','bookings',async session=>{
     const previous=await db.collection('bookings').findOne({_id:identity._id},{session})
     if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
     const address=await requireRecord(db,'customer_addresses',input.addressId,session,{customerId:req.auth.user._id,isActive:true})
     if(String(address.serviceAreaId)!==input.cart.serviceAreaId)fail(400,'INVALID_ADDRESS','Address must match the selected area.')
     const priced=await quote(db,req.auth.user._id,input.cart,session)
     const policy=await db.collection('app_settings').findOne({key:'business',isActive:true},{session})
     if(!policy)fail(503,'POLICY_NOT_CONFIGURED','Approved booking policy is required.')
     const startsAt=new Date(input.startsAt),endsAt=new Date(startsAt.getTime()+priced.durationMinutes*60000)
     if(startsAt.getTime()<Date.now()+policy.bookingLeadMinutes*60000)fail(400,'INVALID_SLOT','Booking lead time is unmet.')
     if(!await scheduling.reserve({bookingId:identity._id,startsAt,endsAt,serviceAreaId:priced.serviceAreaId,session}))fail(409,'SLOT_UNAVAILABLE','Appointment slot is unavailable.')
     const record={...identity,...priced,customerId:req.auth.user._id,addressSnapshot:address,startsAt,endsAt,
      assignmentTimeoutMinutes:policy.assignmentTimeoutMinutes,status:'confirmed',assignmentStatus:'searching',paymentStatus:'pending',paymentMethod:input.method,createdAt:new Date(),isActive:true,schemaVersion:1}
     await reserveCoupon(db,session,priced,req.auth.user._id,record._id)
     await db.collection('bookings').insertOne(record,{session})
     await db.collection('booking_events').insertOne({bookingId:record._id,type:'confirmed',createdAt:new Date(),actorUserId:req.auth.user._id},{session})
     await notifyAdmins(db,session,'booking.created',record._id,'bookings.read');return record
    });reply(req,res,result,201)
   }))
   area.post('/bookings/:id/service-otp',handler(async(req,res)=>{
    if(!serviceOtp?.issue)fail(503,'SERVICE_OTP_NOT_CONFIGURED','Approved service OTP delivery is not configured.')
    const booking=await requireRecord(db,'bookings',req.params.id,undefined,{customerId:req.auth.user._id,status:'arrived'})
    reply(req,res,await serviceOtp.issue({bookingId:booking._id,customerId:req.auth.user._id}))
   }))
   area.get('/payments/:id/receipt',handler(async(req,res)=>{
    const payment=await requireRecord(db,'payments',req.params.id,undefined,{customerId:req.auth.user._id,status:'paid'})
    reply(req,res,{id:payment._id,bookingId:payment.bookingId,amountPaise:payment.amountPaise,method:payment.method,paidAt:payment.paidAt,reference:payment.evidenceReference,verification:payment.verification})
   }))
   area.get('/payments',handler(async(req,res)=>reply(req,res,await list(db,'payments',req.query,{scope:{customerId:req.auth.user._id},fields:['status']}))))
   area.post('/reviews',handler(async(req,res)=>{
    const input=z.object({bookingId:idSchema,rating:z.number().int().min(1).max(5),comment:z.string().trim().max(2000)}).strict().parse(req.body)
    const result=await atomic(db,req,'review.create','reviews',async session=>{
     const booking=await requireRecord(db,'bookings',input.bookingId,session,{customerId:req.auth.user._id,status:'completed'})
     const record={_id:booking._id,bookingId:booking._id,customerId:req.auth.user._id,workerId:booking.workerId,rating:input.rating,comment:input.comment,status:'visible',createdAt:new Date(),isActive:true}
     await db.collection('reviews').insertOne(record,{session});return record
    });reply(req,res,result,201)
   }))
   area.get('/favorites',handler(async(req,res)=>reply(req,res,await list(db,'customer_favorites',req.query,{scope:{customerId:req.auth.user._id,isActive:true},fields:['serviceId']}))))
   area.put('/favorites/:id',handler(async(req,res)=>{
    const result=await atomic(db,req,'favorite.add','customer_favorites',async session=>{
     const service=await requireRecord(db,'services',req.params.id,session,{status:'published',isActive:true})
     const {createHash}=require('node:crypto'),favoriteId=id(createHash('sha256').update(String(req.auth.user._id)+':'+String(service._id)).digest('hex').slice(0,24))
     const record={_id:favoriteId,customerId:req.auth.user._id,serviceId:service._id,isActive:true,createdAt:new Date()}
     await db.collection('customer_favorites').updateOne({_id:favoriteId},{$set:record},{upsert:true,session});return record
    });reply(req,res,result)
   }))
   area.delete('/favorites/:id',handler(async(req,res)=>{
    const result=await atomic(db,req,'favorite.remove','customer_favorites',async session=>{
     const record=await db.collection('customer_favorites').findOneAndUpdate({customerId:req.auth.user._id,serviceId:id(req.params.id)},{$set:{isActive:false}},{session,returnDocument:'after'})
     if(!record)fail(404,'NOT_FOUND','Favorite not found.');return record
    });reply(req,res,result)
   }))
  }
  router.use('/'+app,area)
 }
 return router
}
module.exports={createMobileRouter}
