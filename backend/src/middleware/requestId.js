const { randomUUID } = require('node:crypto')

module.exports = function requestId(req, res, next) {
  const provided = req.get('x-request-id')
  req.id = provided && /^[\w.-]{1,80}$/.test(provided) ? provided : randomUUID()
  res.setHeader('X-Request-Id', req.id)
  next()
}
