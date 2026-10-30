const express = require('express')
const { z } = require('zod')
const { definitions, safeProjection, permissions } = require('./definitions')
const { idSchema,id,fail,reply,handler,protectedRouter,list,atomic,requestIdentity,compareAndSet,requireRecord } = require('./core')
function convert(value, key='') {
  if (value === null) return value
  if (key.endsWith('Ids')) return value.map(id)
  if (key.endsWith('Id')) return id(value)
  if (['startsAt','endsAt'].includes(key)) return new Date(value)
  if (Array.isArray(value)) return value.map(v => convert(v))
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,convert(v,k)]))
  return value
}
async function validateRelationships(db, resource, input, session, storage) {
  const options={session}
  if(resource==='support'&&input.assignedAdminId){if(!await db.collection('users').findOne({_id:id(input.assignedAdminId),userType:/^admin$/i,status:/^active$/i,isActive:true},options))fail(400,'INVALID_ADMIN','Select an active Admin assignee.')}
  if (input.startsAt && input.endsAt && new Date(input.startsAt)>=new Date(input.endsAt)) fail(400,'VALIDATION_ERROR','End must follow start.')
  if (resource==='offers' && input.discountType==='percentage' && input.value>100) fail(400,'VALIDATION_ERROR','Percentage cannot exceed 100.')
  for(const [key,collection] of [['serviceIds','services'],['categoryIds','service_categories'],['packageIds','service_packages'],['serviceAreaIds','service_areas']]){
    if(!input[key])continue
    const ids=[...new Set(input[key].map(String))]
    if(await db.collection(collection).countDocuments({_id:{$in:ids.map(id)},isActive:{$ne:false}},{session})!==ids.length)fail(400,'INVALID_REFERENCE','One or more references are unavailable.')
  }
  if(input.components){
    const ids=[...new Set(input.components.map(c=>String(c.serviceId)))]
    if(ids.length!==input.components.length)fail(400,'DUPLICATE_COMPONENT','Use quantity instead of duplicate component services.')
    const services=await db.collection('services').find({_id:{$in:ids.map(id)},isActive:{$ne:false}},options).toArray()
    if(services.length!==ids.length || input.status==='published' && services.some(s=>s.status!=='published'))fail(400,'INVALID_COMPONENT','Package services must exist; published packages require published services.')
  }
  if(Boolean(input.targetId)!==Boolean(input.targetType))fail(400,'INVALID_TARGET','Set both target type and target ID, or neither.')
  if(input.targetId){
    const collection={service:'services',category:'service_categories',offer:'offers',package:'service_packages'}[input.targetType]
    const target=collection && await db.collection(collection).findOne({_id:id(input.targetId),isActive:{$ne:false}},options)
    if(!target || input.status==='published' && target.status!=='published')fail(400,'INVALID_TARGET','Select an eligible published target.')
  }
  const mediaIds=[...(input.imageMediaIds||[]),input.thumbnailMediaId].filter(Boolean)
  if(input.status==='published' && ['packages','banners'].includes(resource)){
    if(!storage?.isConfigured)fail(503,'STORAGE_NOT_CONFIGURED','Persistent media storage is required before publishing.')
    if(!input.thumbnailMediaId)fail(400,'MEDIA_REQUIRED','A persistent thumbnail is required.')
  }
  if(mediaIds.length){
    const found=await db.collection('media_assets').find({_id:{$in:[...new Set(mediaIds.map(String))].map(id)},visibility:'public',uploadStatus:'ready',isActive:true},options).toArray()
    const {isPersistentPublicImage}=require('../modules/services/catalog.routes')
    if(found.length!==new Set(mediaIds.map(String)).size || found.some(m=>!isPersistentPublicImage(m)))fail(400,'INVALID_MEDIA','Select ready persistent public images.')
  }
}
function createResourcesRouter({ db,auth,storage }) {
  const router=protectedRouter(auth)
  for(const [resource,definition] of Object.entries(definitions)){
    const base='/'+resource, collection=definition.collection
    const scope=req=>resource==='notifications'?{recipientUserId:req.auth.user._id}:{}
    router.get(base,auth.requirePermission(definition.permission+'.read'),handler(async(req,res)=>{
      const result=await list(db,collection,req.query,{projection:safeProjection,scope:scope(req),fields:['name','fullName','subject','code','roleCode']})
      if(resource==='customers'){
        const users=await db.collection('users').find({_id:{$in:result.items.map(item=>item.userId).filter(Boolean)}},{projection:{fullName:1,email:1,mobileNumber:1}}).toArray()
        result.items=result.items.map(item=>{const user=users.find(u=>String(u._id)===String(item.userId));return{...item,...(user?{fullName:user.fullName,email:user.email,mobileNumber:user.mobileNumber}:{})}})
      }
      reply(req,res,result)
    }))
    router.get(base+'/:id',auth.requirePermission(definition.permission+'.read'),handler(async(req,res)=>{
      const record=await db.collection(collection).findOne({_id:id(req.params.id),...scope(req)},{projection:safeProjection})
      if(!record)fail(404,'NOT_FOUND','Record was not found.')
      reply(req,res,record)
    }))
    if(definition.readOnly)continue
    const schema=z.object(definition.fields).strict()
    const guardRole=(req,before,input)=>{
      if(resource!=='roles')return
      if(!['SUPER_ADMIN','HII_BEAUTY_SUPER_ADMIN'].includes(req.auth.role.roleCode))fail(403,'FORBIDDEN','Only Super Admin may manage roles.')
      if(before?.isSystemRole || String(before?._id)===String(req.auth.user.roleId))fail(403,'PROTECTED_ROLE','System and current roles cannot be changed here.')
      if(input.permissions?.some(p=>!permissions.includes(p)))fail(400,'UNKNOWN_PERMISSION','Unknown permission code.')
    }
    if(definition.create!==false)router.post(base,auth.requirePermission(definition.permission+'.create'),handler(async(req,res)=>{
      const input=schema.parse(req.body);guardRole(req,null,input)
      const identity=requestIdentity(req,resource)
      const result=await atomic(db,req,resource+'.create',collection,async session=>{
        const previous=await db.collection(collection).findOne({_id:identity._id},{session})
        if(previous){if(previous.requestHash!==identity.requestHash)fail(409,'IDEMPOTENCY_CONFLICT','Key was already used with different fields.');return previous}
        const unique=resource==='roles'?{roleCode:input.roleCode}:resource==='offers'?{code:input.code}:resource==='settings'?{key:input.key}:resource==='service-areas'?{areaCode:input.areaCode}:{name:input.name}
        // A deterministic uniqueness guard in the existing audit collection serializes competing creates.
        const {createHash}=require('node:crypto')
        const guardId=id(createHash('sha256').update(collection+':unique:'+JSON.stringify(unique)).digest('hex').slice(0,24))
        if(await db.collection(collection).findOne(unique,{session}))fail(409,'DUPLICATE_RESOURCE','A record with this code or name exists.')
        await db.collection('audit_logs').insertOne({_id:guardId,action:'resource.unique',entityType:collection,createdAt:new Date(),isActive:true},{session})
        await validateRelationships(db,resource,input,session,storage)
        const now=new Date(),record={...convert(input),...(resource==='support'?{status:'open'}:{}),...identity,createdAt:now,updatedAt:now,createdBy:req.auth.user._id,isActive:input.status!=='archived',schemaVersion:1,_revision:0}
        await db.collection(collection).insertOne(record,{session});return record
      })
      reply(req,res,result,201)
    }))
    router.patch(base+'/:id',auth.requirePermission(definition.permission+'.update'),handler(async(req,res)=>{
      const input=schema.partial().refine(v=>Object.keys(v).length>0).parse(req.body)
      const result=await atomic(db,req,resource+'.update',collection,async session=>{
        const before=await requireRecord(db,collection,req.params.id,session,scope(req))
        guardRole(req,before,input)
        // Lifecycle changes have dedicated publication/archive permissions.
        if('status'in input && input.status!==before.status)fail(400,'USE_STATUS_ROUTE','Use the authorized status route.')
        if(['roles','offers','settings','service-areas'].includes(resource)){
          const field={roles:'roleCode',offers:'code',settings:'key','service-areas':'areaCode'}[resource]
          if(field in input && input[field]!==before[field])fail(400,'IMMUTABLE_CODE','Stable codes cannot be changed.')
        }
        await validateRelationships(db,resource,{...before,...input},session,storage)
        if (resource==='customers' && 'status' in input) {
          await db.collection('users').updateOne({_id:before.userId,userType:'customer'},{$set:{status:input.status,isActive:input.status==='active'}},{session})
          if(input.status!=='active')await db.collection('auth_sessions').updateMany({userId:before.userId},{$set:{isActive:false,revokedAt:new Date()}},{session})
        }
        if(resource==='customers' && before.userId) await db.collection('users').updateOne({_id:before.userId,userType:'customer'},{$set:{...(input.fullName?{fullName:input.fullName}:{}),...(input.email?{email:input.email}:{}),updatedAt:new Date()}},{session})
        return compareAndSet(db,collection,before,{...convert(input),updatedBy:req.auth.user._id},session)
      })
      reply(req,res,result)
    }))
    const statuses=definition.statusValues || (definition.fields.status?['draft','published','paused','archived']:null)
    if(statuses)router.patch(base+'/:id/status',handler(async(req,res)=>{
      const input=z.object({status:z.enum(statuses)}).strict().parse(req.body)
      const permission=definition.permission+(input.status==='archived'?'.archive':'.publish')
      if(!req.auth.role.permissions.includes(permission))fail(403,'FORBIDDEN','Your role cannot change this status.')
      const result=await atomic(db,req,resource+'.status',collection,async session=>{
        const before=await requireRecord(db,collection,req.params.id,session,scope(req))
        await validateRelationships(db,resource,{...before,...input},session,storage)
        if(resource==='customers' && before.userId){
          await db.collection('users').updateOne({_id:before.userId,userType:'customer'},{$set:{status:input.status,isActive:input.status==='active'}},{session})
          if(input.status!=='active')await db.collection('auth_sessions').updateMany({userId:before.userId},{$set:{isActive:false,revokedAt:new Date()}},{session})
        }
        return compareAndSet(db,collection,before,{status:input.status,isActive:!['archived','disabled','suspended'].includes(input.status)},session)
      });reply(req,res,result)
    }))
  }
  return router
}
function createPublicResourcesRouter({db,storage}){
  const router=express.Router()
  router.get('/service-areas',handler(async(req,res)=>{
    const {q}=require('./core').listFilter(req.query,['name'])
    const where={status:'active',isActive:true,isServiceable:true}
    const records=await db.collection('service_areas').find(where,{projection:{_id:1,name:1,city:1,state:1,postalCodes:1}}).sort({_id:1}).skip((q.page-1)*q.limit).limit(q.limit).toArray()
    reply(req,res,{items:records,pagination:{page:q.page,limit:q.limit,hasMore:records.length===q.limit}})
  }))
  for(const [resource,definition] of Object.entries(definitions).filter(([,d])=>d.public)){
    router.get('/'+resource,handler(async(req,res)=>{
      const {q,filter}=require('./core').listFilter(req.query,['name'])
      const now=new Date(),where={$and:[filter,{status:'published',isActive:true}]}
      if(['offers','banners'].includes(resource))where.$and.push({startsAt:{$lte:now},endsAt:{$gt:now}})
      const records=await db.collection(definition.collection).find(where).sort({displayOrder:1,_id:1}).skip((q.page-1)*q.limit).limit(q.limit).toArray()
      const items=[]
      for(const record of records){
        try {
          await validateRelationships(db,resource,record,undefined,storage)
          const fields=['_id',...Object.keys(definition.fields)]
          const item=Object.fromEntries(fields.filter(k=>k in record).map(k=>[k,record[k]]))
          const mediaIds=[record.thumbnailMediaId,...(record.imageMediaIds||[])].filter(Boolean)
          const assets=mediaIds.length?await db.collection('media_assets').find({_id:{$in:mediaIds},visibility:'public',isActive:true,uploadStatus:'ready'}).toArray():[]
          const safe=assets.filter(require('../modules/services/catalog.routes').isPersistentPublicImage)
          item.thumbnail=safe.find(asset=>String(asset._id)===String(record.thumbnailMediaId))?.publicUrl||null
          item.images=safe.map(asset=>({id:asset._id,url:asset.publicUrl,mimeType:asset.mimeType,altText:asset.altText||record.name}))
          items.push(item)
        }catch(error){if(!['INVALID_COMPONENT','INVALID_TARGET','INVALID_MEDIA','STORAGE_NOT_CONFIGURED','MEDIA_REQUIRED','INVALID_REFERENCE'].includes(error.code))throw error}
      }
      // Cursor scan has a bounded page; filtered stale records are never exposed.
      reply(req,res,{items,pagination:{page:q.page,limit:q.limit,hasMore:records.length===q.limit}})
    }))
  }
  return router
}
module.exports={createResourcesRouter,createPublicResourcesRouter,validateRelationships,convert}
