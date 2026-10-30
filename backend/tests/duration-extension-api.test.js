const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const http = require('node:http')
const mongoose = require('mongoose')
const { createHash } = require('node:crypto')
const { errorHandler } = require('../src/middleware/errorHandler')
const { createMobileRouter } = require('../src/platform/mobile.routes')
const { memoryDatabase } = require('./admin-test-db.cjs')

test('customer extension approval is idempotent, updates server end time, and adds no charge', async () => {
  const customerId = new mongoose.Types.ObjectId()
  const bookingId = new mongoose.Types.ObjectId()
  const extensionId = new mongoose.Types.ObjectId()
  const token = 'c'.repeat(43)
  const now = new Date()
  const db = memoryDatabase({
    users: [{ _id: customerId, userType: 'customer', status: 'active', isActive: true }],
    auth_sessions: [{
      _id: new mongoose.Types.ObjectId(),
      userId: customerId,
      appType: 'customer',
      refreshTokenHash: createHash('sha256').update(token).digest('hex'),
      revokedAt: null,
      isActive: true,
      expiresAt: new Date(now.getTime() + 60000),
    }],
    bookings: [{
      _id: bookingId,
      customerId,
      status: 'in_progress',
      totalPaise: 12000,
      serviceEndsAt: new Date(now.getTime() - 1000),
      durationExtension: {
        id: extensionId,
        status: 'pending',
        minutes: 15,
        pricePaise: 0,
        requestedAt: new Date(now.getTime() - 10000),
        expiresAt: new Date(now.getTime() + 300000),
      },
    }],
  })
  const app = express()
  app.use(express.json())
  app.use(createMobileRouter({ db }))
  app.use(errorHandler)
  const server = http.createServer(app)
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  const base = `http://127.0.0.1:${server.address().port}`

  try {
    const url = `${base}/customer/bookings/${bookingId}/duration-extensions/${extensionId}/respond`
    const headers = {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'x-idempotency-key': 'extension-approve-test-001',
    }
    const request = () => fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ decision: 'approve' }),
    })
    const approved = await request()
    assert.equal(approved.status, 200)
    const result = (await approved.json()).data
    assert.equal(result.durationExtension.status, 'approved')
    assert.equal(result.durationExtension.pricePaise, 0)
    assert.equal(result.serviceEndsAt, result.durationExtension.extendedEndsAt)
    assert.equal(db.records().bookings[0].totalPaise, 12000)
    assert.equal((await request()).status, 200)
    assert.equal(db.records().booking_events.length, 1)

    const conflict = await fetch(url, {
      method: 'POST',
      headers: { ...headers, 'x-idempotency-key': 'extension-decline-test-001' },
      body: JSON.stringify({ decision: 'decline' }),
    })
    assert.equal(conflict.status, 409)
  } finally {
    server.closeAllConnections()
    await new Promise(resolve => server.close(resolve))
  }
})
