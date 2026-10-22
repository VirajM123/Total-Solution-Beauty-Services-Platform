const cors = require('cors')
const env = require('./env')

module.exports = cors({
  origin(origin, callback) {
    if (!origin || env.CORS_ORIGINS.includes(origin)) {
      callback(null, true)
      return
    }
    callback(null, false)
  },
  credentials: true,
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'X-CSRF-Token', 'X-Idempotency-Key', 'X-File-Name', 'X-Media-Visibility'],
  exposedHeaders: ['X-Request-Id'],
  maxAge: 600,
})
