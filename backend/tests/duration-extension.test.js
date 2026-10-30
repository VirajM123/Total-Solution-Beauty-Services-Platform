const test = require('node:test')
const assert = require('node:assert/strict')
const mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { requestDueExtensions } = require('../src/jobs/durationExtension.job')

test('due bookings receive one zero-price 15-minute extension request', async () => {
  const now = new Date()
  const bookingId = new mongoose.Types.ObjectId()
  const customerId = new mongoose.Types.ObjectId()
  const workerUserId = new mongoose.Types.ObjectId()
  const db = memoryDatabase({
    bookings: [{
      _id: bookingId,
      customerId,
      workerUserId,
      status: 'in_progress',
      serviceEndsAt: new Date(now.getTime() - 1000),
    }],
  })

  assert.equal(await requestDueExtensions({ db, now }), 1)
  const extension = db.records().bookings[0].durationExtension
  assert.equal(extension.status, 'pending')
  assert.equal(extension.minutes, 15)
  assert.equal(extension.pricePaise, 0)
  assert.equal(extension.expiresAt.getTime(), now.getTime() + 5 * 60 * 1000)
  assert.equal(await requestDueExtensions({ db, now }), 0)
  assert.equal(db.records().booking_events.length, 1)
  assert.equal(db.records().notifications.length, 2)
})
