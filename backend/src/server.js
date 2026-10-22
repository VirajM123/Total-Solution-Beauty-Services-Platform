const http = require('node:http')
const env = require('./config/env')
const logger = require('./config/logger')
const { connectDatabase } = require('./config/database')
const { createApp } = require('./app')
const models = require('./models')

async function startServer() {
  await connectDatabase()
  if (env.ADMIN_OPERATIONS_API_ENABLED) {
    await require('./platform/database').verifyExistingCollections(require('mongoose').connection.db)
  }
  const server = http.createServer(createApp({ models }))
  let stopAssignmentJob
  if(env.ADMIN_OPERATIONS_API_ENABLED){
    const mongoose=require('mongoose')
    stopAssignmentJob=require('./jobs/assignmentTimeout.job').startAssignmentTimeoutJob({db:mongoose.connection.db,logger})
  }
  let realtime
  if (env.ADMIN_OPERATIONS_API_ENABLED && env.SESSION_COOKIE_SECRET) {
    realtime = require('./realtime/socketServer').attachRealtime(server, {
      db: require('mongoose').connection.db, models, sessionSecret: env.SESSION_COOKIE_SECRET, origins: env.CORS_ORIGINS,
    })
  }
  let shuttingDown = false

  server.listen(env.PORT, () => {
    logger.info({ port: env.PORT, environment: env.NODE_ENV }, 'Backend server listening')
  })

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
}

if (require.main === module) {
  startServer().catch(error => {
    logger.fatal({ errorName: error.name }, 'Backend startup failed')
    process.exitCode = 1
  })
}

module.exports = { startServer }
