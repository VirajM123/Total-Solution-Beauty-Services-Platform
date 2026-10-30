const express=require('express')
const { randomUUID }=require('node:crypto')
const { z }=require('zod')
const { fail,id,reply,handler,protectedRouter,atomic,requireRecord }=require('./core')
function fileType(bytes){
 if(bytes.length>=8 && bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))return'image/png'
 if(bytes.length>=3 && bytes[0]===255 && bytes[1]===216 && bytes[2]===255)return'image/jpeg'
 if(bytes.length>=12 && bytes.toString('ascii',0,4)==='RIFF' && bytes.toString('ascii',8,12)==='WEBP')return'image/webp'
 if(bytes.length>=5 && bytes.toString('ascii',0,5)==='%PDF-')return'application/pdf'
 return null
}
function validateFile(bytes,mime,visibility){
 if(!Buffer.isBuffer(bytes)||!bytes.length||bytes.length>5*1024*1024)fail(400,'INVALID_FILE','File must contain 1 byte to 5 MB.')
 if(!['public','private'].includes(visibility))fail(400,'INVALID_VISIBILITY','Visibility must be public or private.')
 if(fileType(bytes)!==mime || (mime==='application/pdf'&&visibility!=='private'))fail(400,'INVALID_FILE_SIGNATURE','File signature and allowed MIME type must agree. PDF files must remain private.')
 return true
}
function mediaService({db,adapter}){
 return {
  isConfigured:Boolean(adapter),
  async upload(req){
   if(!adapter)fail(503,'STORAGE_NOT_CONFIGURED','No persistent storage provider is approved/configured.')
   const mime=req.get('content-type')?.split(';')[0], visibility=req.get('x-media-visibility')||'public'
   validateFile(req.body,mime,visibility)
   const storageKey=visibility+'/'+randomUUID()
   const uploaded=await adapter.put({bytes:req.body,mimeType:mime,visibility,storageKey})
   if(uploaded.storageKey!==storageKey || !['s3','r2','cloudinary'].includes(uploaded.storageProvider)
     || visibility==='public'&&!/^https:\/\//i.test(uploaded.publicUrl||'')
     || visibility==='private'&&uploaded.publicUrl)fail(502,'INVALID_STORAGE_RESULT','Storage provider returned invalid metadata.')
   const record={_id:new (require('mongoose').Types.ObjectId)(),storageKey,storageProvider:uploaded.storageProvider,
     visibility,mimeType:mime,fileSizeBytes:req.body.length,fileName:z.string().max(150).parse(req.get('x-file-name')||'upload'),
     uploadedBy:req.auth.user._id,uploadStatus:'ready',isActive:true,createdAt:new Date(),updatedAt:new Date(),schemaVersion:1}
   if(visibility==='public')record.publicUrl=uploaded.publicUrl
   try{return await atomic(db,{...req,body:{}},'media.upload','media_assets',async session=>{
     await db.collection('media_assets').insertOne(record,{session});return record
   })}catch(error){
     // Provider must implement cleanup. An orphan never becomes a published DB reference.
     try{await adapter.remove({storageKey})}catch{/* Cleanup requires operator retry; do not disclose private key. */}
     throw error
   }
  },
  async uploadProductEvidence(req,bookingId,worker){
   if(!adapter)fail(503,'STORAGE_NOT_CONFIGURED','Persistent private photo storage is not configured.')
   const mime=req.get('content-type')?.split(';')[0]
   if(!['image/jpeg','image/png','image/webp'].includes(mime))fail(400,'INVALID_EVIDENCE_TYPE','Use a JPEG, PNG, or WebP product photo.')
   validateFile(req.body,mime,'private')
   let fileName
   try{fileName=decodeURIComponent(req.get('x-file-name')||'product-photo')}catch{fail(400,'INVALID_FILE_NAME','File name is not valid URL-encoded text.')}
   fileName=z.string().min(1).max(150).regex(/^[^\x00-\x1f\x7f]+$/).parse(fileName)
   const {createHash,randomUUID}=require('node:crypto')
   const workerUserId=req.auth.user._id,now=new Date(),hash=createHash('sha256').update(req.body).digest('hex')
   const storageKey='private/'+randomUUID()
   const uploaded=await adapter.put({bytes:req.body,mimeType:mime,visibility:'private',storageKey})
   const developmentStorage=require('../config/env').NODE_ENV==='development'&&uploaded.storageProvider==='mongodb'&&require('./mongo-storage').isDevelopmentMedia(uploaded)
   if(uploaded.storageKey!==storageKey||!['s3','r2','cloudinary'].includes(uploaded.storageProvider)&&!developmentStorage||uploaded.publicUrl){
    try{await adapter.remove({storageKey})}catch(cleanupError){req.log?.error({errorName:cleanupError.name},'Failed to remove invalid product evidence upload')}
    fail(502,'INVALID_STORAGE_RESULT','Storage provider returned invalid private metadata.')
   }
   const mediaId=new (require('mongoose').Types.ObjectId)()
   const record={_id:mediaId,storageKey,storageProvider:uploaded.storageProvider,visibility:'private',mimeType:mime,fileSizeBytes:req.body.length,fileName,
    uploadedBy:workerUserId,bookingId:id(bookingId),workerId:worker._id,usage:'product_evidence',contentHash:hash,
    retentionExpiresAt:new Date(+now+90*24*60*60*1000),uploadStatus:'ready',isActive:true,createdAt:now,updatedAt:now,schemaVersion:1}
   const originalBody=req.body
   req.body={bookingId:String(bookingId),mimeType:mime,fileSizeBytes:originalBody.length,contentHash:hash}
   try{
    const result=await atomic(db,req,'booking.product_evidence.upload','media_assets',async session=>{
     const booking=await requireRecord(db,'bookings',bookingId,session,{workerUserId,status:'arrived',isActive:true})
     const assignment=await db.collection('booking_assignments').findOne({_id:booking.assignmentId,bookingId:booking._id,workerId:worker._id,workerUserId,status:{$in:['assigned','accepted']}},{session})
     if(!assignment)fail(409,'ASSIGNMENT_UNAVAILABLE','Only the currently assigned worker can upload evidence.')
     const count=await db.collection('media_assets').countDocuments({bookingId:booking._id,usage:'product_evidence',isActive:true,uploadStatus:'ready'},{session})
     if(count>=3)fail(409,'EVIDENCE_LIMIT_REACHED','A booking can have at most 3 product photos.')
     const previous=await db.collection('media_assets').findOne({bookingId:booking._id,usage:'product_evidence',contentHash:hash,isActive:true},{session})
     if(previous)return previous
     await db.collection('media_assets').insertOne(record,{session})
     await require('./core').compareAndSet(db,'bookings',booking,{productEvidenceIds:[...(booking.productEvidenceIds||[]),mediaId]},session)
     await db.collection('booking_events').insertOne({bookingId:booking._id,type:'product_evidence_uploaded',workerId:worker._id,actorUserId:workerUserId,mediaAssetId:mediaId,createdAt:now},{session})
     return record
    })
    if(String(result._id)!==String(mediaId))await adapter.remove({storageKey})
    return {_id:result._id,bookingId:result.bookingId,fileName:result.fileName,mimeType:result.mimeType,fileSizeBytes:result.fileSizeBytes,uploadedAt:result.createdAt,workerId:result.workerId}
   }catch(error){
    try{await adapter.remove({storageKey})}catch(cleanupError){req.log?.error({errorName:cleanupError.name},'Failed to remove unlinked product evidence upload')}
    throw error
   }finally{req.body=originalBody}
  },
  async productEvidenceLink(req,bookingId,evidenceId,customer=false){
   if(!adapter?.signedRead)fail(503,'STORAGE_NOT_CONFIGURED','Private photo access is not configured.')
   const booking=await requireRecord(db,'bookings',bookingId,undefined,customer?{customerId:req.auth.user._id}:{})
   const evidence=await requireRecord(db,'media_assets',evidenceId,undefined,{bookingId:booking._id,usage:'product_evidence',visibility:'private',uploadStatus:'ready',isActive:true})
   if(evidence.retentionExpiresAt&&evidence.retentionExpiresAt<=new Date())fail(404,'NOT_FOUND','Product evidence was not found.')
   const isCustomer=customer&&String(booking.customerId)===String(req.auth.user._id)
   const isWorker=String(booking.workerUserId)===String(req.auth.user._id)&&String(evidence.uploadedBy)===String(req.auth.user._id)
   const isAdmin=req.auth.role?.permissions?.includes('bookings.read')
   if(!isCustomer&&!isWorker&&!isAdmin)fail(404,'NOT_FOUND','Product evidence was not found.')
   return {url:await adapter.signedRead({storageKey:evidence.storageKey,expiresInSeconds:60}),expiresInSeconds:60}
  },
  async privateLink(req,resourceId){
   if(!adapter?.signedRead)fail(503,'STORAGE_NOT_CONFIGURED','Private document access is not configured.')
   const record=await requireRecord(db,'media_assets',resourceId,undefined,{visibility:'private',isActive:true})
   const own=String(record.uploadedBy)===String(req.auth.user._id)
   if(!own && !req.auth.role?.permissions.includes('workers.documents.read'))fail(404,'NOT_FOUND','Document was not found.')
   return {url:await adapter.signedRead({storageKey:record.storageKey,expiresInSeconds:60}),expiresInSeconds:60}
  },
 }
}
function createMediaRouter({db,auth,storage}){
 const router=protectedRouter(auth)
 router.get('/',auth.requirePermission('catalog.media.upload'),handler(async(req,res)=>reply(req,res,await require('./core').list(db,'media_assets',req.query,{fields:['fileName'],projection:{storageKey:0},scope:{visibility:'public',isActive:true}}))))
 router.post('/uploads',auth.requirePermission('catalog.media.upload'),
   express.raw({type:['image/jpeg','image/png','image/webp','application/pdf'],limit:'5mb'}),
   handler(async(req,res)=>reply(req,res,await storage.upload(req),201)))
 router.get('/:id/private-link',handler(async(req,res)=>{
   res.set('Cache-Control','no-store');reply(req,res,await storage.privateLink(req,req.params.id))
 }))
 router.patch('/:id/archive',auth.requirePermission('catalog.media.upload'),handler(async(req,res)=>{
   const result=await atomic(db,req,'media.archive','media_assets',async session=>{
    const record=await requireRecord(db,'media_assets',req.params.id,session)
    for(const name of ['services','service_categories','service_packages','offers','promotional_banners','worker_documents']){
      if(await db.collection(name).findOne({$or:[{thumbnailMediaId:record._id},{imageMediaIds:record._id},{mediaAssetId:record._id}]},{session}))fail(409,'MEDIA_IN_USE','Replace references before archiving media.')
    }
    return require('./core').compareAndSet(db,'media_assets',record,{isActive:false},session)
   });reply(req,res,result)
 }))
 return router
}
module.exports={fileType,validateFile,mediaService,createMediaRouter}
