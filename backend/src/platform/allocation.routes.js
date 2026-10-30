const {protectedRouter,handler,reply,list,requireRecord,fail,id}=require('./core')

function createAllocationRouter({db,auth,scheduling,allocationEligibility}) {
 const router=protectedRouter(auth)
 router.get('/allocations',auth.requirePermission('bookings.read'),handler(async(req,res)=>{
  const result=await list(db,'bookings',req.query,{
   scope:{status:'confirmed',workerId:null},fields:['bookingNumber','customerSnapshot.fullName','addressSnapshot.city'],
   projection:{_id:1,bookingNumber:1,customerId:1,customerSnapshot:1,items:1,addressSnapshot:1,startsAt:1,endsAt:1,totalPaise:1,assignmentStatus:1,createdAt:1},
  })
  const customerIds=[...new Set(result.items.map(booking=>booking.customerId).filter(Boolean).map(String))]
  if(customerIds.length){
   const customers=await db.collection('users').find({_id:{$in:customerIds.map(id)}},{projection:{_id:1,fullName:1}}).toArray()
   const customerNames=new Map(customers.map(customer=>[String(customer._id),customer.fullName]))
   for(const booking of result.items)if(!booking.customerSnapshot&&booking.customerId)booking.customerSnapshot={fullName:customerNames.get(String(booking.customerId))||'Customer'}
  }
  const now=new Date()
  const localDate=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(now)
  const dayStart=new Date(localDate+'T00:00:00+05:30')
  const dayEnd=new Date(+dayStart+24*60*60*1000)
  const [assignedToday,awaitingApproval,availableExperts]=await Promise.all([
   db.collection('bookings').countDocuments({status:{$in:['assigned','travelling','arrived','in_progress','completed']},assignedAt:{$gte:dayStart,$lt:dayEnd},isDeleted:{$ne:true}}),
   db.collection('booking_assignments').countDocuments({status:'offered',isDeleted:{$ne:true}}),
   db.collection('workers').countDocuments({status:'approved',isActive:true,isOnline:true,isDeleted:{$ne:true}}),
  ])
  reply(req,res,{...result,stats:{pendingRequests:result.pagination.total,assignedToday,awaitingApproval,availableExperts}})
 }))
 router.get('/allocations/:id/eligible-workers',auth.requirePermission('bookings.assign'),handler(async(req,res)=>{
  if(!scheduling)fail(503,'SCHEDULING_NOT_CONFIGURED','Scheduling is required to allocate a worker.')
  const booking=await requireRecord(db,'bookings',req.params.id)
  if(!['confirmed','assigned'].includes(booking.status))fail(409,'INVALID_TRANSITION','This booking cannot be allocated.')
  const area=await db.collection('service_areas').findOne({_id:booking.serviceAreaId,isActive:true,isServiceable:true})
  if(!area)fail(409,'AREA_UNAVAILABLE','The booking service area is unavailable.')
  const workers=await db.collection('workers').find({status:'approved',isActive:true,serviceAreaIds:booking.serviceAreaId}).sort({_id:1}).limit(1000).toArray()
  const items=[]
  for(const worker of workers){
   let reason=''
   if(!(booking.items||[]).every(item=>worker.serviceIds?.some(service=>String(service)===String(item.serviceId))))reason='Service skills do not match'
   else if(!worker.compensationRule||new Date(worker.compensationRule.effectiveFrom)>booking.startsAt)reason='Compensation is not configured for this date'
   else if(await db.collection('worker_leaves').findOne({workerId:worker._id,status:'approved',startsAt:{$lt:booking.endsAt},endsAt:{$gt:booking.startsAt}}))reason='Approved leave overlaps this booking'
   else if(await db.collection('bookings').findOne({_id:{$ne:booking._id},workerId:worker._id,status:{$nin:['completed','cancelled']},startsAt:{$lt:booking.endsAt},endsAt:{$gt:booking.startsAt}}))reason='Another booking overlaps this time'
   else if(!await scheduling.canAssign({worker,booking}))reason='Unavailable in the work schedule'
   else if(allocationEligibility?!await allocationEligibility(worker,booking):worker.isOnline!==true)reason='Unavailable under the assignment policy'
   items.push({_id:worker._id,fullName:worker.fullName,eligible:!reason,reason})
  }
  reply(req,res,{items})
 }))
 return router
}
module.exports={createAllocationRouter}
