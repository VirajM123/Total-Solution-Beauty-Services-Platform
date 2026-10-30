const mongoose=require('mongoose')
const {compareAndSet}=require('../platform/core')
const {notify,notifyAdmins}=require('../platform/business')

const extensionMinutes=15
const approvalSeconds=300

async function requestDueExtensions({db,now=new Date(),limit=100}){
 const bookings=await db.collection('bookings').find({status:'in_progress',serviceFinishedAt:{$exists:false},serviceEndsAt:{$lte:now},durationExtension:{$exists:false}}).sort({serviceEndsAt:1}).limit(limit).toArray()
 let count=0
 for(const candidate of bookings){
  const session=(db.transactionClient||mongoose.connection.getClient()).startSession()
  try{
   await session.withTransaction(async()=>{
    const booking=await db.collection('bookings').findOne({_id:candidate._id,status:'in_progress',serviceFinishedAt:{$exists:false},serviceEndsAt:{$lte:now},durationExtension:{$exists:false}},{session})
    if(!booking)return
    const extension={id:new mongoose.Types.ObjectId(),status:'pending',minutes:extensionMinutes,pricePaise:0,requestedAt:now,expiresAt:new Date(+now+approvalSeconds*1000)}
    await compareAndSet(db,'bookings',booking,{durationExtension:extension},session)
    await db.collection('booking_events').insertOne({bookingId:booking._id,type:'duration_extension_requested',extensionId:extension.id,minutes:extension.minutes,pricePaise:0,actorType:'system',createdAt:now},{session})
    await notify(db,session,booking.customerId,'booking.duration_extension_requested',booking._id,String(extension.id))
    await notify(db,session,booking.workerUserId,'booking.duration_extension_requested',booking._id,String(extension.id))
    await notifyAdmins(db,session,'booking.duration_extension_requested',booking._id,'bookings.read')
    count++
   })
  }finally{await session.endSession()}
 }
 return count
}

async function expireExtensionDecisions({db,now=new Date(),limit=100}){
 const bookings=await db.collection('bookings').find({'durationExtension.status':'pending','durationExtension.expiresAt':{$lte:now}}).sort({'durationExtension.expiresAt':1}).limit(limit).toArray()
 let count=0
 for(const candidate of bookings){
  const session=(db.transactionClient||mongoose.connection.getClient()).startSession()
  try{
   await session.withTransaction(async()=>{
    const booking=await db.collection('bookings').findOne({_id:candidate._id,'durationExtension.status':'pending','durationExtension.expiresAt':{$lte:now}},{session})
    if(!booking)return
    const extension={...booking.durationExtension,status:'expired',decision:'no_response',decidedAt:now}
    await compareAndSet(db,'bookings',booking,{durationExtension:extension},session)
    await db.collection('booking_events').insertOne({bookingId:booking._id,type:'duration_extension_expired',extensionId:extension.id,decision:'no_response',actorType:'system',createdAt:now},{session})
    await notify(db,session,booking.customerId,'booking.duration_extension_expired',booking._id,String(extension.id))
    await notify(db,session,booking.workerUserId,'booking.duration_extension_expired',booking._id,String(extension.id))
    await notifyAdmins(db,session,'booking.duration_extension_expired',booking._id,'bookings.read')
    count++
   })
  }finally{await session.endSession()}
 }
 return count
}

async function expireProductEvidence({db,storageAdapter,now=new Date(),limit=100}){
 if(!storageAdapter?.remove)return 0
 const evidence=await db.collection('media_assets').find({usage:'product_evidence',isActive:true,retentionExpiresAt:{$lte:now}}).sort({retentionExpiresAt:1}).limit(limit).toArray()
 let count=0
 for(const item of evidence){
  await storageAdapter.remove({storageKey:item.storageKey})
  const result=await db.collection('media_assets').updateOne({_id:item._id,usage:'product_evidence',isActive:true,retentionExpiresAt:{$lte:now}},{$set:{isActive:false,uploadStatus:'expired',expiredAt:now,updatedAt:now}})
  if(result.modifiedCount)count++
 }
 return count
}

function startDurationExtensionJob({db,logger,storageAdapter,intervalMs=15000}){
 let busy=false
 const timer=setInterval(async()=>{
  if(busy)return
  busy=true
  try{
   await requestDueExtensions({db})
   await expireExtensionDecisions({db})
   await expireProductEvidence({db,storageAdapter})
  }catch(error){logger.error({errorName:error.name},'Duration extension sweep failed')}
  finally{busy=false}
 },intervalMs)
 timer.unref()
 return()=>clearInterval(timer)
}

module.exports={extensionMinutes,approvalSeconds,requestDueExtensions,expireExtensionDecisions,expireProductEvidence,startDurationExtensionJob}
