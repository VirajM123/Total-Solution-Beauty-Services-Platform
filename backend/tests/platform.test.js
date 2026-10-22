const test=require('node:test')
const assert=require('node:assert/strict')
const express=require('express')
const http=require('node:http')
const mongoose=require('mongoose')
const {z}=require('zod')
const {errorHandler}=require('../src/middleware/errorHandler')
const {listFilter,requestIdentity,csv}=require('../src/platform/core')
const {definitions,permissions}=require('../src/platform/definitions')
const {createResourcesRouter,validateRelationships}=require('../src/platform/resources.routes')
const {createWorkflowsRouter}=require('../src/platform/workflows.routes')
const {mediaService,validateFile}=require('../src/platform/media')
const {mobileAuth,createMobileAuthRouter}=require('../src/platform/mobileAuth')
const {createMobileRouter}=require('../src/platform/mobile.routes')
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
 const sms={async send(input){delivered=input}}
 await serve(foundation(createMobileAuthRouter({db,sms})),async base=>{
  const requested=await fetch(base+'/otp/request',{method:'POST',headers,body:JSON.stringify({mobileNumber:'+919999999999',appType:'customer'})})
  assert.equal(requested.status,201)
  const challenge=(await requested.json()).data
  assert.equal(challenge.code,undefined)
  const verifyBody={challengeId:challenge.challengeId,code:delivered.code,fullName:'Mock customer'}
  const response=await fetch(base+'/otp/verify',{method:'POST',headers,body:JSON.stringify(verifyBody)})
  assert.equal(response.status,200)
  const verified=(await response.json()).data
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
