const test=require('node:test')
const assert=require('node:assert/strict')
const express=require('express')
const http=require('node:http')
const mongoose=require('mongoose')
const {z}=require('zod')
const {errorHandler}=require('../src/middleware/errorHandler')
const {listFilter,requestIdentity,csv}=require('../src/platform/core')
const {definitions,permissions}=require('../src/platform/definitions')
const {createResourcesRouter,createPublicResourcesRouter,validateRelationships}=require('../src/platform/resources.routes')
const {createWorkflowsRouter}=require('../src/platform/workflows.routes')
const {mediaService,validateFile}=require('../src/platform/media')
const {mobileAuth,createMobileAuthRouter}=require('../src/platform/mobileAuth')
const {createMobileRouter}=require('../src/platform/mobile.routes')
const {createPlatformRouter}=require('../src/platform')
const {createServiceOtp}=require('../src/platform/service-otp')
const {discountFor,ensureTransition,collectionEvidence,cartSchema}=require('../src/platform/business')
const {encodeMoney}=require('../src/platform/database')
const userId=new mongoose.Types.ObjectId(),resourceId=new mongoose.Types.ObjectId()
const secretSession='x'.repeat(32)
async function serve(app,run){
 const server=http.createServer(app);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve))
 try{await run('http://127.0.0.1:'+server.address().port)}finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve))}
}
function authentication(perms=[]){
 return {requireAuthenticated(req,res,next){if(req.get('x-test-login')!=='yes')return next(Object.assign(new Error('Sign in'),{status:401}))
  req.auth={user:{_id:userId,roleId:new mongoose.Types.ObjectId()},role:{roleCode:'ADMIN',permissions:perms}};next()},
 requirePermission(permission){return(req,res,next)=>perms.includes(permission)?next():res.status(403).json({success:false})},
 requireCsrf(req,res,next){return req.get('x-csrf-token')==='test-csrf'?next():res.status(403).json({success:false})}}
}
function foundation(router){const app=express();app.use(express.json());app.use(router);app.use(errorHandler);return app}
const headers={'x-test-login':'yes',origin:'http://localhost:5173','x-csrf-token':'test-csrf','content-type':'application/json','x-idempotency-key':'test-operation-key-1234'}
test('pagination bounds, unknown filters, IST range and regex literal escaping',()=>{
 assert.throws(()=>listFilter({limit:101}))
 assert.throws(()=>listFilter({unexpected:'value'}))
 assert.throws(()=>listFilter({from:'2026-10-22',to:'2026-10-21'}))
 const {filter}=listFilter({from:'2026-10-21',to:'2026-10-21',search:'.*'})
 assert.equal(filter.createdAt.$gte.toISOString(),'2026-10-20T18:30:00.000Z')
 assert.equal(filter.createdAt.$lt.toISOString(),'2026-10-21T18:30:00.000Z')
 assert.equal(filter.$or[0].name.test('everything'),false)
 assert.equal(filter.$or[0].name.test('literal .* string'),true)
})
test('resource schemas reject overposting, invalid object IDs and excessive discounts',async()=>{
 const schema=z.object(definitions.roles.fields).strict()
 assert.equal(schema.safeParse({roleCode:'ADMIN',roleName:'Admin',permissions:[],isActive:true,passwordHash:'x'}).success,false)
 assert.equal(cartSchema.safeParse({items:[{serviceId:'bad',quantity:1}],serviceAreaId:String(resourceId)}).success,false)
 assert.equal(cartSchema.safeParse({items:[{serviceId:String(resourceId),quantity:1},{serviceId:String(resourceId),quantity:1}],serviceAreaId:String(resourceId)}).success,false)
 await assert.rejects(validateRelationships({},'offers',{discountType:'percentage',value:101}),e=>e.code==='VALIDATION_ERROR')
 assert.ok(permissions.includes('workers.documents.read'))
})
test('every administrative resource read rejects insufficient permission before database access',async()=>{
 const db={collection(){throw Error('Database must not be touched')}}
 await serve(foundation(createResourcesRouter({db,auth:authentication()})),async base=>{
  for(const name of Object.keys(definitions)){
   const response=await fetch(base+'/'+name,{headers})
   assert.equal(response.status,403,name)
  }
 })
})
test('administrative writes enforce CSRF even with resource permission',async()=>{
 const db={collection(){throw Error('Database must not be touched')}}
 await serve(foundation(createResourcesRouter({db,auth:authentication(permissions)})),async base=>{
  const response=await fetch(base+'/packages',{method:'POST',headers:{...headers,'x-csrf-token':''},body:'{}'})
  assert.equal(response.status,403)
 })
})
test('storage, scheduling, compensation, SMS, and service OTP remain fail-closed without providers',async()=>{
 const db={collection(){throw Error('Database must not be touched')}}
 await assert.rejects(mediaService({db}).upload({}),e=>e.code==='STORAGE_NOT_CONFIGURED')
 await serve(foundation(createWorkflowsRouter({db,auth:authentication(permissions)})),async base=>{
  assert.equal((await fetch(base+'/bookings/'+resourceId+'/assign',{method:'POST',headers,body:'{}'})).status,503)
  assert.equal((await fetch(base+'/settlements/generate',{method:'POST',headers,body:'{}'})).status,503)
 })
 await serve(foundation(createMobileAuthRouter({db})),async base=>{
  assert.equal((await fetch(base+'/otp/request',{method:'POST',headers,body:'{}'})).status,503)
  assert.equal((await fetch(base+'/otp/verify',{method:'POST',headers,body:'{}'})).status,503)
 })
})
test('media checks actual signature, exact MIME, size and private PDF visibility',()=>{
 const png=Buffer.from([137,80,78,71,13,10,26,10])
 assert.equal(validateFile(png,'image/png','public'),true)
 assert.throws(()=>validateFile(png,'image/jpeg','public'),e=>e.code==='INVALID_FILE_SIGNATURE')
 assert.throws(()=>validateFile(Buffer.from('%PDF-1.7'),'application/pdf','public'))
 assert.equal(validateFile(Buffer.from('%PDF-1.7'),'application/pdf','private'),true)
 assert.throws(()=>validateFile(Buffer.alloc(5*1024*1024+1),'image/png','public'))
 assert.throws(()=>validateFile(Buffer.alloc(0),'image/png','public'))
})
test('integer paise encode as BSON Long and discounts use exact integer arithmetic',()=>{
 const encoded=encodeMoney({pricePaise:2147483648,items:[{amountPaise:199}]})
 assert.equal(encoded.pricePaise._bsontype,'Long')
 assert.equal(encoded.items[0].amountPaise.toString(),'199')
 assert.throws(()=>encodeMoney({pricePaise:1.5}))
 assert.equal(discountFor({discountType:'percentage',value:15,maximumDiscountPaise:100000},199),29)
 assert.equal(discountFor({discountType:'fixed',value:1000,maximumDiscountPaise:500},200),200)
})
test('service lifecycle requires assigned approved actor context and valid current state',()=>{
 const booking={workerId:userId,actorUserId:userId,assignmentStatus:'accepted'}
 assert.equal(ensureTransition('assigned','travel','worker',booking),'travelling')
 assert.equal(ensureTransition('arrived','start','worker',booking),'in_progress')
 assert.throws(()=>ensureTransition('assigned','complete','worker',booking))
 assert.throws(()=>ensureTransition('assigned','travel','worker',{...booking,actorUserId:resourceId}))
 assert.throws(()=>ensureTransition('completed','cancel','admin',booking))
 assert.throws(()=>ensureTransition('in_progress','complete','admin',booking))
})
test('payment collection separates service completion and confirmed UPI evidence',()=>{
 const booking={status:'completed',totalPaise:219900}
 assert.doesNotThrow(()=>collectionEvidence(booking,{amountPaise:219900,method:'cash'},'worker'))
 assert.throws(()=>collectionEvidence({...booking,status:'in_progress'},{amountPaise:219900,method:'cash'},'admin'))
 assert.throws(()=>collectionEvidence(booking,{amountPaise:219899,method:'cash'},'admin'))
 assert.throws(()=>collectionEvidence(booking,{amountPaise:219900,method:'upi',success:true},'customer'))
 assert.doesNotThrow(()=>collectionEvidence(booking,{amountPaise:219900,method:'upi',evidenceReference:'confirmed-bank-ref'},'admin'))
})
test('idempotency keys bind identity and operation; CSV resists spreadsheet formulas',()=>{
 const req={auth:{user:{_id:userId}},body:{name:'Example'},get:()=> 'unique-operation-key'}
 const a=requestIdentity(req,'booking')
 assert.equal(String(a._id),String(requestIdentity(req,'booking')._id))
 assert.notEqual(String(a._id),String(requestIdentity(req,'payment')._id))
 assert.notEqual(a.requestHash,requestIdentity({...req,body:{name:'Other'}},'booking').requestHash)
 assert.match(csv([['=1+1',' @command']]),/'=1\+1/)
 assert.match(csv([[' @command']]),/' @command/)
})
test('mobile authentication rejects wrong app, revoked session and missing bearer',async()=>{
 const token='a'.repeat(43)
 let captured
 const db={collection(name){return {async findOne(filter){captured={name,filter};return null}}}}
 await serve(foundation((req,res,next)=>mobileAuth({db}).forApp('customer')(req,res,next)),async base=>{
  assert.equal((await fetch(base)).status,401)
  assert.equal((await fetch(base,{headers:{Authorization:'Bearer '+token}})).status,401)
 })
 assert.equal(captured.filter.appType,'customer')
 assert.equal(captured.filter.revokedAt,null)
 assert.equal(captured.filter.isActive,true)
})

function same(a,b){return a?._bsontype==='ObjectId'||b?._bsontype==='ObjectId'?String(a)===String(b):a===b}
function matches(record,filter){
 return Object.entries(filter).every(([key,value])=>{
  if(key==='$and')return value.every(v=>matches(record,v))
  if(key==='$or')return value.some(v=>matches(record,v))
  const actual=record[key]
  if(value instanceof RegExp)return value.test(String(actual||''))
  if(value&&typeof value==='object'&&!value._bsontype&&!(value instanceof Date)){
   return Object.entries(value).every(([operator,expected])=>{
    if(operator==='$in')return Array.isArray(actual)?actual.some(a=>expected.some(e=>same(a,e))):expected.some(e=>same(actual,e))
    if(operator==='$ne')return !same(actual,expected)
    if(operator==='$nin')return !expected.some(e=>same(actual,e))
    if(operator==='$exists')return (actual!==undefined)===expected
    if(operator==='$gt')return actual>expected
    if(operator==='$gte')return actual>=expected
    if(operator==='$lt')return actual<expected
    if(operator==='$lte')return actual<=expected
    return false
   })
  }
  if(Array.isArray(actual))return actual.some(a=>same(a,value))
  return same(actual,value)
 })
}
function memoryDatabase(seed={}){
 let records={...seed}
 const rows=name=>records[name]||(records[name]=[])
 const update=(record,change)=>{
  Object.assign(record,change.$set||{})
  for(const [key,value]of Object.entries(change.$inc||{}))record[key]=(record[key]||0)+value
  return record
 }
 const db={
  transactionClient:{startSession(){return{
   async withTransaction(run){
    const previous=mongoose.mongo.BSON.deserialize(mongoose.mongo.BSON.serialize(records))
    try{await run()}catch(error){records=previous;throw error}
   },async endSession(){},
  }}},
  collection(name){return{
   find(filter={}){
    let data=rows(name).filter(row=>matches(row,filter))
    return{sort(){return this},skip(n){data=data.slice(n);return this},limit(n){data=data.slice(0,n);return this},
     project(){return this},async toArray(){return data}}
   },
   async findOne(filter){return rows(name).find(row=>matches(row,filter))||null},
   async countDocuments(filter){return rows(name).filter(row=>matches(row,filter)).length},
   async insertOne(record){
    if (!record._id) record._id=new mongoose.Types.ObjectId()
    if(rows(name).some(row=>same(row._id,record._id)))throw Object.assign(Error('Duplicate'),{code:11000})
    rows(name).push(record);return{insertedId:record._id}
   },
   async findOneAndUpdate(filter,change){
    const row=rows(name).find(record=>matches(record,filter));return row?update(row,change):null
   },
   async updateOne(filter,change,options={}){
    const row=rows(name).find(record=>matches(record,filter))
    if(row){update(row,change);return{modifiedCount:1}}
    if(options.upsert){rows(name).push({...filter,...change.$set,...change.$setOnInsert});return{modifiedCount:0,upsertedCount:1}}
    return{modifiedCount:0}
   },
   async updateMany(filter,change){for(const row of rows(name).filter(r=>matches(r,filter)))update(row,change)},
  }},
  records:()=>records,
 }
 return db
}
test('package CRUD persists server-confirmed changes, handles duplicates and rolls back failed publication',async()=>{
 const serviceA=new mongoose.Types.ObjectId(),serviceB=new mongoose.Types.ObjectId()
 const db=memoryDatabase({services:[{_id:serviceA,status:'published',isActive:true},{_id:serviceB,status:'published',isActive:true}]})
 await serve(foundation(createResourcesRouter({db,auth:authentication(permissions)})),async base=>{
  const body={name:'Approved test package',description:'Deterministic mock only',components:[{serviceId:String(serviceA),quantity:1},{serviceId:String(serviceB),quantity:1}],
   pricePaise:10000,durationMinutes:60,displayOrder:1,status:'draft'}
  const response=await fetch(base+'/packages',{method:'POST',headers,body:JSON.stringify(body)})
  assert.equal(response.status,201)
  const created=(await response.json()).data
  const retry=await fetch(base+'/packages',{method:'POST',headers,body:JSON.stringify(body)})
  assert.equal(retry.status,201)
  assert.equal((await retry.json()).data._id,created._id)
  assert.equal(db.records().service_packages.length,1)
  const conflict=await fetch(base+'/packages',{method:'POST',headers,body:JSON.stringify({...body,name:'Changed with reused key'})})
  assert.equal(conflict.status,409)
  const edit=await fetch(base+'/packages/'+created._id,{method:'PATCH',headers,body:JSON.stringify({name:'Edited test package'})})
  assert.equal(edit.status,200)
  assert.equal(db.records().service_packages[0].name,'Edited test package')
  const publish=await fetch(base+'/packages/'+created._id+'/status',{method:'PATCH',headers,body:JSON.stringify({status:'published'})})
  assert.equal(publish.status,503)
  assert.equal(db.records().service_packages[0].status,'draft')
  const list=await fetch(base+'/packages?limit=1&page=1',{headers})
  assert.equal(list.status,200)
  assert.equal((await list.json()).data.pagination.total,1)
  assert.ok(db.records().audit_logs.some(row=>row.action==='packages.update'))
 })
})
test('worker approval requires private identity proof; optional certificates do not block approval',async()=>{
 const mediaId=new mongoose.Types.ObjectId()
 const db=memoryDatabase({workers:[{_id:resourceId,userId,isActive:true,status:'pending'}],
  worker_documents:[{_id:new mongoose.Types.ObjectId(),workerId:resourceId,kind:'identity',mediaAssetId:mediaId,isActive:true}],
  media_assets:[{_id:mediaId,visibility:'private',uploadStatus:'ready',isActive:true}]})
 await serve(foundation(createWorkflowsRouter({db,auth:authentication(permissions)})),async base=>{
  const response=await fetch(base+'/workers/'+resourceId+'/decision',{method:'POST',headers,body:JSON.stringify({decision:'approve',identityReviewed:true})})
  assert.equal(response.status,200)
  assert.equal(db.records().workers[0].status,'approved')
  assert.equal(db.records().notifications[0].recipientUserId.toString(),userId.toString())
 })
})
test('public service areas expose only active serviceable backend records',async()=>{
 const areaId=new mongoose.Types.ObjectId()
 const db=memoryDatabase({service_areas:[
  {_id:areaId,name:'Backend Area',city:'Latur',postalCodes:['413512'],status:'active',isActive:true,isServiceable:true},
  {_id:new mongoose.Types.ObjectId(),name:'Disabled',status:'disabled',isActive:false,isServiceable:true},
  {_id:new mongoose.Types.ObjectId(),name:'Unavailable',status:'active',isActive:true,isServiceable:false},
 ]})
 await serve(foundation(createPublicResourcesRouter({db})),async base=>{
  const response=await fetch(base+'/service-areas?page=1&limit=100')
  assert.equal(response.status,200)
  const result=(await response.json()).data
  assert.equal(result.items.length,1)
  assert.equal(result.items[0].name,'Backend Area')
  assert.equal(result.items[0]._id,String(areaId))
  assert.equal(result.pagination.hasMore,false)
 })
})

test('customer mobile profile cannot read another customer booking',async()=>{
 const token='c'.repeat(43)
 const db=memoryDatabase({users:[{_id:userId,userType:'customer',isActive:true,status:'active'}],
  auth_sessions:[{_id:new mongoose.Types.ObjectId(),userId,refreshTokenHash:require('node:crypto').createHash('sha256').update(token).digest('hex'),appType:'customer',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)}],
  bookings:[{_id:resourceId,customerId:new mongoose.Types.ObjectId(),status:'confirmed'}]})
 await serve(foundation(createMobileRouter({db})),async base=>{
  assert.equal((await fetch(base+'/customer/bookings/'+resourceId,{headers:{Authorization:'Bearer '+token}})).status,404)
  const listed=await fetch(base+'/customer/bookings',{headers:{Authorization:'Bearer '+token}})
  assert.equal(listed.status,200)
  assert.deepEqual((await listed.json()).data.items,[])
 })
})
test('customer booking creates a server-side service OTP once, including idempotent replay',async()=>{
 const customerUserId=new mongoose.Types.ObjectId(),areaId=new mongoose.Types.ObjectId()
 const addressId=new mongoose.Types.ObjectId(),serviceId=new mongoose.Types.ObjectId(),categoryId=new mongoose.Types.ObjectId()
 const token='c'.repeat(43),hash=require('node:crypto').createHash('sha256').update(token).digest('hex')
 const db=memoryDatabase({
  users:[{_id:customerUserId,userType:'customer',isActive:true,status:'active'}],
  auth_sessions:[{_id:new mongoose.Types.ObjectId(),userId:customerUserId,refreshTokenHash:hash,appType:'customer',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)}],
  service_areas:[{_id:areaId,isActive:true,isServiceable:true}],
  customer_addresses:[{_id:addressId,customerId:customerUserId,serviceAreaId:areaId,isActive:true}],
  service_categories:[{_id:categoryId,status:'published',isActive:true}],
  services:[{_id:serviceId,categoryId,status:'published',isActive:true,isHomeServiceAvailable:true,
   serviceAreaIds:[areaId],name:'Hair Spa',pricePaise:100000,durationMinutes:30}],
  app_settings:[{key:'business',isActive:true,bookingLeadMinutes:30,assignmentTimeoutMinutes:5}],
 })
 const scheduling={async reserve(){return true}}
 const serviceOtp=createServiceOtp({db})
 await serve(foundation(createMobileRouter({db,scheduling,serviceOtp})),async base=>{
  const headers={Authorization:'Bearer '+token,'content-type':'application/json','x-idempotency-key':'booking-otp-test-0001'}
  const body={
   cart:{serviceAreaId:String(areaId),items:[{serviceId:String(serviceId),quantity:1}]},
   addressId:String(addressId),
   startsAt:new Date(Date.now()+60*60*1000).toISOString(),
   method:'cash',
  }
  const create=()=>fetch(base+'/customer/bookings',{
   method:'POST',headers,body:JSON.stringify(body),
  })
  const first=await create()
  assert.equal(first.status,201)
  assert.equal((await first.json()).data.serviceOtp.status,'available')
  const replay=await create()
  assert.equal(replay.status,201)
  const challenges=db.records().service_otp_challenges
  assert.equal(challenges.length,1)
  assert.match(challenges[0].otpHash,/^\$argon2id\$/)
  assert.equal(challenges[0].otp,undefined)
 })
})
test('customer bookings reach eligible online workers and rejection advances to the next worker',async()=>{
 const customerId=new mongoose.Types.ObjectId(),areaId=new mongoose.Types.ObjectId()
 const addressId=new mongoose.Types.ObjectId(),serviceId=new mongoose.Types.ObjectId(),categoryId=new mongoose.Types.ObjectId()
 const workerUserIds=[new mongoose.Types.ObjectId(),new mongoose.Types.ObjectId()]
 const workerIds=[new mongoose.Types.ObjectId(),new mongoose.Types.ObjectId()]
 const customerToken='c'.repeat(43),workerTokens=['w'.repeat(43),'x'.repeat(43)]
 const hashToken=token=>require('node:crypto').createHash('sha256').update(token).digest('hex')
 const workers=workerIds.map((workerId,index)=>({
  _id:workerId,userId:workerUserIds[index],status:'approved',isActive:true,isOnline:true,
  serviceIds:[serviceId],serviceAreaIds:[areaId],
  compensationRule:{amountPaise:2500,effectiveFrom:new Date('2020-01-01')},
 }))
 const db=memoryDatabase({
  users:[
   {_id:customerId,userType:'customer',isActive:true,status:'active'},
   ...workerUserIds.map(_id=>({_id,userType:'worker',isActive:true,status:'active'})),
  ],
  auth_sessions:[
   {_id:new mongoose.Types.ObjectId(),userId:customerId,refreshTokenHash:hashToken(customerToken),appType:'customer',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)},
   ...workerUserIds.map((userId,index)=>({_id:new mongoose.Types.ObjectId(),userId,refreshTokenHash:hashToken(workerTokens[index]),appType:'worker',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)})),
  ],
  service_areas:[{_id:areaId,isActive:true,isServiceable:true}],
  customer_addresses:[{_id:addressId,customerId,serviceAreaId:areaId,isActive:true}],
  service_categories:[{_id:categoryId,status:'published',isActive:true}],
  services:[{_id:serviceId,categoryId,status:'published',isActive:true,isHomeServiceAvailable:true,
   serviceAreaIds:[areaId],name:'Hair Spa',pricePaise:100000,durationMinutes:30}],
  workers,
  app_settings:[{key:'business',isActive:true,bookingLeadMinutes:30,assignmentTimeoutMinutes:5}],
  worker_settlements:[{_id:new mongoose.Types.ObjectId(),workerId:workerIds[1],status:'paid'}],
 })
 const serviceOtp=createServiceOtp({db})
 await serve(foundation(createPlatformRouter({db,auth:authentication(permissions),serviceOtp,legacyWorkerOffersEnabled:true})),async base=>{
  const customerHeaders={Authorization:'Bearer '+customerToken,'content-type':'application/json','x-idempotency-key':'online-booking-test-0001'}
  const body={
   cart:{serviceAreaId:String(areaId),items:[{serviceId:String(serviceId),quantity:1}]},
   addressId:String(addressId),
   startsAt:new Date(Date.now()+60*60*1000).toISOString(),
   method:'cash',
  }
  const created=await fetch(base+'/mobile/customer/bookings',{method:'POST',headers:customerHeaders,body:JSON.stringify(body)})
  assert.equal(created.status,201)
  const booking=(await created.json()).data
  assert.equal(booking.status,'assigned')
  assert.equal(booking.assignmentStatus,'offered')
  assert.equal(String(booking.workerId),String(workerIds[0]))

  const firstOffers=await fetch(base+'/mobile/worker/offers',{headers:{Authorization:'Bearer '+workerTokens[0]}})
  const firstOffer=(await firstOffers.json()).data.items[0]
  assert.equal(String(firstOffer.bookingId),String(booking._id))
  assert.equal(firstOffer.items[0].name,'Hair Spa')

  const reject=await fetch(base+'/mobile/worker/assignments/'+firstOffer._id+'/respond',{
   method:'POST',
   headers:{Authorization:'Bearer '+workerTokens[0],'content-type':'application/json','x-idempotency-key':'worker-reject-test-0001'},
   body:JSON.stringify({decision:'reject',reason:'Unavailable today'}),
  })
  assert.equal(reject.status,200)
  const secondOffers=await fetch(base+'/mobile/worker/offers',{headers:{Authorization:'Bearer '+workerTokens[1]}})
  const secondOffer=(await secondOffers.json()).data.items[0]
  assert.equal(String(secondOffer.bookingId),String(booking._id))

  const settlements=await fetch(base+'/mobile/worker/settlements',{headers:{Authorization:'Bearer '+workerTokens[1]}})
  assert.equal(settlements.status,200)
  assert.equal((await settlements.json()).data.items.length,1)
 })
})
test('only the customer can reveal a code and only the worker route can start service',async()=>{
 const workerUserId=new mongoose.Types.ObjectId(),customerUserId=new mongoose.Types.ObjectId(),workerId=new mongoose.Types.ObjectId()
 const customerToken='c'.repeat(43),workerToken='w'.repeat(43)
 const hashToken=token=>require('node:crypto').createHash('sha256').update(token).digest('hex')
 const assignmentId=new mongoose.Types.ObjectId(),evidenceId=new mongoose.Types.ObjectId()
 const booking={_id:resourceId,customerId:customerUserId,workerId,workerUserId,assignmentId,durationMinutes:60,
  status:'arrived',assignmentStatus:'accepted',isActive:true}
 const db=memoryDatabase({
  users:[
   {_id:workerUserId,userType:'worker',isActive:true,status:'active'},
   {_id:customerUserId,userType:'customer',isActive:true,status:'active'},
  ],
  auth_sessions:[
   {_id:new mongoose.Types.ObjectId(),userId:workerUserId,refreshTokenHash:hashToken(workerToken),appType:'worker',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)},
   {_id:new mongoose.Types.ObjectId(),userId:customerUserId,refreshTokenHash:hashToken(customerToken),appType:'customer',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)},
  ],
  workers:[{_id:workerId,userId:workerUserId,status:'approved',isActive:true}],
  bookings:[booking],
  booking_assignments:[{_id:assignmentId,bookingId:resourceId,workerId,workerUserId,status:'accepted'}],
  media_assets:[{_id:evidenceId,bookingId:resourceId,workerId,uploadedBy:workerUserId,usage:'product_evidence',
   visibility:'private',uploadStatus:'ready',isActive:true,retentionExpiresAt:new Date(Date.now()+86400000)}],
 })
 const serviceOtp={
  configured:true,
  async availability(){return{status:'available',revealAllowed:true}},
  async reveal(){return{bookingId:resourceId,otp:'123456'}},
  async verify({code}){return code==='123456'},
 }
 await serve(foundation(createMobileRouter({db,serviceOtp})),async base=>{
  const customerHeaders={Authorization:'Bearer '+customerToken,'content-type':'application/json'}
  const workerHeaders={Authorization:'Bearer '+workerToken,'content-type':'application/json'}
  const details=await fetch(base+'/customer/bookings/'+resourceId,{headers:customerHeaders})
  assert.equal((await details.json()).data.serviceOtp.status,'available')

  const reveal=await fetch(base+'/customer/bookings/'+resourceId+'/service-otp/reveal',{
   method:'POST',headers:customerHeaders,body:'{}',
  })
  assert.equal(reveal.status,200)
  assert.equal(reveal.headers.get('cache-control'),'private, no-store')
  assert.equal((await reveal.json()).data.otp,'123456')

  const customerStart=await fetch(base+'/customer/bookings/'+resourceId+'/progress',{
   method:'POST',headers:customerHeaders,body:JSON.stringify({action:'start',otp:'123456'}),
  })
  assert.equal(customerStart.status,404)

  const workerStart=await fetch(base+'/worker/bookings/'+resourceId+'/progress',{
   method:'POST',headers:workerHeaders,body:JSON.stringify({action:'start',otp:'123456',evidenceIds:[String(evidenceId)]}),
  })
  assert.equal(workerStart.status,200)
  assert.equal((await workerStart.json()).data.status,'in_progress')
 })
})
test('worker extra requests require customer approval and Razorpay QR uses the updated server total',async()=>{
 const workerUserId=new mongoose.Types.ObjectId(),customerUserId=new mongoose.Types.ObjectId(),workerId=new mongoose.Types.ObjectId(),assignmentId=new mongoose.Types.ObjectId()
 const workerToken='w'.repeat(43),customerToken='c'.repeat(43)
 const hashToken=token=>require('node:crypto').createHash('sha256').update(token).digest('hex')
 const db=memoryDatabase({
  users:[
   {_id:workerUserId,userType:'worker',isActive:true,status:'active'},
   {_id:customerUserId,userType:'customer',isActive:true,status:'active'},
  ],
  auth_sessions:[
   {_id:new mongoose.Types.ObjectId(),userId:workerUserId,refreshTokenHash:hashToken(workerToken),appType:'worker',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)},
   {_id:new mongoose.Types.ObjectId(),userId:customerUserId,refreshTokenHash:hashToken(customerToken),appType:'customer',revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+60000)},
  ],
  workers:[{_id:workerId,userId:workerUserId,status:'approved',isActive:true}],
  bookings:[{_id:resourceId,customerId:customerUserId,workerId,workerUserId,assignmentId,status:'in_progress',
   assignmentStatus:'accepted',totalPaise:12000,paymentStatus:'pending'}],
  booking_assignments:[{_id:assignmentId,bookingId:resourceId,workerId,workerUserId,status:'accepted'}],
 })
 let providerCalls=0,providerAmount
 const razorpay={
  isConfigured:()=>true,
  async createQrCode(input){
   providerCalls++;providerAmount=input.amountPaise
   return{id:'qr_test_booking',image_url:'https://razorpay.test/qr.png'}
  },
  verifyWebhook:(body,signature)=>Buffer.isBuffer(body)&&signature==='verified-test-signature',
 }
 const app=express()
 app.use(express.json({verify(req,res,buffer){if(req.originalUrl.includes('/payments/razorpay/webhook'))req.rawBody=Buffer.from(buffer)}}))
 app.use(createMobileRouter({db,razorpay}))
 app.use(errorHandler)
 await serve(app,async base=>{
  const workerHeaders={Authorization:'Bearer '+workerToken,'content-type':'application/json','x-idempotency-key':'worker-extra-test-001'}
  const customerHeaders={Authorization:'Bearer '+customerToken,'content-type':'application/json'}
  const proposed=await fetch(base+'/worker/bookings/'+resourceId+'/extra-services',{
   method:'POST',headers:workerHeaders,body:JSON.stringify({name:'Hair Spa',amountPaise:5000,durationMinutes:45}),
  })
  assert.equal(proposed.status,201)
  let bookingResponse=await fetch(base+'/customer/bookings/'+resourceId,{headers:customerHeaders})
  const bookingData=(await bookingResponse.json()).data
  assert.equal(bookingData.pendingExtraServices.length,1)
  const extraId=bookingData.pendingExtraServices[0]._id
  const completeWhilePending=await fetch(base+'/worker/bookings/'+resourceId+'/progress',{
   method:'POST',headers:{...workerHeaders,'x-idempotency-key':'worker-complete-test-001'},
   body:JSON.stringify({action:'complete'}),
  })
  assert.equal(completeWhilePending.status,409)
  const approved=await fetch(base+'/customer/bookings/'+resourceId+'/extra-services/'+extraId+'/respond',{
   method:'POST',headers:customerHeaders,body:JSON.stringify({decision:'approve'}),
  })
  assert.equal(approved.status,200)
  assert.equal(db.records().bookings[0].totalPaise,17000)
  const completeBeforePayment=await fetch(base+'/worker/bookings/'+resourceId+'/progress',{
   method:'POST',headers:{...workerHeaders,'x-idempotency-key':'worker-complete-test-002'},
   body:JSON.stringify({action:'complete'}),
  })
  assert.equal(completeBeforePayment.status,409)
  const qr=await fetch(base+'/worker/bookings/'+resourceId+'/payment-qr',{
   method:'POST',headers:{...workerHeaders,'x-idempotency-key':'worker-qr-test-0001'},body:'{}',
  })
  assert.equal(qr.status,201)
  assert.equal(providerAmount,17000)
  assert.equal((await qr.json()).data.amountPaise,17000)
  const retry=await fetch(base+'/worker/bookings/'+resourceId+'/payment-qr',{
   method:'POST',headers:{...workerHeaders,'x-idempotency-key':'worker-qr-test-0002'},body:'{}',
  })
  assert.equal(retry.status,200)
  assert.equal(providerCalls,1)
  const webhook=await fetch(base+'/payments/razorpay/webhook',{
   method:'POST',headers:{'content-type':'application/json','x-razorpay-signature':'verified-test-signature'},
   body:JSON.stringify({event:'qr_code.credited',payload:{payment:{entity:{
    id:'pay_test_booking',qr_code_id:'qr_test_booking',status:'captured',amount:17000,currency:'INR',
   }}}}),
  })
  assert.equal(webhook.status,200)
  assert.equal(db.records().bookings[0].paymentStatus,'paid')
  assert.equal(db.records().bookings[0].status,'in_progress')
 })
})

