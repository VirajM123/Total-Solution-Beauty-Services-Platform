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
