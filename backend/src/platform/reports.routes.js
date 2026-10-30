const {z}=require('zod')
const {reply,handler,protectedRouter,listFilter,list,csv,fail}=require('./core')
const financialStatuses={status:'paid',verification:{$in:['authorized_reconciliation','provider_verified']}}
function createReportsRouter({db,auth}){
 const router=protectedRouter(auth)
 router.get('/dashboard',auth.requirePermission('reports.read'),handler(async(req,res)=>{
  const {filter}=listFilter(req.query,[], 'startsAt')
  const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata'}).format(new Date())
  const start=new Date(today+'T00:00:00+05:30'),end=new Date(start.getTime()+86400000)
  const [bookingStatuses,customers,workers,pendingWorkers,todayBookings,collections,pendingSettlements,popular,recent]=await Promise.all([
   db.collection('bookings').aggregate([{$match:filter},{$group:{_id:{booking:'$status',assignment:'$assignmentStatus',payment:'$paymentStatus'},count:{$sum:1},bookedPaise:{$sum:'$totalPaise'}}}]).toArray(),
   db.collection('customers').countDocuments({isActive:true}),
   db.collection('workers').countDocuments({status:'approved',isActive:true}),
   db.collection('workers').countDocuments({status:'pending'}),
   db.collection('bookings').countDocuments({startsAt:{$gte:start,$lt:end}}),
   db.collection('payments').aggregate([{$match:{...financialStatuses,...(filter.startsAt?{paidAt:filter.startsAt}:{})}},{$group:{_id:'$method',collectedPaise:{$sum:'$amountPaise'},count:{$sum:1}}}]).toArray(),
   db.collection('worker_settlements').countDocuments({status:'pending'}),
   db.collection('bookings').aggregate([{$match:filter},{$unwind:'$items'},{$group:{_id:'$items.serviceId',bookedQuantity:{$sum:'$items.quantity'}}},{$sort:{bookedQuantity:-1}},{$limit:10}]).toArray(),
   db.collection('audit_logs').find({},{projection:{action:1,entityType:1,entityId:1,createdAt:1}}).sort({createdAt:-1}).limit(15).toArray(),
  ])
  reply(req,res,{today,todayBookings,totalCustomers:customers,approvedWorkers:workers,pendingWorkerApprovals:pendingWorkers,pendingSettlements,bookingStatuses,verifiedCollections:collections,popularServices:popular,recentActivity:recent,
   note:'Booked value, verified customer collections and settlement earnings are separate measures.'})
 }))
 const allowed={bookings:{collection:'bookings',date:'startsAt',fields:['status']},payments:{collection:'payments',date:'paidAt',fields:['status']},
  workers:{collection:'workers',date:'createdAt',fields:['fullName']},settlements:{collection:'worker_settlements',date:'createdAt',fields:['status']},
  redemptions:{collection:'coupon_redemptions',date:'createdAt',fields:['offerId']},customers:{collection:'customers',date:'createdAt',fields:['fullName']}}
 for(const [name,spec] of Object.entries(allowed)){
  router.get('/reports/'+name,auth.requirePermission('reports.read'),auth.requirePermission((name==='redemptions'?'offers':name)+'.read'),handler(async(req,res)=>{
   reply(req,res,await list(db,spec.collection,req.query,{fields:spec.fields,dateField:spec.date,projection:{passwordHash:0,otpHash:0,refreshTokenHash:0}}))
  }))
  router.get('/reports/'+name+'/export',auth.requirePermission('reports.read'),auth.requirePermission((name==='redemptions'?'offers':name)+'.read'),handler(async(req,res)=>{
   const {filter}=listFilter(req.query,spec.fields,spec.date)
   const cursor=db.collection(spec.collection).find({$and:[filter,{isDeleted:{$ne:true}}]},{projection:{_id:1,status:1,createdAt:1,totalPaise:1,amountPaise:1,earningsPaise:1,method:1}}).sort({createdAt:-1,_id:1})
   const fields=['_id','status','createdAt','totalPaise','amountPaise','earningsPaise','method']
   res.type('text/csv').attachment('hii-beauty-'+name+'.csv')
   res.write(csv([fields])+'\r\n')
   try{
    for await(const record of cursor){
     if(res.destroyed)break
     if(!res.write(csv([fields.map(field=>record[field])]).slice(1)+'\r\n'))await require('node:events').once(res,'drain')
    }
   }finally{await cursor.close()}
   res.end()
  }))
 }
 return router
}
module.exports={createReportsRouter}
