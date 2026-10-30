const test=require('node:test')
const assert=require('node:assert/strict')
const express=require('express')
const mongoose=require('mongoose')
const {createHash,createHmac}=require('node:crypto')
const {memoryDatabase}=require('./admin-test-db.cjs')
const {createMobileRouter}=require('../src/platform/mobile.routes')
const {createWorkflowsRouter}=require('../src/platform/workflows.routes')
const {createAllocationRouter}=require('../src/platform/allocation.routes')
const {createAdminOperationsRouter}=require('../src/platform/admin-operations')
const {mediaService}=require('../src/platform/media')
const {createRazorpay}=require('../src/platform/razorpay')
const {createBookingControlOtp}=require('../src/platform/booking-control-otp')
const {requestDueExtensions}=require('../src/jobs/durationExtension.job')
const {errorHandler}=require('../src/middleware/errorHandler')

test('one order: admin allocation → worker proof/OTP → approved extras → exact QR → signed payment → customer receipt/review',async()=>{
 const oid=()=>new mongoose.Types.ObjectId(),bookingId=oid(),workerId=oid(),workerUserId=oid(),customerId=oid(),adminId=oid(),serviceId=oid(),areaId=oid()
 const tokens={worker:'w'.repeat(43),customer:'c'.repeat(43)}
 const db=memoryDatabase({
  users:[{_id:workerUserId,userType:'worker',isActive:true,status:'active'},{_id:customerId,userType:'customer',isActive:true,status:'active'}],
  auth_sessions:Object.entries(tokens).map(([appType,token])=>({_id:oid(),userId:appType==='worker'?workerUserId:customerId,appType,refreshTokenHash:createHash('sha256').update(token).digest('hex'),revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+600000)})),
  bookings:[{_id:bookingId,customerId,workerId:null,status:'confirmed',assignmentStatus:'searching',durationMinutes:60,totalPaise:12005,isActive:true,items:[{serviceId}],serviceAreaId:areaId,startsAt:new Date('2036-10-21T10:00:00Z'),endsAt:new Date('2036-10-21T11:00:00Z')}],
  workers:[{_id:workerId,userId:workerUserId,status:'approved',isActive:true,isOnline:true,serviceIds:[serviceId],serviceAreaIds:[areaId],compensationRule:{effectiveFrom:new Date('2020-01-01'),amountPaise:1000}}],
  worker_availability:[{workerId,isActive:true,startsAt:new Date('2030-01-01'),endsAt:new Date('2040-01-01')}],
  service_areas:[{_id:areaId,isActive:true,isServiceable:true}],
 })
 const stored=new Map()
 const storage=mediaService({db,adapter:{async put(input){stored.set(input.storageKey,input.bytes);return{storageKey:input.storageKey,storageProvider:'s3'}},async remove({storageKey}){stored.delete(storageKey)},async signedRead(){return'https://private.test/photo'}}})
 let providerCalls=0,charged=0
 const config={RAZORPAY_ENABLED:true,RAZORPAY_QR_ENABLED:true,RAZORPAY_KEY_ID:'rzp_test_fixture',RAZORPAY_KEY_SECRET:'fixture-key',RAZORPAY_CURRENCY:'INR',RAZORPAY_WEBHOOK_SECRET:'fixture-webhook'}
 const razorpay=createRazorpay({config,fetchImpl:async(url,options)=>{providerCalls++;charged=JSON.parse(options.body).payment_amount;return{ok:true,json:async()=>({id:'qr_fixture',image_url:'https://provider.test/qr.png'})}}})
 const auth={requireAuthenticated(req,res,next){req.auth={user:{_id:adminId},role:{roleCode:'ADMIN',permissions:['bookings.read','bookings.assign']}};next()},requireCsrf(req,res,next){next()},requirePermission(){return(req,res,next)=>next()}}
 const controlOtp=createBookingControlOtp({db})
 const scheduling={async canAssign(){return true}}
 const app=express();app.use(express.json({verify(req,res,buffer){req.rawBody=Buffer.from(buffer)}}))
 app.use('/admin',createAllocationRouter({db,auth,scheduling}),createWorkflowsRouter({db,auth,scheduling}),createAdminOperationsRouter({db,auth,storage,scheduling,controlOtp}))
 app.use('/mobile',createMobileRouter({db,storage,razorpay,controlOtp,serviceOtp:{async verify({code}){return code==='123456'}}}));app.use(errorHandler)
 const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));const base=`http://127.0.0.1:${server.address().port}`
 let seq=0
 async function request(path,body,actor='worker',expected=200){const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{authorization:'Bearer '+tokens[actor],origin:'http://localhost:5173','content-type':'application/json','x-idempotency-key':'flow-operation-'+String(++seq).padStart(8,'0')},body:body===undefined?undefined:JSON.stringify(body)});const data=await response.json();assert.equal(response.status,expected,JSON.stringify(data));return data.data}
 const workerPath=`/mobile/worker/bookings/${bookingId}`,customerPath=`/mobile/customer/bookings/${bookingId}`
 try{
  assert.equal((await request('/admin/allocations')).items.length,1)
  await request(`/admin/bookings/${bookingId}/assign`,{workerId:String(workerId),reason:'Test administrator allocation'})
  assert.equal((await request(workerPath)).status,'assigned')
  await request(workerPath+'/progress',{action:'travel'});await request(workerPath+'/progress',{action:'arrive'})
  await request(workerPath+'/progress',{action:'start',otp:'123456'},'worker',400)
  const upload=await fetch(base+workerPath+'/product-evidence',{method:'POST',headers:{authorization:'Bearer '+tokens.worker,'content-type':'image/jpeg','x-file-name':'products.jpg'},body:Buffer.from([255,216,255,1,2,3])})
  assert.equal(upload.status,201);const evidence=(await upload.json()).data
  await request(workerPath+'/progress',{action:'start',otp:'000000',evidenceIds:[evidence._id]},'worker',401)
  const started=await request(workerPath+'/progress',{action:'start',otp:'123456',evidenceIds:[evidence._id]})
  assert.equal(+new Date(started.serviceEndsAt)- +new Date(started.serviceStartedAt),3600000)
  const extra=await request(workerPath+'/extra-services',{name:'Approved extra',amountPaise:5050,durationMinutes:15},'worker',201)
  await request(workerPath+'/payment-qr',{},'worker',409)
  await request(customerPath+`/extra-services/${extra._id}/respond`,{decision:'approve'},'customer')
  await db.collection('bookings').updateOne({_id:bookingId},{$set:{serviceEndsAt:new Date(Date.now()-1000)}})
  assert.equal(await requestDueExtensions({db}),1)
  const extensionOtp=await request(`/admin/bookings/${bookingId}/control-otp`,{purpose:'duration_extension'},'worker',201)
  await request(workerPath+'/progress',{action:'continue',otp:'000000'},'worker',401)
  const continued=await request(workerPath+'/progress',{action:'continue',otp:extensionOtp.otp})
  assert.equal(continued.durationExtension.status,'approved')
  assert.ok(continued.durationExtension.adminOtpVerifiedAt)
  await db.collection('bookings').updateOne({_id:bookingId},{$set:{paymentMethod:'cash'}})
  const qr=await request(workerPath+'/payment-qr',{},'worker',201)
  assert.equal(qr.amountPaise,17055);assert.equal(charged,17055)
  assert.equal((await request(workerPath)).status,'in_progress')
  assert.ok((await request(workerPath)).serviceFinishedAt)
  await request(workerPath+'/extra-services',{name:'Too late',amountPaise:100,durationMinutes:5},'worker',409)
  await request(workerPath+'/progress',{action:'complete'},'worker',409)
  assert.equal(await requestDueExtensions({db,now:new Date('2040-01-01')}),0)
  await request(workerPath+'/payment-qr',{});assert.equal(providerCalls,1)
  await request(workerPath+'/progress',{action:'finish'},'worker',409)
  const workflow=await request(`/admin/bookings/${bookingId}/workflow`);assert.equal(workflow.paymentStatus,'pending');assert.ok(workflow.serviceFinishedAt)
  async function webhook(amount,signatureValid=true){const body=JSON.stringify({event:'qr_code.credited',payload:{payment:{entity:{id:'pay_fixture',status:'captured',amount,currency:'INR'}},qr_code:{entity:{id:'qr_fixture'}}}});const signature=createHmac('sha256',config.RAZORPAY_WEBHOOK_SECRET).update(body).digest('hex');return fetch(base+'/mobile/payments/razorpay/webhook',{method:'POST',headers:{'content-type':'application/json','x-razorpay-signature':signatureValid?signature:'0'.repeat(64)},body})}
  assert.equal((await webhook(17055,false)).status,401)
  assert.equal((await webhook(17054)).status,400)
  assert.equal(db.records().payments?.length||0,0)
  assert.equal((await webhook(17055)).status,200);assert.equal((await webhook(17055)).status,200)
  assert.equal(db.records().payments.length,1)
  const paidAwaitingOtp=await request(customerPath,undefined,'customer');assert.equal(paidAwaitingOtp.status,'in_progress');assert.equal(paidAwaitingOtp.paymentStatus,'paid')
  await request(workerPath+'/progress',{action:'complete'},'worker',400)
  const completionOtp=await request(`/admin/bookings/${bookingId}/control-otp`,{purpose:'service_completion'},'worker',201)
  assert.match(completionOtp.otp,/^\d{6}$/)
  await request(workerPath+'/progress',{action:'complete',otp:'000000'},'worker',401)
  const completedByWorker=await request(workerPath+'/progress',{action:'complete',otp:completionOtp.otp})
  assert.equal(completedByWorker.status,'completed')
  const completed=await request(customerPath,undefined,'customer');assert.equal(completed.status,'completed');assert.equal(completed.paymentStatus,'paid')
  const receipt=await request(`/mobile/customer/payments/${db.records().payments[0]._id}/receipt`,undefined,'customer');assert.equal(receipt.amountPaise,17055)
  await request('/mobile/customer/reviews',{bookingId:String(bookingId),rating:5,comment:'Good service'},'customer',201)
  const cashBookingId=oid(),cashAssignmentId=oid()
  await db.collection('bookings').insertOne({_id:cashBookingId,customerId,workerId,workerUserId,status:'in_progress',assignmentId:cashAssignmentId,assignmentStatus:'assigned',paymentMethod:'razorpay_qr',paymentStatus:'pending',totalPaise:12005,durationMinutes:60,serviceStartedAt:new Date(),isActive:true})
  await db.collection('booking_assignments').insertOne({_id:cashAssignmentId,bookingId:cashBookingId,workerId,workerUserId,status:'assigned',isActive:true,createdAt:new Date()})
  const cashWorkerPath=`/mobile/worker/bookings/${cashBookingId}`
  await request(cashWorkerPath+'/progress',{action:'finish'})
  assert.equal((await request(cashWorkerPath)).paymentMethod,'cash')
  await request(cashWorkerPath+'/payment-qr',{},'worker',409)
  await request('/admin/payments/reconcile',{bookingId:String(cashBookingId),amountPaise:12005,method:'cash',evidenceReference:'cash-receipt-1'},'worker',409)
  await request(cashWorkerPath+'/cash-collection',{amountPaise:12005,reference:'cash-receipt-1'},'worker',201)
  await request(cashWorkerPath+'/cash-collection',{amountPaise:12005,reference:'cash-receipt-1'},'worker',409)
  const pendingCash=(await request('/admin/pending-payments',undefined,'worker')).items.find(item=>String(item._id)===String(cashBookingId))
  assert.equal(pendingCash.cashReportReference,'cash-receipt-1')
  const cashDetail=await request(cashWorkerPath)
  assert.ok(cashDetail.cashCollectionReportedAt)
  await request('/admin/payments/reconcile',{bookingId:String(cashBookingId),amountPaise:12005,method:'cash',evidenceReference:'wrong-reference'},'worker',409)
  await request('/admin/payments/reconcile',{bookingId:String(cashBookingId),amountPaise:12005,method:'cash',evidenceReference:'cash-receipt-1'},'worker',201)
  await request(cashWorkerPath+'/progress',{action:'complete'},'worker',400)
  const cashCompletionOtp=await request(`/admin/bookings/${cashBookingId}/control-otp`,{purpose:'service_completion'},'worker',201)
  const cashCompleted=await request(cashWorkerPath+'/progress',{action:'complete',otp:cashCompletionOtp.otp})
  assert.equal(cashCompleted.status,'completed')
 }finally{await new Promise(resolve=>server.close(resolve))}
})
