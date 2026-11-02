const test=require('node:test'),assert=require('node:assert/strict'),express=require('express'),mongoose=require('mongoose');
const {createHash}=require('node:crypto');
const {memoryDatabase}=require('./admin-test-db.cjs');
const {createMobileRouter}=require('../src/platform/mobile.routes');
const {errorHandler}=require('../src/middleware/errorHandler');
test('customer photo persists, rejects another owner, and booking exposes saved worker photo',async()=>{
 const userId=new mongoose.Types.ObjectId(),workerId=new mongoose.Types.ObjectId(),bookingId=new mongoose.Types.ObjectId(),photoId=new mongoose.Types.ObjectId(),otherPhotoId=new mongoose.Types.ObjectId();
 const token='p'.repeat(43);
 const db=memoryDatabase({users:[{_id:userId,userType:'customer',fullName:'Customer',isActive:true,status:'active'},{_id:workerId,fullName:'Beauty Expert',profileImageUrl:'https://example.com/worker.jpg'}],customers:[{_id:new mongoose.Types.ObjectId(),userId}],workers:[],bookings:[{_id:bookingId,customerId:userId,workerUserId:workerId}],media_assets:[{_id:photoId,uploadedBy:userId,visibility:'public',uploadStatus:'ready',isActive:true,mimeType:'image/jpeg',publicUrl:'https://example.com/customer.jpg'},{_id:otherPhotoId,uploadedBy:workerId,visibility:'public',uploadStatus:'ready',isActive:true,mimeType:'image/jpeg',publicUrl:'https://example.com/other.jpg'}],auth_sessions:[{_id:new mongoose.Types.ObjectId(),userId,appType:'customer',refreshTokenHash:createHash('sha256').update(token).digest('hex'),revokedAt:null,isActive:true,expiresAt:new Date(Date.now()+600000)}]});
 const app=express();app.use(express.json());app.use(createMobileRouter({db,storage:require('../src/platform/media').mediaService({db,adapter:{async put({storageKey}){return {storageKey,storageProvider:'s3',publicUrl:'https://example.com/upload.jpg'}},async remove(){}}})}));app.use(errorHandler);
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const url='http://127.0.0.1:'+server.address().port+'/customer',headers={authorization:'Bearer '+token,'content-type':'application/json'};
 try{
 let uploaded=await fetch(url+'/profile/photo',{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'image/jpeg','x-file-name':'profile.jpg'},body:Buffer.from([255,216,255,0])});assert.equal(uploaded.status,201,await uploaded.text());
 let r=await fetch(url+'/profile',{method:'PATCH',headers,body:JSON.stringify({fullName:'Updated Customer',profileImageId:String(photoId)})});assert.equal(r.status,200,await r.text());
 r=await fetch(url+'/profile',{headers});assert.equal((await r.json()).data.user.profileImageUrl,'https://example.com/customer.jpg');
 r=await fetch(url+'/profile',{method:'PATCH',headers,body:JSON.stringify({fullName:'Updated Customer',profileImageId:String(otherPhotoId)})});assert.equal(r.status,404);
 r=await fetch(url+'/bookings/'+bookingId,{headers});assert.equal(r.status,200);assert.deepEqual((await r.json()).data.worker,{fullName:'Beauty Expert',photoUrl:'https://example.com/worker.jpg'});
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r))}
});
