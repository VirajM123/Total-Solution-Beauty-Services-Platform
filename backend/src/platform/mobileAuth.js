const express=require('express')
const { randomInt,randomBytes,createHash }=require('node:crypto')
const argon2=require('argon2')
const { rateLimit }=require('express-rate-limit')
const {z}=require('zod')
const {id,fail,handler,reply,atomic}=require('./core')
const hash=value=>createHash('sha256').update(value).digest('hex')
function mobileAuth({db}){
 const forApp=app=>(req,res,next)=>Promise.resolve().then(async()=>{
  const token=req.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1]
  if(!token)fail(401,'UNAUTHENTICATED','Mobile sign-in is required.')
  const session=await db.collection('auth_sessions').findOne({refreshTokenHash:hash(token),appType:app,revokedAt:null,isActive:true,expiresAt:{$gt:new Date()}})
  if(!session)fail(401,'UNAUTHENTICATED','Session expired.')
  const user=await db.collection('users').findOne({_id:session.userId,userType:app,isActive:true,status:'active'},{projection:{passwordHash:0}})
  if(!user)fail(401,'UNAUTHENTICATED','Account is inactive.')
  req.auth={user,session};req.actorType=app;next()
 }).catch(next)
 return {forApp}
}
function createMobileAuthRouter({db,sms}){
 const router=express.Router()
 router.use(rateLimit({windowMs:15*60*1000,limit:10,standardHeaders:'draft-8',legacyHeaders:false}))
 router.post('/otp/request',handler(async(req,res)=>{
  if(!sms)fail(503,'SMS_NOT_CONFIGURED','Mobile verification provider is not configured.')
  const input=z.object({mobileNumber:z.string().regex(/^\+[1-9]\d{7,14}$/),appType:z.enum(['customer','worker'])}).strict().parse(req.body)
  const code=String(randomInt(100000,1000000))
  const record={_id:new(require('mongoose').Types.ObjectId)(),...input,purpose:'login',otpHash:await argon2.hash(code,{type:argon2.argon2id}),
   attempts:0,expiresAt:new Date(Date.now()+5*60000),createdAt:new Date(),isActive:true,consumedAt:null}
  await db.collection('otp_challenges').insertOne(record)
  try{await sms.send({mobileNumber:input.mobileNumber,code,purpose:'login'})}
  catch{await db.collection('otp_challenges').updateOne({_id:record._id},{$set:{isActive:false}});fail(503,'SMS_UNAVAILABLE','Verification message could not be sent.')}
  reply(req,res,{challengeId:record._id,expiresInSeconds:300},201)
 }))
 router.post('/otp/verify',handler(async(req,res)=>{
  if(!sms)fail(503,'SMS_NOT_CONFIGURED','Mobile verification provider is not configured.')
  const input=z.object({challengeId:z.string().regex(/^[a-f0-9]{24}$/i),code:z.string().regex(/^\d{6}$/),
   fullName:z.string().trim().min(2).max(120)}).strict().parse(req.body)
  const challenge=await db.collection('otp_challenges').findOneAndUpdate(
   {_id:id(input.challengeId),purpose:'login',isActive:true,consumedAt:null,attempts:{$lt:5},expiresAt:{$gt:new Date()}},
   {$inc:{attempts:1}},{returnDocument:'after'})
  if(!challenge||!await argon2.verify(challenge.otpHash,input.code))fail(401,'INVALID_OTP','Verification code is invalid or expired.')
  const token=randomBytes(32).toString('base64url')
  const reqForAudit={...req,auth:{user:{_id:challenge._id}},actorType:challenge.appType,body:{}}
  const result=await atomic(db,reqForAudit,'mobile.login','auth_sessions',async session=>{
   const consumed=await db.collection('otp_challenges').updateOne({_id:challenge._id,consumedAt:null,isActive:true},{$set:{consumedAt:new Date(),isActive:false}},{session})
   if(consumed.modifiedCount!==1)fail(409,'OTP_CONSUMED','Verification code has already been used.')
   let user=await db.collection('users').findOne({mobileNumber:challenge.mobileNumber},{session})
   if(user&&(user.userType!==challenge.appType||user.isActive!==true||user.status!=='active'))fail(403,'ACCOUNT_UNAVAILABLE','This identity cannot sign in to this app.')
   if(!user){
    user={_id:new(require('mongoose').Types.ObjectId)(),fullName:input.fullName,mobileNumber:challenge.mobileNumber,userType:challenge.appType,
     authProvider:'mobile_otp',mobileVerifiedAt:new Date(),status:'active',isActive:true,createdAt:new Date(),schemaVersion:1}
    await db.collection('users').insertOne(user,{session})
    if(challenge.appType==='customer')await db.collection('customers').insertOne({_id:user._id,userId:user._id,fullName:user.fullName,status:'active',createdAt:new Date(),isActive:true,schemaVersion:1},{session})
   }
   reqForAudit.auth.user._id=user._id
   const record={_id:new(require('mongoose').Types.ObjectId)(),userId:user._id,appType:challenge.appType,refreshTokenHash:hash(token),issuedAt:new Date(),
    expiresAt:new Date(Date.now()+24*3600000),isActive:true,revokedAt:null}
   await db.collection('auth_sessions').insertOne(record,{session})
   return record
  })
  res.set('Cache-Control','no-store');reply(req,res,{accessToken:token,expiresAt:result.expiresAt,appType:challenge.appType})
 }))
 return router
}
module.exports={mobileAuth,createMobileAuthRouter}
