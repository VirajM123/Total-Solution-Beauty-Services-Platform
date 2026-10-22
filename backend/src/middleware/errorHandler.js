const { ZodError } = require('zod')
const logger = require('../config/logger')

class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message)
    this.name = 'HttpError'
    this.status = status
    this.code = code
    this.details = details
  }
}

function notFound(req, res) {
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'The requested endpoint was not found.' },
    requestId: req.id,
  })
}

function errorHandler(error, req, res, next) {
  if (res.headersSent) {
    next(error)
    return
  }

  let status = 500
  let code = 'INTERNAL_SERVER_ERROR'
  let message = 'An unexpected error occurred.'
  let details

  if (error instanceof HttpError) {
    status = error.status
    code = error.code
    message = error.message
    details = error.details
  } else if (error instanceof ZodError) {
    status = 400
    code = 'VALIDATION_ERROR'
    message = 'Request validation failed.'
    details = error.issues.map(issue => ({ field: issue.path.join('.'), message: issue.message }))
  } else if (error.type === 'entity.too.large') {
    status = 413
    code = 'PAYLOAD_TOO_LARGE'
    message = 'Request body exceeds the configured size limit.'
  } else if (error.type === 'entity.parse.failed') {
    status = 400
    code = 'INVALID_JSON'
    message = 'Request body must contain valid JSON.'
  } else if (error.code === 11000) {
    status = 409; code = 'DUPLICATE_RESOURCE'; message = 'This operation conflicts with an existing record or idempotency key.'
  } else if (error.code === 121) {
    status = 400; code = 'DATABASE_VALIDATION_ERROR'; message = 'Record does not match the existing database validator. Review the field contract.'
  } else if (error.code === 'ECONNREFUSED' || error.name === 'MongooseError') {
    status = 503
    code = 'SERVICE_UNAVAILABLE'
    message = 'The requested service is temporarily unavailable.'
  }

  if (status >= 500) {
    logger.error({ requestId: req.id, errorName: error.name, errorCode: error.code }, 'Request failed')
  }

  res.status(status).json({
    success: false,
    error: { code, message, ...(details ? { details } : {}) },
    requestId: req.id,
  })
}

module.exports = { HttpError, notFound, errorHandler }
