const pino = require('pino')
const env = require('./env')

const logger = pino({
  level: process.env.LOG_LEVEL || (env.NODE_ENV === 'production' ? 'info' : 'debug'),
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'req.headers["set-cookie"]',
      'password',
      'token',
      'connectionString',
      'mongoUri',
      'MONGODB_URI',
      'SESSION_COOKIE_SECRET',
      'passwordHash',
      'refreshTokenHash',
      'csrfToken',
      'res.headers["set-cookie"]',
    ],
    censor: '[REDACTED]',
  },
})

module.exports = logger
