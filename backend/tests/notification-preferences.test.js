const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const mongoose = require('mongoose')
const { createHash } = require('node:crypto')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { createMobileRouter } = require('../src/platform/mobile.routes')
const { errorHandler } = require('../src/middleware/errorHandler')

test('notification preferences persist only for the authenticated customer and require provisioning', async () => {
  const userId = new mongoose.Types.ObjectId(), otherId = new mongoose.Types.ObjectId()
  const token = 'p'.repeat(43)
  const db = memoryDatabase({
    users: [{ _id: userId, userType: 'customer', isActive: true, status: 'active' }],
    auth_sessions: [{ _id: new mongoose.Types.ObjectId(), userId, appType: 'customer', refreshTokenHash: createHash('sha256').update(token).digest('hex'), revokedAt: null, isActive: true, expiresAt: new Date(Date.now() + 600000) }],
  })
  let provisioned = true
  db.listCollections = () => ({ async toArray() { return provisioned ? [{ name: 'notification_preferences' }] : [] } })
  const app = express(); app.use(express.json()); app.use(createMobileRouter({ db })); app.use(errorHandler)
  const server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve))
  const url = 'http://127.0.0.1:' + server.address().port + '/customer/notification-preferences'
  const headers = { authorization: 'Bearer ' + token, 'content-type': 'application/json' }
  const body = { notificationsEnabled: true, marketingNotificationsEnabled: false }
  try {
    let response = await fetch(url, { method: 'PATCH', headers, body: JSON.stringify(body) })
    assert.equal(response.status, 200, await response.text())
    response = await fetch(url, { headers })
    assert.deepEqual((await response.json()).data, body)
    assert.equal(String(db.records().notification_preferences[0]._id), String(userId))
    response = await fetch(url, { method: 'PATCH', headers, body: JSON.stringify({ ...body, userId: String(otherId) }) })
    assert.equal(response.status, 400)
    provisioned = false
    response = await fetch(url, { method: 'PATCH', headers, body: JSON.stringify(body) })
    assert.equal(response.status, 503)
    assert.equal(db.records().notification_preferences.length, 1)
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)) }
})
