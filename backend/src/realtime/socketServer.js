const {Server}=require('socket.io')
const {createAuthentication}=require('../middleware/authenticate')
const {mobileAuth}=require('../platform/mobileAuth')
function attachRealtime(server,{db,models,sessionSecret,origins}){
 const io=new Server(server,{cors:{origin:origins,credentials:true},allowRequest(req,callback){callback(null,origins.includes(req.headers.origin))}})
 const adminAuth=createAuthentication({...models,secret:sessionSecret})
 async function authenticate(socket){
  const app=socket.handshake.auth?.appType
  const req={get:name=>socket.request.headers[name.toLowerCase()],ip:socket.request.socket.remoteAddress}
  const run=middleware=>new Promise((resolve,reject)=>middleware(req,{},error=>error?reject(error):resolve()))
  if(app==='admin'){
   await run(adminAuth.requireAuthenticated)
   req.get=name=>name.toLowerCase()==='x-csrf-token'?socket.handshake.auth.csrfToken:socket.request.headers[name.toLowerCase()]
   await run(adminAuth.requireCsrf)
   if(!req.auth.role.permissions.includes('notifications.read'))throw Error('Forbidden')
  }else if(['customer','worker'].includes(app)){
   req.get=name=>name.toLowerCase()==='authorization'?'Bearer '+socket.handshake.auth.token:undefined
   await run(mobileAuth({db}).forApp(app))
  }else throw Error('Invalid app')
  return req.auth
 }
 io.use((socket,next)=>authenticate(socket).then(auth=>{socket.data.userId=auth.user._id;next()}).catch(()=>next(Error('Authentication required'))))
 io.on('connection',socket=>{
  // No client-controlled room subscriptions and no private global broadcasts.
  let since=new Date(),busy=false
  const timer=setInterval(async()=>{
   if(busy)return;busy=true
   try{
    const auth=await authenticate(socket)
    const cutoff=new Date()
    const events=await db.collection('notifications').find({recipientUserId:auth.user._id,createdAt:{$gte:since,$lt:cutoff}},{projection:{type:1,entityId:1,createdAt:1}}).sort({createdAt:1}).limit(100).toArray()
    if(events.length)socket.emit('notifications.changed',{events:require('../platform/core').serialize(events),refetch:true})
    // If the bounded batch fills, retain the cursor; clients deduplicate by notification ID.
    since=events.length===100?events[events.length-1].createdAt:cutoff
   }catch{socket.disconnect(true)}finally{busy=false}
  },5000)
  timer.unref()
  socket.on('disconnect',()=>clearInterval(timer))
 })
 return io
}
module.exports={attachRealtime}
