const express=require('express')
const {createResourcesRouter,createPublicResourcesRouter}=require('./resources.routes')
const {createWorkflowsRouter}=require('./workflows.routes')
const {createReportsRouter}=require('./reports.routes')
const {mediaService,createMediaRouter}=require('./media')
const {createMobileAuthRouter}=require('./mobileAuth')
const {createAdminOperationsRouter,createScheduling,createCompensation}=require('./admin-operations')
const {createMobileRouter}=require('./mobile.routes')
function createPlatformRouter(options){
 const router=express.Router()
 const storage=mediaService({db:options.db,adapter:options.storageAdapter})
 const dependencies={...options,storage}
 router.use('/admin/media-v2',createMediaRouter(dependencies))
 router.use('/admin',createAdminOperationsRouter(dependencies),createResourcesRouter(dependencies),createWorkflowsRouter({...dependencies,scheduling:options.scheduling||createScheduling(options),compensation:options.compensation||createCompensation()}),createReportsRouter(dependencies))
 router.use('/catalog',createPublicResourcesRouter(dependencies))
 router.use('/mobile/auth',createMobileAuthRouter(dependencies))
 router.use('/mobile',createMobileRouter(dependencies))
 return router
}
module.exports={createPlatformRouter}
