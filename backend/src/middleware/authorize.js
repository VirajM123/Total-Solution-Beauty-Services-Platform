const { HttpError } = require('./errorHandler')

function requireSameOrigin(req, res, next) {
  const origin = req.get('origin')
  const allowedOrigins = require('../config/env').CORS_ORIGINS
  if (!origin || !allowedOrigins.includes(origin)) {
    next(new HttpError(403, 'CSRF_REJECTED', 'A trusted browser origin is required.'))
    return
  }
  next()
}

module.exports = { requireSameOrigin }