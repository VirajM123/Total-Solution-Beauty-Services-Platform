const http = require('node:http')
const env = require('./config/env')
const logger = require('./config/logger')
const { connectDatabase } = require('./config/database')
const { createApp } = require('./app')
const models = require('./models')

async function startServer() {
  let server, realtime, stopAssignmentJob, stopDispatchJob, stopDurationExtensionJob, stopNotificationJob
  try {
    await connectDatabase()
    if (env.ADMIN_OPERATIONS_API_ENABLED && env.NODE_ENV === 'development' && env.MONGODB_DB_NAME === 'hii_beauty_dev') {
      await require('./platform/provision-booking-control-otps').provisionBookingControlOtps(require('mongoose').connection.db)
    }
    if (env.ADMIN_OPERATIONS_API_ENABLED) {
      await require('./platform/database').verifyExistingCollections(require('mongoose').connection.db)
    }
    const mongoose = require('mongoose')
    const storageAdapter = require('./platform/s3-storage').createS3StorageAdapter({
      region: env.AWS_REGION, bucket: env.S3_BUCKET, publicBaseUrl: env.S3_PUBLIC_BASE_URL,
    }) || (env.NODE_ENV === 'development'
        && env.SESSION_COOKIE_SECRET?.length >= 32
      ? require('./platform/mongo-storage').createMongoStorageAdapter({ db: mongoose.connection.db })
      : undefined)
    const pushProvider = require('./platform/push-notifications').createPushProvider({ enabled: env.FCM_ENABLED, projectId: env.FIREBASE_PROJECT_ID })
    if (pushProvider) {
      const existingPush = await require('mongoose').connection.db.listCollections().toArray()
      if (!['push_devices', 'push_deliveries', 'push_campaigns'].every(name => existingPush.some(item => item.name === name))) {
        throw Error('Push schema is missing. Run npm run provision:push before enabling FCM_ENABLED.')
      }
    }
    const sms = require('./platform/msg91-otp').createMsg91OtpProvider({
      authKey: env.MSG91_AUTH_KEY, widgetId: env.MSG91_WIDGET_ID, widgetToken: env.MSG91_WIDGET_TOKEN,
      enabled: env.MSG91_ENABLED && env.OTP_PROVIDER === 'msg91', timeoutMs: env.OTP_PROVIDER_TIMEOUT_MS,
    })
    server = http.createServer(createApp({
      sms,
      models,
      storageAdapter,
      legacyWorkerOffersEnabled: env.LEGACY_WORKER_OFFERS_ENABLED,
    }))
    await require('./platform/listen').listen(server, env.PORT)
    logger.info({ port: env.PORT, environment: env.NODE_ENV }, `Backend server is running at http://localhost:${env.PORT}`)
    if(env.ADMIN_OPERATIONS_API_ENABLED){
      stopAssignmentJob=require('./jobs/assignmentTimeout.job').startAssignmentTimeoutJob({db:mongoose.connection.db,logger,legacyWorkerOffersEnabled:env.LEGACY_WORKER_OFFERS_ENABLED})
      stopDurationExtensionJob=require('./jobs/durationExtension.job').startDurationExtensionJob({db:mongoose.connection.db,logger,storageAdapter})
    }
    if (env.ADMIN_OPERATIONS_API_ENABLED) stopNotificationJob = require('./jobs/notificationRetry.job').startNotificationRetryJob({ db: require('mongoose').connection.db, provider: pushProvider, logger })
    if (env.ADMIN_OPERATIONS_API_ENABLED && env.SESSION_COOKIE_SECRET) {
      realtime = require('./realtime/socketServer').attachRealtime(server, {
        db: require('mongoose').connection.db, models, sessionSecret: env.SESSION_COOKIE_SECRET, origins: env.CORS_ORIGINS,
      })
    }
    let shuttingDown = false

    const shutdown = signal => {
      if (shuttingDown) return
      shuttingDown = true
      logger.info({ signal }, 'Graceful shutdown started')

      const timeout = setTimeout(() => {
        logger.error('Graceful shutdown timed out')
        process.exitCode = 1
        server.closeAllConnections?.()
      }, env.SHUTDOWN_TIMEOUT_MS)
      timeout.unref()

      stopAssignmentJob?.()
      stopDurationExtensionJob?.()
      stopNotificationJob?.()
      if (realtime) realtime.disconnectSockets(true)
      server.close(async error => {
        if (error) {
          logger.error({ errorName: error.name }, 'HTTP server shutdown failed')
          process.exitCode = 1
        }
        try {
          const mongoose = require('mongoose')
          await mongoose.disconnect()
        } catch (disconnectError) {
          logger.error({ errorName: disconnectError.name }, 'MongoDB shutdown failed')
          process.exitCode = 1
        } finally {
          clearTimeout(timeout)
        }
      })
    }

    process.once('SIGTERM', () => shutdown('SIGTERM'))
    process.once('SIGINT', () => shutdown('SIGINT'))
    return server
  } catch (error) {
    stopAssignmentJob?.()
    stopDispatchJob?.()
    stopDurationExtensionJob?.()
      stopNotificationJob?.()
    if (realtime) await new Promise(resolve => realtime.close(resolve))
    if (server?.listening) await new Promise(resolve => server.close(resolve))
    await require('mongoose').disconnect()
    throw error
  }
}

if (require.main === module) {
  startServer().catch(error => {
    logger.fatal({ errorName: error.name, errorCode: error.code, port: env.PORT }, error.message)
    process.exitCode = 1
  })
}

module.exports = { startServer }