test('fake storage adapter persists private metadata without publishing a private URL',async()=>{
 const db=memoryDatabase(),stored=[],removed=[]
 const storage=mediaService({db,adapter:{
  async put(input){stored.push(input);return{storageKey:input.storageKey,storageProvider:'s3'}},
  async remove(input){removed.push(input)},async signedRead(){return'https://signed.example/short-lived'},
 }})
 const req={auth:{user:{_id:userId},role:{roleCode:'ADMIN'}},body:Buffer.from('%PDF-1.7'),
  id:'mock-request',get(name){return({'content-type':'application/pdf','x-media-visibility':'private','x-file-name':'identity.pdf'})[name]}}
 const record=await storage.upload(req)
 assert.equal(stored.length,1);assert.equal(record.visibility,'private');assert.equal(record.publicUrl,undefined)
 assert.equal(db.records().media_assets.length,1)
 assert.equal(db.records().audit_logs[0].changes.fields.length,0)
 assert.equal(removed.length,0)
})
test('fake SMS verifies once, creates one customer, and never returns the OTP or password hash',async()=>{
 const db=memoryDatabase();let delivered
 const sms={configured:true,async send(input){delivered=input;return{requestId:'provider-test'}},async verify(input){return input.code==='654321'},async resend(){return true}}
 await serve(foundation(createMobileAuthRouter({db,sms})),async base=>{
  const requested=await fetch(base+'/otp/request',{method:'POST',headers,body:JSON.stringify({mobileNumber:'+919999999999',appType:'customer',flow:'registration'})})
  assert.equal(requested.status,201)
  const challenge=(await requested.json()).data
  assert.equal(challenge.code,undefined)
  const verifyBody={challengeId:challenge.challengeId,code:'654321',fullName:'Mock customer'}
  const response=await fetch(base+'/otp/verify',{method:'POST',headers,body:JSON.stringify(verifyBody)})
  assert.equal(response.status,200)
  const proof=(await response.json()).data
  assert.equal(proof.registrationRequired,true)
  assert.equal(delivered.code,undefined)
  const registered=await fetch(base+'/register/customer',{method:'POST',headers,body:JSON.stringify({registrationToken:proof.registrationToken,fullName:'Mock customer'})})
  assert.equal(registered.status,201)
  const verified=(await registered.json()).data
  assert.equal(verified.accessToken.length,43)
  assert.equal(verified.passwordHash,undefined)
  assert.equal(db.records().users.length,1)
  assert.equal(db.records().customers.length,1)
  assert.notEqual(db.records().auth_sessions[0].refreshTokenHash,verified.accessToken)
  const repeated=await fetch(base+'/otp/verify',{method:'POST',headers,body:JSON.stringify(verifyBody)})
  assert.equal(repeated.status,401)
  assert.equal(db.records().users.length,1)
 })
})
