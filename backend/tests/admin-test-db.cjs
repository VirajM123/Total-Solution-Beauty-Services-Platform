const mongoose=require('mongoose')
function same(a,b){return a?._bsontype==='ObjectId'||b?._bsontype==='ObjectId'?String(a)===String(b):a===b}
function matches(record,filter){
 return Object.entries(filter).every(([key,value])=>{
  if(key==='$and')return value.every(v=>matches(record,v))
  if(key==='$or')return value.some(v=>matches(record,v))
  const actual=record[key]
  if(value instanceof RegExp)return value.test(String(actual||''))
  if(value&&typeof value==='object'&&!value._bsontype&&!(value instanceof Date)){
   return Object.entries(value).every(([operator,expected])=>{
    if(operator==='$in')return Array.isArray(actual)?actual.some(a=>expected.some(e=>same(a,e))):expected.some(e=>same(actual,e))
    if(operator==='$ne')return !same(actual,expected)
    if(operator==='$nin')return !expected.some(e=>same(actual,e))
    if(operator==='$exists')return (actual!==undefined)===expected
    if(operator==='$gt')return actual>expected
    if(operator==='$gte')return actual>=expected
    if(operator==='$lt')return actual<expected
    if(operator==='$lte')return actual<=expected
    return false
   })
  }
  if(Array.isArray(actual))return actual.some(a=>same(a,value))
  return same(actual,value)
 })
}
function memoryDatabase(seed={}){
 let records={...seed}
 const rows=name=>records[name]||(records[name]=[])
 const update=(record,change)=>{
  Object.assign(record,change.$set||{})
  for(const [key,value]of Object.entries(change.$inc||{}))record[key]=(record[key]||0)+value
  return record
 }
 const db={
  transactionClient:{startSession(){return{
   async withTransaction(run){
    const previous=mongoose.mongo.BSON.deserialize(mongoose.mongo.BSON.serialize(records))
    try{await run()}catch(error){records=previous;throw error}
   },async endSession(){},
  }}},
  collection(name){return{
   find(filter={}){
    let data=rows(name).filter(row=>matches(row,filter))
    return{sort(){return this},skip(n){data=data.slice(n);return this},limit(n){data=data.slice(0,n);return this},
     project(){return this},async toArray(){return data}}
   },
   async findOne(filter){return rows(name).find(row=>matches(row,filter))||null},
   async countDocuments(filter){return rows(name).filter(row=>matches(row,filter)).length},
   async insertOne(record){
    if (!record._id) record._id=new mongoose.Types.ObjectId()
    if(rows(name).some(row=>same(row._id,record._id)))throw Object.assign(Error('Duplicate'),{code:11000})
    rows(name).push(record);return{insertedId:record._id}
   },
   async findOneAndUpdate(filter,change){
    const row=rows(name).find(record=>matches(record,filter));return row?update(row,change):null
   },
   async updateOne(filter,change,options={}){
    const row=rows(name).find(record=>matches(record,filter))
    if(row){update(row,change);return{modifiedCount:1}}
    if(options.upsert){rows(name).push({...filter,...change.$set,...change.$setOnInsert});return{modifiedCount:0,upsertedCount:1}}
    return{modifiedCount:0}
   },
   async updateMany(filter,change){for(const row of rows(name).filter(r=>matches(r,filter)))update(row,change)},
  }},
  records:()=>records,
 }
 return db
}

module.exports={memoryDatabase}
