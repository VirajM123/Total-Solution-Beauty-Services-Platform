// Additional domain contracts: proposed field mapping until live validators are rechecked.
// No model can create a collection or index.
const mongoose=require('mongoose')
const collections={
 Customer:'customers',CustomerAddress:'customer_addresses',CustomerFavorite:'customer_favorites',
 Worker:'workers',WorkerSkill:'worker_skills',WorkerAvailability:'worker_availability',
 WorkerLeave:'worker_leaves',WorkerDocument:'worker_documents',WorkerLocation:'worker_locations',
 Package:'service_packages',Offer:'offers',CouponRedemption:'coupon_redemptions',Banner:'promotional_banners',
 AppSetting:'app_settings',Cart:'carts',Booking:'bookings',BookingEvent:'booking_events',BookingSlot:'booking_slots',
 Assignment:'booking_assignments',ServiceEvent:'service_events',ServiceOtp:'service_otp_challenges',
 Payment:'payments',PaymentEvent:'payment_events',Settlement:'worker_settlements',SettlementItem:'worker_settlement_items',
 Notification:'notifications',Review:'reviews',SupportTicket:'support_tickets',LoginOtp:'otp_challenges',
}
const oid=mongoose.Schema.Types.ObjectId
const shared={createdAt:Date,updatedAt:Date,isActive:Boolean,schemaVersion:Number,userId:oid,customerId:oid,workerId:oid,
 bookingId:oid,serviceId:oid,serviceAreaId:oid,roleId:oid,status:String,name:String,
 pricePaise:mongoose.Schema.Types.BigInt,totalPaise:mongoose.Schema.Types.BigInt,amountPaise:mongoose.Schema.Types.BigInt}
module.exports=Object.fromEntries(Object.entries(collections).map(([name,collection])=>{
 const schema=new mongoose.Schema(shared,{collection,strict:false,autoCreate:false,autoIndex:false,timestamps:false,versionKey:false})
 return [name,mongoose.models['Central'+name]||mongoose.model('Central'+name,schema,collection)]
}))
