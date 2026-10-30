const express=require('express')
const {createResourcesRouter,createPublicResourcesRouter}=require('./resources.routes')
const {createWorkflowsRouter}=require('./workflows.routes')
const {createReportsRouter}=require('./reports.routes')
const {mediaService,createMediaRouter}=require('./media')
const {createMobileAuthRouter}=require('./mobileAuth')
const {createAdminOperationsRouter,createScheduling,createCompensation}=require('./admin-operations')
const {createMobileRouter}=require('./mobile.routes')
const {createServiceOtp}=require('./service-otp')
const {createBookingControlOtp}=require('./booking-control-otp')
function createPlatformRouter(options){
 const router=express.Router()
 const storage=mediaService({db:options.db,adapter:options.storageAdapter})
 const scheduling=options.scheduling||createScheduling(options)
 const dependencies={...options,storage,scheduling,compensation:options.compensation||createCompensation(),
  serviceOtp:options.serviceOtp||createServiceOtp({db:options.db}),
  controlOtp:options.controlOtp||createBookingControlOtp({db:options.db})}
 router.use('/admin',require('./payment-recovery').createPaymentRecoveryRouter(dependencies))
 router.use('/admin',require('./push-campaigns').createPushCampaignRouter(dependencies))
 router.use('/admin',require('./push-notifications').createAdminNotificationRouter(dependencies))
 router.use('/admin/media-v2',createMediaRouter(dependencies))
 router.use('/admin',require('./allocation.routes').createAllocationRouter(dependencies))
 router.use('/admin',createAdminOperationsRouter(dependencies),createResourcesRouter(dependencies),createWorkflowsRouter(dependencies),createReportsRouter(dependencies))
 router.use('/catalog',createPublicResourcesRouter(dependencies))
 router.use('/mobile/auth',createMobileAuthRouter({...dependencies,otpLength:require('../config/env').OTP_LENGTH,otpExpirySeconds:require('../config/env').OTP_EXPIRY_SECONDS,resendCooldownSeconds:require('../config/env').OTP_RESEND_COOLDOWN_SECONDS,maxAttempts:require('../config/env').OTP_MAX_ATTEMPTS}))
 router.use('/mobile',createMobileRouter(dependencies))
 return router
}
module.exports={createPlatformRouter}
