const express=require('express')
const { z }=require('zod')
const { idSchema,id,money,fail,reply,handler,list,atomic,requestIdentity,compareAndSet,requireRecord }=require('./core')
const {cartSchema,quote,reserveCoupon,notify,notifyAdmins,ensureTransition}=require('./business')
const {mobileAuth}=require('./mobileAuth')
const {offerNextWorker,offerPendingBookings}=require('./dispatch')
const reason=z.string().trim().min(3).max(1000)
function createMobileRouter({db,scheduling,serviceOtp,controlOtp:providedControlOtp,storage,razorpay,legacyWorkerOffersEnabled=false}){
 const router=express.Router(),auth=mobileAuth({db}),controlOtp=providedControlOtp||require('./booking-control-otp').createBookingControlOtp({db})
 router.use(require('./booking-payments').createBookingPaymentsRouter({db,razorpay}))
 for(const app of ['customer','worker']){
  const area=express.Router();area.use(auth.forApp(app))
  require('./push-notifications').installDeviceRoutes(area,{db,app})
  area.get('/notification-preferences',handler(async(req,res)=>{
   const saved=await db.collection('notification_preferences').findOne({_id:req.auth.user._id})
   const profile=await db.collection(app==='customer'?'customers':'workers').findOne({userId:req.auth.user._id})
   res.set('Cache-Control','no-store')
   reply(req,res,{notificationsEnabled:saved?.notificationsEnabled??profile?.notificationsEnabled??true,marketingNotificationsEnabled:saved?.marketingNotificationsEnabled??profile?.marketingNotificationsEnabled??true})
  }))
  area.patch('/notification-preferences',handler(async(req,res)=>{
   const input=z.object({notificationsEnabled:z.boolean(),marketingNotificationsEnabled:z.boolean()}).strict().parse(req.body)
   const collections=await db.listCollections({name:'notification_preferences'}).toArray()
   if(!collections.length)fail(503,'PREFERENCES_NOT_CONFIGURED','Notification preferences require the push schema provisioning step.')
   const result=await atomic(db,req,app+'.notification_preferences','notification_preferences',async session=>{
    await db.collection('notification_preferences').updateOne({_id:req.auth.user._id},{$set:{...input,appType:app,updatedAt:new Date()}},{upsert:true,session})
    return {_id:req.auth.user._id,...input}
   })
   reply(req,res,result)
  }))
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
   await db.collection('push_devices').updateMany({sessionId:req.auth.session._id},{$set:{isActive:false}})
   reply(req,res,{loggedOut:true})
  }))
  area.get('/bookings',handler(async(req,res)=>{
   const result=await list(db,'bookings',req.query,{scope:app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id},fields:['_id']})
   if(app==='worker')for(const booking of result.items){
    const customer=await db.collection('users').findOne({_id:booking.customerId},{projection:{fullName:1,mobileNumber:1}})
    if(customer)booking.customerSnapshot={fullName:customer.fullName,mobileNumber:customer.mobileNumber}
   }
   reply(req,res,result)
  }))
  area.get('/bookings/:id',handler(async(req,res)=>{
   const scope=app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id}
   const booking=await requireRecord(db,'bookings',req.params.id,undefined,scope)
   if(app==='worker'&&booking.customerId){
    const customer=await db.collection('users').findOne({_id:booking.customerId},{projection:{fullName:1,mobileNumber:1}})
    if(customer)booking.customerSnapshot={fullName:customer.fullName,mobileNumber:customer.mobileNumber}
   }
   if(app==='worker'&&booking.paymentMethod==='cash'&&booking.serviceFinishedAt){
    booking.cashCollectionReportedAt=(await db.collection('payment_events').findOne({bookingId:booking._id,workerId:booking.workerId,type:'cash_reported'},{projection:{createdAt:1}}))?.createdAt||null
   }
   const extraServices=await db.collection('booking_extra_services').find({bookingId:booking._id},{projection:{requestHash:0}}).sort({createdAt:1}).toArray()
   const productEvidence=await db.collection('media_assets').find({bookingId:booking._id,usage:'product_evidence',isActive:true,uploadStatus:'ready'},{projection:{storageKey:0,publicUrl:0,contentHash:0}}).sort({createdAt:1}).toArray()
   const result={...booking,extraServices,pendingExtraServices:extraServices.filter(extra=>extra.status==='pending'),productEvidence,durationExtension:booking.durationExtension||null}
   if(app==='customer'&&booking.workerUserId){
    const worker=await db.collection('users').findOne({_id:booking.workerUserId},{projection:{fullName:1}})
    if(worker)result.worker={fullName:worker.fullName}
   }
   if(app==='customer'&&serviceOtp?.availability)result.serviceOtp=await serviceOtp.availability(booking)
   reply(req,res,result)
  }))
  area.get('/bookings/:id/product-evidence/:evidenceId/private-link',handler(async(req,res)=>{
   if(!storage?.productEvidenceLink)fail(503,'STORAGE_NOT_CONFIGURED','Private photo access is not configured.')
   const customer=app==='customer'
   const result=await storage.productEvidenceLink(req,req.params.id,req.params.evidenceId,customer)
   res.set('Cache-Control','no-store');reply(req,res,result)
  }))
  if(app==='customer')area.post('/bookings/:id/duration-extensions/:extensionId/respond',handler(async(req,res)=>{
   const input=z.object({decision:z.enum(['approve','decline'])}).strict().parse(req.body)
   const identity=requestIdentity(req,'customer.duration-extension.respond')
   const result=await atomic(db,req,'duration_extension.decision','booking_events',async session=>{
    const previous=await db.collection('booking_events').findOne({_id:identity._id},{session})
    if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','This key was used with a different response.');return previous.result}
    const booking=await requireRecord(db,'bookings',req.params.id,session,{customerId:req.auth.user._id,status:'in_progress'})
    const current=booking.durationExtension
    if(!current||String(current.id)!==String(id(req.params.extensionId)))fail(404,'NOT_FOUND','Duration extension request was not found.')
    if(current.status!=='pending')fail(409,'EXTENSION_DECISION_CONFLICT','This duration extension already has a decision.')
    const now=new Date()
    const expired=current.expiresAt<=now
    const extension=expired
     ?{...current,status:'expired',decision:'no_response',decidedAt:now}
     :{...current,status:input.decision==='approve'?'approved':'declined',decision:input.decision,decidedAt:now,decidedBy:req.auth.user._id,
       ...(input.decision==='approve'?{extraTimeStartedAt:now,extendedEndsAt:new Date(+now+Number(current.minutes)*60000)}:{})}
    const updated=await compareAndSet(db,'bookings',booking,{durationExtension:extension,...(!expired&&input.decision==='approve'?{serviceEndsAt:extension.extendedEndsAt}: {})},session)
    const record={...identity,bookingId:booking._id,extensionId:extension.id,type:expired?'duration_extension_expired':'duration_extension_'+extension.status,decision:extension.decision||'no_response',actorUserId:req.auth.user._id,createdAt:now,result:{_id:extension.id,bookingId:booking._id,durationExtension:extension,serviceEndsAt:updated.serviceEndsAt}}
    await db.collection('booking_events').insertOne(record,{session})
    const event=expired?'booking.duration_extension_expired':'booking.duration_extension_'+extension.status
    await notify(db,session,booking.customerId,event,booking._id,String(extension.id))
    await notify(db,session,booking.workerUserId,event,booking._id,String(extension.id))
    await notifyAdmins(db,session,event,booking._id,'bookings.read')
    return record.result
   })
   if(result.durationExtension.status==='expired')fail(409,'EXTENSION_EXPIRED','The extension request expired without approval; the worker must finish the service.')
   reply(req,res,result)
  }))
  area.get('/notifications',handler(async(req,res)=>{
   const result=await list(db,'notifications',req.query,{scope:{recipientUserId:req.auth.user._id},fields:['type']})
   result.items=result.items.map(item=>{const copy=require('./push-notifications').notificationCopy(item.type);return {...item,...copy,message:copy.body}})
   reply(req,res,result)
  }))
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
  area.get('/leaves',handler(async(req,res)=>{
   const worker=await db.collection('workers').findOne({userId:req.auth.user._id,isActive:true})
   if(!worker)fail(404,'WORKER_PROFILE_NOT_FOUND','Worker profile was not found for this login.')
   reply(req,res,await list(db,'worker_leaves',req.query,{scope:{workerId:worker._id},fields:['status','reason']}))
  }))
  area.get('/support',handler(async(req,res)=>reply(req,res,await list(db,'support_tickets',req.query,{scope:{userId:req.auth.user._id},fields:['subject']}))))
  if(app==='worker'){
   area.post('/bookings/:id/product-evidence',express.raw({type:['image/jpeg','image/png','image/webp'],limit:'5mb'}),handler(async(req,res)=>{
    if(!storage?.uploadProductEvidence)fail(503,'STORAGE_NOT_CONFIGURED','Persistent private photo storage is not configured.')
    const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true})
    if(!worker)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
    const evidence=await storage.uploadProductEvidence(req,req.params.id,worker)
    res.set('Cache-Control','no-store');reply(req,res,evidence,201)
   }))
  area.get('/offers',handler(async(req,res)=>{
   if(!legacyWorkerOffersEnabled)fail(409,'LEGACY_OFFERS_DISABLED','This backend uses admin-owned worker assignment.')
   const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true})
   if(!worker)fail(403,'WORKER_NOT_APPROVED','Only approved workers can view booking offers.')
   const result=await list(db,'booking_assignments',req.query,{
    scope:{workerUserId:req.auth.user._id,status:'offered',expiresAt:{$gt:new Date()}},
    fields:['status'],
   })
   const offers=await Promise.all(result.items.map(async assignment=>{
    const booking=await db.collection('bookings').findOne({
     _id:assignment.bookingId,
     assignmentId:assignment._id,
     workerUserId:req.auth.user._id,
     status:'assigned',
     assignmentStatus:'offered',
    })
    if(!booking)return null
    const serviceArea=await db.collection('service_areas').findOne({_id:booking.serviceAreaId},{projection:{name:1}})
    return {
     _id:assignment._id,
     bookingId:booking._id,
     status:assignment.status,
     expiresAt:assignment.expiresAt,
     startsAt:booking.startsAt,
     endsAt:booking.endsAt,
     serviceAreaId:booking.serviceAreaId,
     serviceAreaName:serviceArea?.name,
     items:booking.items.map(item=>({
      serviceId:item.serviceId,
      name:item.name,
      durationMinutes:item.durationMinutes,
     })),
     totalPaise:booking.totalPaise,
     customerPayable:Math.round(Number(booking.totalPaise?.toString())/100),
    }
   }))
   reply(req,res,{...result,items:offers.filter(Boolean)})
  }))
  area.post('/bookings/:id/extra-services',handler(async(req,res)=>{
    const input=z.object({name:z.string().trim().min(2).max(120),amountPaise:money.refine(value=>value>0),durationMinutes:z.number().int().min(1).max(600)}).strict().parse(req.body)
    const identity=requestIdentity(req,'worker.extra-service')
    const result=await atomic(db,req,'worker.extra_service.propose','booking_extra_services',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
     const booking=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id,status:'in_progress'})
     if(booking.serviceFinishedAt)fail(409,'BILL_FINALIZED','The final bill is locked for payment.')
     await compareAndSet(db,'bookings',booking,{lastExtraServiceCheckAt:new Date()},session)
     const previous=await db.collection('booking_extra_services').findOne({_id:identity._id},{session})
     if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
     const record={...identity,...input,bookingId:booking._id,customerId:booking.customerId,workerUserId:req.auth.user._id,
      status:'pending',createdAt:new Date(),isActive:true}
     await db.collection('booking_extra_services').insertOne(record,{session})
     await notify(db,session,booking.customerId,'booking.extra_service.requested',record._id,req.id)
     return record
    })
    reply(req,res,result,201)
   }))
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
     if(!legacyWorkerOffersEnabled)fail(409,'LEGACY_OFFERS_DISABLED','This backend uses admin-owned worker assignment.')
    const input=z.object({decision:z.enum(['accept','reject']),reason:reason.optional()}).strict().parse(req.body)
    if(input.decision==='reject'&&!input.reason)fail(400,'REASON_REQUIRED','A rejection reason is required.')
    const result=await atomic(db,req,'assignment.'+input.decision,'booking_assignments',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Only approved workers can respond.')
     const assignment=await requireRecord(db,'booking_assignments',req.params.id,session,{workerUserId:req.auth.user._id,status:'offered'})
     if(assignment.expiresAt<=new Date())fail(409,'OFFER_EXPIRED','Assignment offer has expired.')
     const booking=await requireRecord(db,'bookings',assignment.bookingId,session,{assignmentId:assignment._id,status:'assigned'})
     const updatedBooking=await compareAndSet(db,'bookings',booking,{assignmentStatus:input.decision==='accept'?'accepted':'rejected',
      ...(input.decision==='reject'?{status:'confirmed',workerId:null,workerUserId:null,assignmentId:null}: {})},session)
     const updated=await compareAndSet(db,'booking_assignments',assignment,{status:input.decision==='accept'?'accepted':'rejected',reason:input.reason||'',respondedAt:new Date()},session)
     if(input.decision==='reject'&&legacyWorkerOffersEnabled)await offerNextWorker(db,{booking:updatedBooking,session,scheduling})
     await notifyAdmins(db,session,'assignment.'+input.decision,assignment._id,'bookings.read');return updated
    });reply(req,res,result)
   }))
   area.post('/bookings/:id/progress',handler(async(req,res)=>{
    const input=z.object({action:z.enum(['travel','arrive','start','continue','finish','complete']),otp:z.string().regex(/^\d{6}$/).optional(),evidenceIds:z.array(idSchema).min(1).max(3).optional()}).strict().parse(req.body)
    if(input.action==='start'&&!input.evidenceIds)fail(400,'PRODUCT_EVIDENCE_REQUIRED','Upload at least one product photo before entering the customer OTP.')
    if(input.action==='start'&&(!serviceOtp||serviceOtp.configured===false))fail(503,'SERVICE_OTP_NOT_CONFIGURED','Service OTP verification is not configured.')
    const result=await atomic(db,req,input.action==='start'?'service.start_attempt':'service.'+input.action,'bookings',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
     const booking=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id})
     const status=['continue','finish'].includes(input.action)?booking.status:ensureTransition(booking.status,input.action,'worker',{...booking,actorUserId:worker._id})
     const assignment=await db.collection('booking_assignments').findOne({_id:booking.assignmentId,bookingId:booking._id,workerId:worker._id,workerUserId:req.auth.user._id,status:{$in:['accepted','assigned']}},{session})
     if(!assignment)fail(409,'ASSIGNMENT_UNAVAILABLE','Assigned booking is no longer active.')
     if(['finish','complete'].includes(input.action)&&await db.collection('booking_extra_services').countDocuments({bookingId:booking._id,status:'pending'},{session}))fail(409,'EXTRA_SERVICE_APPROVAL_PENDING','Resolve pending extra services before finishing the service.')
     if(['finish','complete'].includes(input.action)&&booking.durationExtension?.status==='pending')fail(409,'EXTENSION_DECISION_PENDING','Wait for the customer or administrator to decide on the requested time extension.')
     if(['finish','complete'].includes(input.action)&&booking.durationExtension?.status==='approved'&&!booking.durationExtension.adminOtpVerifiedAt)fail(409,'EXTENSION_OTP_REQUIRED','Enter the admin continuation OTP before finishing the extended service.')
     if(input.action==='continue'&&(booking.serviceFinishedAt||!['pending','approved'].includes(booking.durationExtension?.status)||booking.durationExtension.adminOtpVerifiedAt))fail(409,'EXTENSION_NOT_AVAILABLE','There is no duration extension waiting for an admin OTP.')
     if(input.action==='finish'&&(booking.status!=='in_progress'||booking.paymentStatus==='paid'||booking.serviceFinishedAt||booking.paymentQrCodeId||booking.paymentQrRequestId))fail(409,'INVALID_TRANSITION','Only an unpaid, unfinished in-progress booking without a payment QR can be finished for cash reconciliation.')
     if(input.action==='continue'&&booking.status!=='in_progress')fail(409,'INVALID_TRANSITION','Only an in-progress booking can continue.')
     if(input.action==='complete'&&(!booking.serviceFinishedAt||booking.paymentStatus!=='paid'))fail(409,'PAYMENT_PENDING','Verified payment is required before service completion.')
     if((input.action==='continue'||input.action==='complete')&&!controlOtp)fail(503,'CONTROL_OTP_NOT_CONFIGURED','Booking control OTP verification is not configured.')
     let evidence=[]
     const now=new Date()
     if(input.action==='start'){
      const uniqueIds=[...new Set(input.evidenceIds.map(String))]
      evidence=await db.collection('media_assets').find({_id:{$in:uniqueIds.map(id)},bookingId:booking._id,workerId:worker._id,uploadedBy:req.auth.user._id,usage:'product_evidence',visibility:'private',uploadStatus:'ready',isActive:true,retentionExpiresAt:{$gt:now}},{session}).toArray()
      if(evidence.length!==uniqueIds.length)fail(409,'INVALID_PRODUCT_EVIDENCE','Evidence must be uploaded for this booking by the assigned worker.')
     }
     if(input.action==='start'&&!await serviceOtp.verify({booking,workerUserId:req.auth.user._id,code:input.otp,session,req}))return {_id:booking._id,otpFailure:true}
     let controlChallenge
     if(input.action==='continue'){
      if(!input.otp)fail(400,'OTP_REQUIRED','Enter the admin continuation OTP.')
      controlChallenge=await controlOtp.verify({booking,bookingId:booking._id,workerUserId:req.auth.user._id,purpose:'duration_extension',code:input.otp,session})
      if(!controlChallenge)return {_id:booking._id,otpFailure:'duration_extension'}
     }
     if(input.action==='complete'){
      if(!input.otp)fail(400,'OTP_REQUIRED','Enter the admin service-completion OTP.')
      controlChallenge=await controlOtp.verify({booking,bookingId:booking._id,workerUserId:req.auth.user._id,purpose:'service_completion',code:input.otp,session})
      if(!controlChallenge)return {_id:booking._id,otpFailure:'service_completion'}
     }
     const duration=Number(booking.durationMinutes)
     if(input.action==='start'&&(!Number.isInteger(duration)||duration<1||duration>1440))fail(409,'INVALID_BOOKING_DURATION','Booked service duration is invalid.')
     const extension=input.action==='continue'
      ?{...booking.durationExtension,status:'approved',decision:booking.durationExtension.decision||'admin_otp',adminOtpVerifiedAt:now,adminAuthorizedBy:controlChallenge.issuedBy,extraTimeStartedAt:now,extendedEndsAt:new Date(+now+Number(booking.durationExtension.minutes||15)*60000)}
      :undefined
     const changes={status,...(status==='completed'?{completedAt:now}:{}),...(status==='in_progress'&&input.action==='start'?{startedAt:now,serviceStartedAt:now,serviceEndsAt:new Date(+now+duration*60000),serviceEvidenceIds:evidence.map(item=>item._id)}:{}),...(input.action==='finish'?{serviceFinishedAt:now,paymentStatus:'pending',paymentMethod:'cash'}:{}),...(extension?{durationExtension:extension,serviceEndsAt:extension.extendedEndsAt}:{})}
     const updated=await compareAndSet(db,'bookings',booking,changes,session)
     const eventType=extension?'duration_extension_admin_otp_approved':input.action==='finish'?'service_finished_awaiting_cash_reconciliation':status
     await db.collection('service_events').insertOne({bookingId:booking._id,workerId:worker._id,type:eventType,...(input.action==='start'?{serviceStartedAt:now,serviceEndsAt:updated.serviceEndsAt,evidenceIds:updated.serviceEvidenceIds}:{}),...(extension?{extensionId:extension.id,serviceEndsAt:updated.serviceEndsAt}:{}),createdAt:now},{session})
     await db.collection('booking_events').insertOne({bookingId:booking._id,workerId:worker._id,type:eventType,actorUserId:req.auth.user._id,...(input.action==='start'?{serviceStartedAt:now,serviceEndsAt:updated.serviceEndsAt,evidenceIds:updated.serviceEvidenceIds}:{}),...(extension?{extensionId:extension.id,minutes:extension.minutes,serviceEndsAt:updated.serviceEndsAt}:{}),createdAt:now},{session})
     if(input.action==='finish')await notifyAdmins(db,session,'booking.cash_reconciliation_requested',booking._id,'payments.reconcile')
     else if(extension)await notify(db,session,booking.customerId,'booking.duration_extension_approved',booking._id,String(extension.id))
     else await notify(db,session,booking.customerId,'booking.'+status,booking._id,req.id)
     if(input.action!=='finish')await notifyAdmins(db,session,extension?'booking.duration_extension_approved':'booking.'+status,booking._id,'bookings.read');return updated
    });if(result.otpFailure==='duration_extension')fail(401,'INVALID_EXTENSION_OTP','Admin continuation OTP is invalid, expired, consumed or locked.');if(result.otpFailure==='service_completion')fail(401,'INVALID_COMPLETION_OTP','Admin service-completion OTP is invalid, expired, consumed or locked.');if(result.otpFailure)fail(401,'INVALID_SERVICE_OTP','Service OTP is invalid, expired, consumed or locked.');reply(req,res,result)
   }))
   area.post('/bookings/:id/cash-collection',handler(async(req,res)=>{
    const input=z.object({amountPaise:money,reference:reason}).strict().parse(req.body),identity=requestIdentity(req,'cash.report')
    const result=await atomic(db,req,'cash.report','payment_events',async session=>{
     const booking=await requireRecord(db,'bookings',req.params.id,session,{workerUserId:req.auth.user._id,status:'in_progress',serviceFinishedAt:{$exists:true},paymentMethod:'cash',paymentStatus:{$ne:'paid'}})
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Active worker approval required.')
     if(Number(booking.totalPaise.toString())!==input.amountPaise)fail(400,'AMOUNT_MISMATCH','Cash must match the booking snapshot.')
     const previous=await db.collection('payment_events').findOne({_id:identity._id},{session});if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key already used.');return previous}
     if(await db.collection('payment_events').findOne({bookingId:booking._id,workerId:worker._id,type:'cash_reported'},{session}))fail(409,'CASH_ALREADY_REPORTED','Cash collection has already been reported for this booking.')
     const record={...identity,bookingId:booking._id,workerId:worker._id,amountPaise:input.amountPaise,reference:input.reference,type:'cash_reported',verification:'pending_reconciliation',createdAt:new Date()}
     await db.collection('payment_events').insertOne(record,{session});await notifyAdmins(db,session,'cash.reported',record._id,'payments.read');return record
    });reply(req,res,result,201)
   }))
   area.get('/settlements',handler(async(req,res)=>{
    const worker=await db.collection('workers').findOne({userId:req.auth.user._id,isActive:true})
    if(!worker)fail(404,'WORKER_PROFILE_NOT_FOUND','Worker profile was not found for this login.')
    reply(req,res,await list(db,'worker_settlements',req.query,{scope:{workerId:worker._id},fields:['status']}))
   }))
   area.put('/availability',handler(async(req,res)=>{
    if(!scheduling)fail(503,'SCHEDULING_NOT_CONFIGURED','An approved availability strategy is required.')
    const input=z.object({isOnline:z.boolean()}).strict().parse(req.body)
    const result=await atomic(db,req,'worker.availability','workers',async session=>{
      const before=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
      if(!before)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
      const updated=await compareAndSet(db,'workers',before,input,session)
      if(input.isOnline&&legacyWorkerOffersEnabled)await offerPendingBookings(db,{worker:updated,session,scheduling})
      return updated
    });reply(req,res,result)
    }))
   area.post('/leaves',handler(async(req,res)=>{
    const input=z.object({startsAt:z.iso.datetime({offset:true}),endsAt:z.iso.datetime({offset:true}),reason}).strict().refine(v=>v.startsAt<v.endsAt).parse(req.body)
    const identity=requestIdentity(req,'leave')
    const result=await atomic(db,req,'leave.request','worker_leaves',async session=>{
     const worker=await db.collection('workers').findOne({userId:req.auth.user._id,status:'approved',isActive:true},{session})
     if(!worker)fail(403,'WORKER_NOT_APPROVED','Worker approval is required.')
     const previous=await db.collection('worker_leaves').findOne({_id:identity._id},{session})
     if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
     const record={...identity,workerId:worker._id,startsAt:new Date(input.startsAt),endsAt:new Date(input.endsAt),reason:input.reason,status:'pending',createdAt:new Date(),isActive:true}
     await db.collection('worker_leaves').insertOne(record,{session});return record
    });reply(req,res,result,201)
   }))
  } else {
   area.post('/bookings/:id/extra-services/:extraId/respond',handler(async(req,res)=>{
    const input=z.object({decision:z.enum(['approve','reject'])}).strict().parse(req.body)
    const result=await atomic(db,req,'customer.extra_service.respond','booking_extra_services',async session=>{
     const booking=await requireRecord(db,'bookings',req.params.id,session,{customerId:req.auth.user._id,status:'in_progress'})
     if(booking.serviceFinishedAt)fail(409,'BILL_FINALIZED','The final bill is locked for payment.')
     const extra=await requireRecord(db,'booking_extra_services',req.params.extraId,session,{bookingId:booking._id,customerId:req.auth.user._id})
     if(extra.status!=='pending'){
      if(extra.status===(input.decision==='approve'?'approved':'rejected'))return extra
      fail(409,'EXTRA_SERVICE_ALREADY_DECIDED','This extra service has already been decided.')
     }
     if(input.decision==='approve'){
      const currentTotal=Number(booking.totalPaise?.toString())
      const totalPaise=currentTotal+Number(extra.amountPaise?.toString())
      if(!Number.isSafeInteger(totalPaise))fail(400,'INVALID_BOOKING_AMOUNT','Updated booking total is invalid.')
      await compareAndSet(db,'bookings',booking,{totalPaise},session)
     }
     const updated=await compareAndSet(db,'booking_extra_services',extra,{status:input.decision==='approve'?'approved':'rejected',decidedAt:new Date()},session)
     await notify(db,session,extra.workerUserId,'booking.extra_service.'+updated.status,updated._id,req.id)
     return updated
    })
    reply(req,res,result)
   }))
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
    if(!serviceOtp?.createForBooking)fail(503,'SERVICE_OTP_NOT_CONFIGURED','Booking service OTP is not configured.')
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
     if(!await scheduling.reserve({bookingId:identity._id,startsAt,endsAt,serviceAreaId:priced.serviceAreaId,items:priced.items,session}))fail(409,'SLOT_UNAVAILABLE','Appointment slot is unavailable.')
     const record={...identity,...priced,customerId:req.auth.user._id,addressSnapshot:address,startsAt,endsAt,
      assignmentTimeoutMinutes:policy.assignmentTimeoutMinutes,status:'confirmed',assignmentStatus:'searching',paymentStatus:'pending',paymentMethod:input.method,createdAt:new Date(),isActive:true,schemaVersion:1}
     await reserveCoupon(db,session,priced,req.auth.user._id,record._id)
     await serviceOtp.createForBooking({booking:record,session})
     await db.collection('bookings').insertOne(record,{session})
     await db.collection('booking_events').insertOne({bookingId:record._id,type:'confirmed',createdAt:new Date(),actorUserId:req.auth.user._id},{session})
     await notifyAdmins(db,session,'booking.created',record._id,'bookings.read')
     return legacyWorkerOffersEnabled
      ?await offerNextWorker(db,{booking:record,session,scheduling})||record
      :record
    });reply(req,res,{...result,serviceOtp:await serviceOtp.availability(result)},201)
   }))
   const revealServiceOtp=handler(async(req,res)=>{
    if(!serviceOtp?.reveal)fail(503,'SERVICE_OTP_NOT_CONFIGURED','Service OTP reveal is not configured.')
    res.set('Cache-Control','private, no-store')
    res.set('Pragma','no-cache')
    reply(req,res,await serviceOtp.reveal({
     bookingId:req.params.id,
     customerId:req.auth.user._id,
     req,
    }))
   })
   area.post('/bookings/:id/service-otp/reveal',revealServiceOtp)
   area.post('/bookings/:id/service-otp',revealServiceOtp)
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
