const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { createPaymentRecoveryRouter } = require('../src/platform/payment-recovery')
const { errorHandler } = require('../src/middleware/errorHandler')
const oid = () => new mongoose.Types.ObjectId()

for (const scenario of ['recover','wrong-booking','wrong-amount','permission','already-linked']) test('QR recovery: ' + scenario, async () => {
  const booking = {_id:oid(),workerUserId:oid(),customerId:oid(),totalPaise:17055,status:'in_progress',paymentStatus:'pending',paymentMethod:'razorpay_qr',serviceFinishedAt:new Date(),paymentQrRequestId:oid()}
  if(scenario==='already-linked')booking.paymentQrCodeId='qr_other'
  const db=memoryDatabase({bookings:[booking]})
  const provider={id:'qr_original',type:'upi_qr',usage:'single_use',fixed_amount:true,status:'active',payment_amount:17055,image_url:'https://provider.test/qr.png',notes:{bookingId:String(booking._id)}}
  if(scenario==='wrong-booking')provider.notes.bookingId=String(oid())
  if(scenario==='wrong-amount')provider.payment_amount=1
  const auth={requireAuthenticated(req,res,next){req.auth={user:{_id:oid()},role:{roleCode:'ADMIN'}};next()},requireCsrf(req,res,next){next()},requirePermission(){return(req,res,next)=>scenario==='permission'?res.status(403).json({success:false}):next()}}
  const app=express();app.use(express.json());app.use(createPaymentRecoveryRouter({db,auth,razorpay:{async fetchQrCode(){return provider}}}));app.use(errorHandler)
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve))
  try {
    const response=await fetch('http://127.0.0.1:'+server.address().port+'/bookings/'+booking._id+'/payment-qr/recover',{method:'POST',headers:{origin:'http://localhost:5173','content-type':'application/json'},body:JSON.stringify({providerQrCodeId:'qr_original'})})
    assert.equal(response.status,scenario==='recover'?200:scenario==='permission'?403:409,await response.text())
    assert.equal(db.records().bookings[0].paymentStatus,'pending')
    assert.equal(db.records().bookings[0].paymentQrRequestId.toString(),booking.paymentQrRequestId.toString())
    assert.equal((db.records().payment_qr_codes||[]).length,scenario==='recover'?1:0)
    if(scenario==='recover')assert.equal(db.records().bookings[0].paymentQrCodeId,'qr_original')
  } finally {server.closeAllConnections();await new Promise(resolve=>server.close(resolve))}
})
