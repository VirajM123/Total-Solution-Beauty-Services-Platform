const test=require('node:test')
const assert=require('node:assert/strict')
const express=require('express')
const mongoose=require('mongoose')
const {createHash}=require('node:crypto')
const {memoryDatabase}=require('./admin-test-db.cjs')
const {createMobileRouter}=require('../src/platform/mobile.routes')
const {requestDueExtensions,expireExtensionDecisions}=require('../src/jobs/durationExtension.job')
const {errorHandler}=require('../src/middleware/errorHandler')

for(const decision of ['approve','decline','timeout'])test(`extension ${decision}: durable single request, deterministic decision, no automatic charge`,async()=>{
 const customerId=new mongoose.Types.ObjectId(),bookingId=new mongoose.Types.ObjectId(),token='c'.repeat(43),now=new Date()
 const db=memoryDatabase({users:[{_id:customerId,userType:'customer',status:'active',isActive:true}],auth_sessions:[{userId:customerId,appType:'customer',refreshTokenHash:createHash('sha256').update(token).digest('hex'),isActive:true,revokedAt:null,expiresAt:new Date(+now+3600000)}],bookings:[{_id:bookingId,customerId,status:'in_progress',totalPaise:12000,serviceEndsAt:new Date(+now-1000)}]})
 assert.equal(await requestDueExtensions({db,now}),1)
 assert.equal(await requestDueExtensions({db,now}),0)
 const extension=db.records().bookings[0].durationExtension
 assert.equal(extension.minutes,15);assert.equal(extension.pricePaise,0)
 const app=express();app.use(express.json());app.use(createMobileRouter({db}));app.use(errorHandler)
 const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve))
 const respond=()=>fetch(`http://127.0.0.1:${server.address().port}/customer/bookings/${bookingId}/duration-extensions/${extension.id}/respond`,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json','x-idempotency-key':'extension-decision-test-key'},body:JSON.stringify({decision:decision==='timeout'?'approve':decision})})
 try{
  if(decision==='timeout'){
   assert.equal(await expireExtensionDecisions({db,now:new Date(+now+301000)}),1)
   assert.equal(await expireExtensionDecisions({db,now:new Date(+now+301000)}),0)
   assert.equal((await respond()).status,409)
  }else{
   assert.equal((await respond()).status,200)
   assert.equal((await respond()).status,200)
  }
  const booking=db.records().bookings[0]
  assert.equal(booking.durationExtension.status,decision==='approve'?'approved':decision==='decline'?'declined':'expired')
  assert.equal(booking.totalPaise,12000)
  if(decision==='approve')assert.equal(+booking.serviceEndsAt- +booking.durationExtension.extraTimeStartedAt,15*60000)
  else assert.equal(+booking.serviceEndsAt,+now-1000)
  assert.equal(await requestDueExtensions({db,now:new Date(+now+3600000)}),0)
 }finally{await new Promise(resolve=>server.close(resolve))}
})
