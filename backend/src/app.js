const express = require('express')
const helmet = require('helmet')
const pinoHttp = require('pino-http')
const env = require('./config/env')
const cors = require('./config/cors')
const logger = require('./config/logger')
const requestId = require('./middleware/requestId')
const { isDatabaseReady } = require('./config/database')
const { HttpError, notFound, errorHandler } = require('./middleware/errorHandler')

function unavailable(req, res, next) {
  next(new HttpError(503, 'API_NOT_CONFIGURED', 'Business APIs require a configured development database and Admin session secret.'))
}

function createApp(options = {}) {
  const app = express()
  const databaseReady = options.isDatabaseReady || isDatabaseReady
  const models = options.models
  const sessionSecret = options.sessionSecret === undefined ? env.SESSION_COOKIE_SECRET : options.sessionSecret
  const authConfigured = Boolean(models && sessionSecret && sessionSecret.length >= 32)
  const apiConfigured = options.apiEnabled === true
    || Boolean(models && env.ADMIN_CATALOG_API_ENABLED && env.MONGODB_URI && sessionSecret)

  app.use((req,res,next) => {
    if (req.url.startsWith('/api/v1/')) req.url = '/api/' + req.url.slice('/api/v1/'.length)
    next()
  })
  app.disable('x-powered-by')
  app.use(requestId)
  app.use(pinoHttp({
    logger,
    genReqId: req => req.id,
    customProps: req => ({ requestId: req.id }),
    serializers: {
      req(req) {
        return { id: req.id, method: req.method, url: req.url.split('?')[0] }
      },
      res(res) {
        return { statusCode: res.statusCode }
      },
    },
  }))
  app.use(helmet())
  app.use(cors)
  app.use(express.json({ limit: env.JSON_BODY_LIMIT, strict: true }))
  app.use(express.urlencoded({ extended: false, limit: env.JSON_BODY_LIMIT }))

  app.get('/health/live', (req, res) => {
    res.status(200).json({
      success: true,
      data: { status: 'live' },
      requestId: req.id,
    })
  })

  app.get('/health/ready', (req, res) => {
    const ready = databaseReady()
    res.status(ready ? 200 : 503).json({
      success: ready,
      data: { status: ready ? 'ready' : 'not_ready', database: ready ? 'connected' : 'disconnected' },
      requestId: req.id,
    })
  })

  app.use('/api', (req, res, next) => {
    if (!databaseReady()) return unavailable(req, res, next)
    next()
  })
  if (authConfigured) {
    const { createAdminAuthRouter } = require('./modules/auth/adminAuth.routes')
    app.use('/api/admin/auth', createAdminAuthRouter({ models, sessionSecret }))
  } else {
    app.use('/api/admin/auth', unavailable)
  }
  if ((env.ADMIN_OPERATIONS_API_ENABLED || options.operationsEnabled === true) && authConfigured) {
    const db = options.db || require('mongoose').connection.db
    if (db) {
      const { createAuthentication } = require('./middleware/authenticate')
      const auth = createAuthentication({ ...models, secret: sessionSecret })
      const { createPlatformRouter } = require('./platform')
      app.use('/api', createPlatformRouter({ db: require('./platform/database').moneyDatabase(db), models, auth, storageAdapter: options.storageAdapter,
        sms: options.sms, scheduling: options.scheduling, compensation: options.compensation, serviceOtp: options.serviceOtp }))
    }
  }
  if (apiConfigured && authConfigured) {
    const { createAuthentication } = require('./middleware/authenticate')
    const { createCatalogRouters } = require('./modules/services/catalog.routes')
    const { createMediaRouter, createMediaStorage } = require('./modules/media/media.routes')
    const auth = createAuthentication({
      User: models.User,
      Role: models.Role,
      AuthSession: models.AuthSession,
      secret: sessionSecret,
    })
    const mediaStorage = createMediaStorage(options.mediaStorageAdapter)
    const catalog = createCatalogRouters({
      models,
      auth,
      storageConfigured: mediaStorage.isConfigured,
    })

    app.use('/api/admin/categories', catalog.adminCategories)
    app.use('/api/admin/services', catalog.adminServices)
    app.use('/api/admin/media', createMediaRouter({ auth, storage: mediaStorage }))
    app.use('/api/catalog', catalog.publicCatalog)
  } else {
    app.use('/api', unavailable)
  }

  app.use(notFound)
  app.use(errorHandler)
  return app
}

module.exports = { createApp }
