const mongoose=require('mongoose')
const {fail}=require('./core')
// Raw driver writes must encode financial values as BSON Long, matching integer validators.
function encodeMoney(value,key=''){
 if(value==null)return value
 if(key.endsWith('Paise')&&(typeof value==='number'||typeof value==='bigint')){
  if(typeof value==='number'&&(!Number.isSafeInteger(value)||value<0))fail(400,'INVALID_MONEY','Invalid monetary value.')
  return mongoose.mongo.Long.fromString(String(value))
 }
 if(value instanceof Date||Buffer.isBuffer(value)||value._bsontype)return value
 if(Array.isArray(value))return value.map(v=>encodeMoney(v))
 if(typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encodeMoney(v,k)]))
 return value
}
function moneyDatabase(db){
 return new Proxy(db,{get(target,key){
  if(key==='collection')return name=>{
   const collection=target.collection(name)
   return new Proxy(collection,{get(c,method){
    const value=c[method];if(typeof value!=='function')return value
    if(['insertOne','insertMany','updateOne','updateMany','replaceOne','findOneAndUpdate'].includes(method)){
      return(...args)=>value.apply(c,args.map((arg,i)=>i<(['insertOne','insertMany'].includes(method)?1:2)?encodeMoney(arg):arg))
    }
    return value.bind(c)
   }})
  }
  const value=target[key];return typeof value==='function'?value.bind(target):value
 }})
}
async function verifyExistingCollections(db){
 if(db.databaseName!=='hii_beauty_dev')fail(503,'WRONG_DATABASE','Only the approved development database is allowed.')
 const required=['users','roles','auth_sessions','audit_logs','service_categories','services','media_assets','service_areas',
  ...Object.values(require('./models')).map(m=>m.collection.name)]
 const collections=await db.listCollections().toArray()
 for(const name of new Set(required)){
  const collection=collections.find(c=>c.name===name)
  if(!collection)fail(503,'SCHEMA_REVIEW_REQUIRED','An expected existing collection is unavailable.')
  if(collection.options?.validationLevel!=='strict'||collection.options?.validationAction!=='error'||!collection.options?.validator?.$jsonSchema)fail(503,'SCHEMA_REVIEW_REQUIRED','Existing strict collection validation must be reviewed before activation.')
 }
 return true
}
module.exports={encodeMoney,moneyDatabase,verifyExistingCollections}
