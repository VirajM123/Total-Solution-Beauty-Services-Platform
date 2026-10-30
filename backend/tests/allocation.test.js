const test=require('node:test')
const assert=require('node:assert/strict')
const express=require('express')
const mongoose=require('mongoose')
const {memoryDatabase}=require('./admin-test-db.cjs')
const {createAllocationRouter}=require('../src/platform/allocation.routes')
const {createWorkflowsRouter}=require('../src/platform/workflows.routes')
const {errorHandler}=require('../src/middleware/errorHandler')

test('allocation queue excludes assigned bookings; approval checks eligibility and replays without duplicate assignments',async()=>{
 const oid=()=>new mongoose.Types.ObjectId()
 const admin=oid(),bookingId=oid(),area=oid(),service=oid(),workerId=oid(),customer=oid()
 const booking={_id:bookingId,customerId:customer,workerId:null,status:'confirmed',assignmentStatus:'searching',serviceAreaId:area,startsAt:new Date('2036-10-21T10:00:00Z'),endsAt:new Date('2036-10-21T11:00:00Z'),items:[{serviceId:service}],totalPaise:10000}
 const worker={_id:workerId,userId:oid(),fullName:'Test expert',status:'approved',isActive:true,isOnline:true,serviceAreaIds:[area],serviceIds:[service],compensationRule:{effectiveFrom:new Date('2020-01-01'),amountPaise:1000}}
 const db=memoryDatabase({bookings:[booking,{...booking,_id:oid(),workerId:oid(),status:'assigned'}],users:[{_id:worker.userId,isActive:true,status:'active'}],worker_availability:[{workerId,isActive:true,startsAt:new Date('2030-01-01'),endsAt:new Date('2040-01-01')}],workers:[worker],service_areas:[{_id:area,isActive:true,isServiceable:true}]})
 let permissions=['bookings.read','bookings.assign']
 let allowed=true
 const auth={requireAuthenticated(req,res,next){req.auth={user:{_id:admin},role:{roleCode:'ADMIN',permissions}};next()},requireCsrf(req,res,next){next()},requirePermission(permission){return(req,res,next)=>req.auth.role.permissions.includes(permission)?next():res.sendStatus(403)}}
 const scheduling={async canAssign(){return allowed}}
 const app=express();app.use(express.json());app.use(createAllocationRouter({db,auth,scheduling}));app.use(createWorkflowsRouter({db,auth,scheduling}));app.use(errorHandler)
 const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve))
 const base=`http://127.0.0.1:${server.address().port}`
 const headers={origin:'http://localhost:5173','content-type':'application/json','x-idempotency-key':'allocation-approval-test-001'}
 const post=body=>fetch(`${base}/bookings/${bookingId}/assign`,{method:'POST',headers,body:JSON.stringify(body)})
 try{
  permissions=[]
  assert.equal((await fetch(base+'/allocations')).status,403)
  assert.equal((await fetch(`${base}/allocations/${bookingId}/eligible-workers`)).status,403)
  permissions=['bookings.read','bookings.assign']
  let response=await fetch(base+'/allocations');assert.equal(response.status,200);assert.equal((await response.json()).data.items.length,1)
  response=await fetch(`${base}/allocations/${bookingId}/eligible-workers`);assert.equal((await response.json()).data.items[0].eligible,true)
  allowed=false
  response=await fetch(`${base}/allocations/${bookingId}/eligible-workers`);assert.match((await response.json()).data.items[0].reason,/schedule/)
  assert.equal((await post({workerId:String(workerId),reason:'Approve booking allocation'})).status,409)
  assert.equal(db.records().booking_assignments?.length||0,0)
  allowed=true
  const body={workerId:String(workerId),reason:'Approve booking allocation'}
  response=await post(body);assert.equal(response.status,200);assert.equal((await response.json()).data.status,'assigned')
  assert.equal((await post(body)).status,200)
  assert.equal(db.records().booking_assignments.length,1)
  assert.equal(String(db.records().bookings[0].assignmentId),String(db.records().booking_assignments[0]._id))
  assert.equal(db.records().booking_assignments[0].status,'assigned')
  assert.equal(db.records().booking_events.filter(event=>event.type==='assignment_assigned').length,1)
  assert.equal((await post({...body,reason:'Different reason'})).status,409)
  response=await fetch(base+'/allocations');assert.equal((await response.json()).data.items.length,0)
 }finally{await new Promise(resolve=>server.close(resolve))}
})
