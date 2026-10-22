const { z }=require('zod')
const { id,fail,requireRecord,compareAndSet }=require('./core')
function paise(value){
 const n=Number(value?.toString())
 if(!Number.isSafeInteger(n)||n<0)fail(400,'INVALID_MONEY','Amount must be nonnegative integer paise.')
 return n
}
function discountFor(offer,subtotal){
 const amount=offer.discountType==='percentage'?Number(BigInt(subtotal)*BigInt(offer.value)/100n):paise(offer.value)
 return Math.min(subtotal,paise(offer.maximumDiscountPaise),amount)
}
function ensureTransition(current,action,actor,booking){
 const transitions={travel:['assigned','travelling'],arrive:['travelling','arrived'],start:['arrived','in_progress'],complete:['in_progress','completed'],cancel:['confirmed','cancelled']}
 if(action==='cancel'){
  if(actor!=='admin'||['completed','cancelled','in_progress'].includes(current))fail(409,'INVALID_TRANSITION','Booking cannot be cancelled in this state.')
  return'cancelled'
 }
 if(actor!=='worker'||String(booking.workerId)!==String(booking.actorUserId))fail(403,'FORBIDDEN','Only the assigned worker can progress service.')
 const transition=transitions[action]
 if(!transition||current!==transition[0]||booking.assignmentStatus!=='accepted')fail(409,'INVALID_TRANSITION','Booking state does not allow this operation.')
 return transition[1]
}
function collectionEvidence(booking,input,actor){
 if(booking.status!=='completed')fail(409,'SERVICE_NOT_COMPLETED','Collection is only allowed after service completion.')
 if(paise(input.amountPaise)!==paise(booking.totalPaise))fail(400,'AMOUNT_MISMATCH','Only full payment of the booking snapshot is supported.')
 if(!['cash','upi'].includes(input.method))fail(400,'INVALID_METHOD','Only Cash and UPI after completion are supported.')
 if(input.method==='upi'&&(actor!=='admin'||!input.evidenceReference?.trim()))fail(403,'UPI_NOT_VERIFIED','UPI requires authorized reconciliation with confirmed evidence.')
}
async function notify(db,session,userId,type,entityId,eventId){
 const {createHash}=require('node:crypto')
 const _id=id(createHash('sha256').update(String(userId)+':'+type+':'+String(eventId||entityId)).digest('hex').slice(0,24))
 await db.collection('notifications').updateOne({_id},{$setOnInsert:{recipientUserId:userId,type,entityId,createdAt:new Date(),isRead:false,isActive:true}},{session,upsert:true})
}
async function notifyAdmins(db,session,type,entityId,permission){
 const roles=await db.collection('roles').find({isActive:true,permissions:permission},{session,projection:{_id:1}}).toArray()
 const users=await db.collection('users').find({roleId:{$in:roles.map(r=>r._id)},userType:/^admin$/i,status:/^active$/i,isActive:true},{session,projection:{_id:1}}).limit(1000).toArray()
 for(const user of users)await notify(db,session,user._id,type,entityId)
}
async function quote(db,userId,input,session){
 const items=[],options={session}
 let subtotal=0,duration=0
 const area=await db.collection('service_areas').findOne({_id:id(input.serviceAreaId),isActive:true,isServiceable:true},options)
 if(!area)fail(400,'INVALID_SERVICE_AREA','Select an active service area.')
 for(const selected of input.items){
  const service=await requireRecord(db,'services',selected.serviceId,session,{status:'published',isActive:true,isHomeServiceAvailable:{$ne:false}})
  const category=await db.collection('service_categories').findOne({_id:service.categoryId,status:'published',isActive:true},options)
  if(!category||service.serviceAreaIds?.length&&!service.serviceAreaIds.some(a=>String(a)===String(area._id)))fail(400,'SERVICE_UNAVAILABLE','A selected service is unavailable in this area.')
  const price=paise(service.pricePaise),amount=price*selected.quantity
  subtotal+=amount;duration+=Number(service.durationMinutes)*selected.quantity
  if(!Number.isSafeInteger(subtotal)||!Number.isSafeInteger(duration)||duration>1440)fail(400,'QUOTE_TOO_LARGE','Quote exceeds supported bounds.')
  items.push({serviceId:service._id,name:service.name,pricePaise:price,quantity:selected.quantity,durationMinutes:service.durationMinutes,categoryId:service.categoryId})
 }
 let discount=0,offer
 if(input.couponCode){
  const now=new Date()
  offer=await db.collection('offers').findOne({code:input.couponCode,status:'published',isActive:true,startsAt:{$lte:now},endsAt:{$gt:now}},options)
  if(!offer||subtotal<offer.minimumOrderPaise)fail(400,'COUPON_INELIGIBLE','Coupon is unavailable or minimum order is unmet.')
  if(offer.serviceIds?.length&&items.some(i=>!offer.serviceIds.some(s=>String(s)===String(i.serviceId))))fail(400,'COUPON_INELIGIBLE','Coupon excludes a selected service.')
  if(offer.categoryIds?.length&&items.some(i=>!offer.categoryIds.some(c=>String(c)===String(i.categoryId))))fail(400,'COUPON_INELIGIBLE','Coupon excludes a selected category.')
  const usage=await db.collection('coupon_redemptions').countDocuments({offerId:offer._id,customerId:userId},options)
  if(usage>=offer.perCustomerLimit||(offer.redeemedCount||0)>=offer.totalLimit)fail(400,'COUPON_EXHAUSTED','Coupon usage limit reached.')
  if(offer.newCustomerOnly&&await db.collection('bookings').findOne({customerId:userId},options))fail(400,'COUPON_INELIGIBLE','Coupon is for first-time customers.')
  discount=discountFor(offer,subtotal)
 }
 return {items,subtotalPaise:subtotal,discountPaise:discount,totalPaise:subtotal-discount,durationMinutes:duration,serviceAreaId:area._id,offerId:offer?._id}
}
async function reserveCoupon(db,session,quote,userId,bookingId){
 if(!quote.offerId)return
 const offer=await requireRecord(db,'offers',quote.offerId,session)
 const usage=await db.collection('coupon_redemptions').countDocuments({offerId:offer._id,customerId:userId},{session})
 if(usage>=offer.perCustomerLimit || (offer.redeemedCount||0)>=offer.totalLimit)fail(409,'COUPON_EXHAUSTED','Coupon limit was reached.')
 await compareAndSet(db,'offers',offer,{redeemedCount:(offer.redeemedCount||0)+1},session)
 await db.collection('coupon_redemptions').insertOne({_id:bookingId,offerId:offer._id,customerId:userId,bookingId,discountPaise:quote.discountPaise,createdAt:new Date(),isActive:true},{session})
}
const cartSchema=z.object({
 items:z.array(z.object({serviceId:z.string().regex(/^[a-f0-9]{24}$/i),quantity:z.number().int().min(1).max(10)}).strict()).min(1).max(20),
 serviceAreaId:z.string().regex(/^[a-f0-9]{24}$/i),couponCode:z.string().regex(/^[A-Z0-9_-]{3,24}$/).optional(),
}).strict().refine(v=>new Set(v.items.map(i=>i.serviceId)).size===v.items.length,'Duplicate services are not allowed.')
module.exports={paise,discountFor,ensureTransition,collectionEvidence,notify,notifyAdmins,quote,reserveCoupon,cartSchema}
