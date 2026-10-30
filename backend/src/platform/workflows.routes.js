const {z}=require('zod')
const {idSchema,id,money,fail,reply,handler,protectedRouter,list,atomic,requestIdentity,compareAndSet,requireRecord}=require('./core')
const {notify,notifyAdmins,ensureTransition,collectionEvidence,paise}=require('./business')
const reason=z.string().trim().min(3).max(1000)
function createWorkflowsRouter({db,auth,scheduling,compensation}){
 const router=protectedRouter(auth)
 router.get('/pending-payments',auth.requirePermission('payments.read'),handler(async(req,res)=>{
  const result=await list(db,'bookings',req.query,{scope:{paymentStatus:'pending',status:{$ne:'cancelled'}},fields:[],projection:{_id:1,customerId:1,workerId:1,totalPaise:1,paymentMethod:1,createdAt:1,status:1,serviceFinishedAt:1}})
  for(const booking of result.items){
   if(booking.paymentMethod==='cash'&&booking.serviceFinishedAt){
    const report=await db.collection('payment_events').findOne({bookingId:booking._id,workerId:booking.workerId,type:'cash_reported',verification:'pending_reconciliation'},{projection:{reference:1,createdAt:1}})
    booking.cashReportReference=report?.reference||''
    booking.cashReportedAt=report?.createdAt||null
   }
  }
  reply(req,res,result)
 }))
 router.patch('/admins/:id/status',auth.requirePermission('admins.update'),handler(async(req,res)=>{
  const input=z.object({status:z.enum(['active','suspended'])}).strict().parse(req.body)
  if(!['SUPER_ADMIN','HII_BEAUTY_SUPER_ADMIN'].includes(req.auth.role.roleCode)||req.params.id===String(req.auth.user._id))fail(403,'FORBIDDEN','Only a Super Admin may change another administrator account.')
  const result=await atomic(db,req,'admin.status','users',async session=>{
   const before=await requireRecord(db,'users',req.params.id,session,{userType:/^admin$/i})
   const updated=await compareAndSet(db,'users',before,{status:input.status,isActive:input.status==='active'},session)
   if(input.status!=='active')await db.collection('auth_sessions').updateMany({userId:before._id},{$set:{isActive:false,revokedAt:new Date()}},{session})
   return {_id:updated._id,status:updated.status,isActive:updated.isActive}
  });reply(req,res,result)
 }))
 router.post('/support/:id/replies',auth.requirePermission('support.update'),handler(async(req,res)=>{
  const input=z.object({text:z.string().trim().min(1).max(1000)}).strict().parse(req.body)
  const result=await atomic(db,req,'support.reply','support_tickets',async session=>{
   const before=await requireRecord(db,'support_tickets',req.params.id,session)
   if((before.messages||[]).length>=500)fail(409,'HISTORY_LIMIT','Ticket history limit reached.')
   return compareAndSet(db,'support_tickets',before,{messages:[...(before.messages||[]),{text:input.text,at:new Date(),actorUserId:req.auth.user._id,visibility:'internal'}]},session)
  });reply(req,res,result)
 }))
 router.patch('/notifications/:id/read',auth.requirePermission('notifications.read'),handler(async(req,res)=>{
  const record=await db.collection('notifications').findOneAndUpdate({_id:id(req.params.id),recipientUserId:req.auth.user._id},{$set:{isRead:true}},{returnDocument:'after'})
  if(!record)fail(404,'NOT_FOUND','Notification not found.');reply(req,res,record)
 }))
 router.get('/workers/:id/documents',auth.requirePermission('workers.documents.read'),handler(async(req,res)=>{
   await requireRecord(db,'workers',req.params.id)
   reply(req,res,{items:await db.collection('worker_documents').find({workerId:id(req.params.id),isActive:true},{projection:{kind:1,mediaAssetId:1}}).toArray()})
 }))
 router.post('/leaves/:id/decision',auth.requirePermission('workers.leaves.update'),handler(async(req,res)=>{
  const input=z.object({decision:z.enum(['approved','rejected']),reason}).strict().parse(req.body)
  const result=await atomic(db,req,'leave.decision','worker_leaves',async session=>{
   const before=await requireRecord(db,'worker_leaves',req.params.id,session,{status:'pending'})
   return compareAndSet(db,'worker_leaves',before,{status:input.decision,reviewReason:input.reason,reviewedBy:req.auth.user._id},session)
  });reply(req,res,result)
 }))
 router.post('/workers/:id/decision',auth.requirePermission('workers.approve'),handler(async(req,res)=>{
  const input=z.object({decision:z.enum(['approve','reject','suspend','reactivate']),reason:reason.optional(),identityReviewed:z.boolean().optional()}).strict().parse(req.body)
  if(['reject','suspend'].includes(input.decision)&&!input.reason)fail(400,'REASON_REQUIRED','A reason is required.')
  const permission={approve:'workers.approve',reject:'workers.reject',suspend:'workers.suspend',reactivate:'workers.approve'}[input.decision]
  if(!req.auth.role.permissions.includes(permission))fail(403,'FORBIDDEN','This decision requires additional permission.')
  const worker=await atomic(db,req,'worker.'+input.decision,'workers',async session=>{
   const before=await requireRecord(db,'workers',req.params.id,session)
   if(input.decision==='approve'){
    if(before.status!=='pending'||input.identityReviewed!==true)fail(409,'INVALID_TRANSITION','Only reviewed pending workers may be approved.')
    const documents=await db.collection('worker_documents').find({workerId:before._id,kind:'identity',isActive:true},{session}).toArray()
    if(!documents.length)fail(400,'IDENTITY_REQUIRED','Identity proof is mandatory; certificates are optional.')
    for(const document of documents){
     const media=await db.collection('media_assets').findOne({_id:document.mediaAssetId,visibility:'private',uploadStatus:'ready',isActive:true},{session})
     if(!media)fail(400,'IDENTITY_REQUIRED','Identity proof must be stored privately.')
    }
   }else if(input.decision==='reject'&&before.status!=='pending'||input.decision==='suspend'&&before.status!=='approved'||input.decision==='reactivate'&&before.status!=='suspended')fail(409,'INVALID_TRANSITION','Worker state does not permit this decision.')
   const status={approve:'approved',reject:'rejected',suspend:'suspended',reactivate:'approved'}[input.decision]
   const result=await compareAndSet(db,'workers',before,{status,reviewReason:input.reason||'',reviewedAt:new Date(),reviewedBy:req.auth.user._id},session)
   await notify(db,session,before.userId,'worker.'+status,before._id,req.id);return result
  });reply(req,res,worker)
 }))
 router.post('/bookings/:id/assign',auth.requirePermission('bookings.assign'),handler(async(req,res)=>{
  if(!scheduling)fail(503,'SCHEDULING_NOT_CONFIGURED','Approved scheduling/availability strategy is required.')
  const input=z.object({workerId:idSchema,reason:reason}).strict().parse(req.body)
  const identity=requestIdentity(req,'admin.assignment.'+req.params.id)
  const result=await atomic(db,req,'booking.assign','bookings',async session=>{
   const previous=await db.collection('booking_events').findOne({_id:identity._id},{session})
   if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','This key was used with a different allocation.');return previous.result}
   const booking=await requireRecord(db,'bookings',req.params.id,session)
   if(!['confirmed','assigned'].includes(booking.status))fail(409,'INVALID_TRANSITION','This booking cannot be assigned.')
   const worker=await requireRecord(db,'workers',input.workerId,session,{status:'approved',isOnline:true,isActive:true})
   if(!booking.items.every(item=>worker.serviceIds?.some(s=>String(s)===String(item.serviceId)))||!worker.serviceAreaIds?.some(a=>String(a)===String(booking.serviceAreaId)))fail(400,'WORKER_INELIGIBLE','Worker skills or service area do not match.')
   await requireRecord(db,'service_areas',booking.serviceAreaId,session,{isActive:true,isServiceable:true})
   if(await db.collection('worker_leaves').findOne({workerId:worker._id,status:'approved',startsAt:{$lt:booking.endsAt},endsAt:{$gt:booking.startsAt}},{session}))fail(409,'WORKER_ON_LEAVE','Worker has approved leave during this booking.')
   // Serialize all assignments for this worker, including assignments to different bookings.
   await compareAndSet(db,'workers',worker,{lastAssignmentCheckAt:new Date()},session)
   const overlap=await db.collection('bookings').findOne({_id:{$ne:booking._id},workerId:worker._id,status:{$nin:['completed','cancelled']},
     startsAt:{$lt:booking.endsAt},endsAt:{$gt:booking.startsAt}},{session})
   if(overlap||!await scheduling.canAssign({worker,booking,session}))fail(409,'WORKER_UNAVAILABLE','Worker has a conflicting booking or unavailable schedule.')
   const assignedAt=new Date()
   const previousAssignments=await db.collection('booking_assignments').find({bookingId:booking._id,status:{$in:['offered','accepted','assigned']}},{session}).toArray()
   for(const previous of previousAssignments){
     await compareAndSet(db,'booking_assignments',previous,{status:'superseded',reason:input.reason,changedAt:assignedAt,changedBy:req.auth.user._id},session)
     if(String(previous.workerUserId)!==String(worker.userId))await notify(db,session,previous.workerUserId,'assignment.revoked',previous._id)
   }
   const assignment={_id:new(require('mongoose').Types.ObjectId)(),bookingId:booking._id,workerId:worker._id,workerUserId:worker.userId,status:'assigned',
     reason:input.reason,assignedAt,assignedBy:req.auth.user._id,createdAt:assignedAt,isActive:true}
   await db.collection('booking_assignments').insertOne(assignment,{session})
   if(!worker.compensationRule || new Date(worker.compensationRule.effectiveFrom)>booking.startsAt)fail(409,'COMPENSATION_NOT_CONFIGURED','Configure an effective compensation rule before assigning this worker.')
   const compensationPaise=paise(worker.compensationRule.amountPaise)
   const updated=await compareAndSet(db,'bookings',booking,{compensationPaise,workerId:worker._id,workerUserId:worker.userId,assignmentId:assignment._id,assignmentStatus:'assigned',assigningAdminUserId:req.auth.user._id,assignedAt,assignmentReason:input.reason,status:'assigned'},session)
   await db.collection('booking_events').insertOne({...identity,result:updated,bookingId:booking._id,type:'assignment_assigned',workerId:worker._id,actorUserId:req.auth.user._id,reason:input.reason,createdAt:assignedAt},{session})
   await notify(db,session,worker.userId,'assignment.assigned',assignment._id)
   await notify(db,session,booking.customerId,'booking.assigned',booking._id)
   return updated
  });reply(req,res,result)
 }))
 router.post('/bookings/:id/cancel',auth.requirePermission('bookings.cancel'),handler(async(req,res)=>{
  const input=z.object({reason}).strict().parse(req.body)
  const result=await atomic(db,req,'booking.cancel','bookings',async session=>{
   const booking=await requireRecord(db,'bookings',req.params.id,session)
   ensureTransition(booking.status,'cancel','admin',booking)
   await db.collection('booking_assignments').updateMany({bookingId:booking._id,status:{$in:['offered','accepted','assigned']}},{$set:{status:'cancelled',updatedAt:new Date()}},{session})
   const updated=await compareAndSet(db,'bookings',booking,{status:'cancelled',assignmentStatus:'cancelled',cancellationReason:input.reason},session)
   await db.collection('booking_events').insertOne({bookingId:booking._id,type:'cancelled',actorUserId:req.auth.user._id,reason:input.reason,createdAt:new Date()},{session})
   await notify(db,session,booking.customerId,'booking.cancelled',booking._id,req.id)
   if(booking.workerUserId)await notify(db,session,booking.workerUserId,'booking.cancelled',booking._id,req.id)
   return updated
  });reply(req,res,result)
 }))
 router.post('/payments/reconcile',auth.requirePermission('payments.reconcile'),handler(async(req,res)=>{
  const input=z.object({bookingId:idSchema,amountPaise:money,method:z.enum(['cash','upi']),evidenceReference:reason}).strict().parse(req.body)
  const identity=requestIdentity(req,'payments.reconcile')
  const result=await atomic(db,req,'payment.reconcile','payments',async session=>{
   const previous=await db.collection('payments').findOne({_id:identity._id},{session})
   if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used.');return previous}
   const booking=await requireRecord(db,'bookings',input.bookingId,session)
   collectionEvidence(booking,input,'admin')
   if(booking.paymentStatus==='paid')fail(409,'ALREADY_PAID','Payment is already recorded.')
   if(booking.status==='in_progress'&&input.method==='cash'){
    const report=await db.collection('payment_events').findOne({bookingId:booking._id,workerId:booking.workerId,type:'cash_reported',verification:'pending_reconciliation',amountPaise:input.amountPaise,reference:input.evidenceReference},{session})
    if(!report)fail(409,'CASH_REPORT_REQUIRED','Verify the worker cash report before reconciling payment.')
   }
   await compareAndSet(db,'bookings',booking,{paymentStatus:'paid'},session)
   // A deterministic reference guard prevents reuse across different bookings/keys.
   const {createHash}=require('node:crypto')
   const referenceId=id(createHash('sha256').update(input.method+':'+input.evidenceReference).digest('hex').slice(0,24))
   await db.collection('payment_events').insertOne({_id:referenceId,bookingId:booking._id,paymentId:identity._id,type:'reconciled',reference:input.evidenceReference,actorUserId:req.auth.user._id,createdAt:new Date()},{session})
   const payment={...identity,bookingId:booking._id,customerId:booking.customerId,workerId:booking.workerId,amountPaise:input.amountPaise,method:input.method,
    status:'paid',verification:'authorized_reconciliation',evidenceReference:input.evidenceReference,verifiedBy:req.auth.user._id,paidAt:new Date(),createdAt:new Date(),isActive:true}
   await db.collection('payments').insertOne(payment,{session})
   await notify(db,session,booking.customerId,'payment.recorded',payment._id)
   if(booking.workerUserId)await notify(db,session,booking.workerUserId,'booking.payment_received',booking._id,String(payment._id))
   return payment
  });reply(req,res,result,201)
 }))
 router.post('/settlements/generate',auth.requirePermission('settlements.approve'),handler(async(req,res)=>{
  if(!compensation)fail(503,'COMPENSATION_NOT_CONFIGURED','An approved worker compensation strategy is required.')
  const input=z.object({workerId:idSchema,date:z.iso.date()}).strict().parse(req.body)
  const result=await atomic(db,req,'settlement.generate','worker_settlements',async session=>{
   const {createHash}=require('node:crypto'),settlementId=id(createHash('sha256').update(input.workerId+':'+input.date).digest('hex').slice(0,24))
   const previous=await db.collection('worker_settlements').findOne({_id:settlementId},{session});if(previous)return previous
   const start=new Date(input.date+'T00:00:00+05:30'),end=new Date(start.getTime()+86400000)
   const jobs=await db.collection('bookings').find({workerId:id(input.workerId),status:'completed',completedAt:{$gte:start,$lt:end}},{session}).toArray()
   const amounts=await compensation.calculate({jobs,workerId:input.workerId,date:input.date,session})
   const earnings=paise(amounts.earningsPaise),cashRemitted=paise(amounts.cashRemittedPaise)
   const cash=await db.collection('payments').aggregate([{$match:{workerId:id(input.workerId),method:'cash',status:'paid',bookingId:{$in:jobs.map(j=>j._id)}}},{$group:{_id:null,total:{$sum:'$amountPaise'}}}],{session}).toArray()
   const record={_id:settlementId,workerId:id(input.workerId),date:input.date,earningsPaise:earnings,cashCollectedPaise:paise(cash[0]?.total||0),cashRemittedPaise:cashRemitted,status:'pending',createdAt:new Date(),isActive:true}
   await db.collection('worker_settlements').insertOne(record,{session})
   for(const job of jobs)await db.collection('worker_settlement_items').insertOne({_id:job._id,settlementId,bookingId:job._id,workerId:job.workerId,createdAt:new Date()},{session})
   return record
  });reply(req,res,result,201)
 }))
 router.post('/settlements/:id/approve',auth.requirePermission('settlements.approve'),handler(async(req,res)=>{
  const input=z.object({reference:reason}).strict().parse(req.body)
  const result=await atomic(db,req,'settlement.approve','worker_settlements',async session=>{
   const before=await requireRecord(db,'worker_settlements',req.params.id,session)
   if(before.status!=='pending')fail(409,'INVALID_TRANSITION','Only a pending settlement can be approved.')
   return compareAndSet(db,'worker_settlements',before,{status:'approved',approvedBy:req.auth.user._id,approvedAt:new Date(),reference:input.reference},session)
  });reply(req,res,result)
 }))
 return router
}
module.exports={createWorkflowsRouter}
