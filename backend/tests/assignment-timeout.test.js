const test = require('node:test'), assert = require('node:assert/strict'), mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { expireAssignments } = require('../src/jobs/assignmentTimeout.job')
test('assignment expiry is restart-safe and never removes a newer assignment', async () => {
  const bookingId = new mongoose.Types.ObjectId(), assignmentId = new mongoose.Types.ObjectId(), now = new Date()
  const db = memoryDatabase({ bookings: [{ _id: bookingId, assignmentId, status: 'assigned', assignmentStatus: 'offered', workerId: new mongoose.Types.ObjectId() }], booking_assignments: [{ _id: assignmentId, bookingId, status: 'offered', expiresAt: new Date(now.getTime() - 1000) }] })
  assert.equal(await expireAssignments({ db, now }), 1)
  assert.equal(db.records().bookings[0].assignmentStatus, 'searching')
  assert.equal(db.records().bookings[0].workerId, null)
  assert.equal(await expireAssignments({ db, now }), 0)
  assert.equal(db.records().booking_events.length, 1)
  const oldId = new mongoose.Types.ObjectId(), newerId = new mongoose.Types.ObjectId()
  db.records().booking_assignments.push({ _id: oldId, bookingId, status: 'offered', expiresAt: new Date(now.getTime() - 1000) })
  Object.assign(db.records().bookings[0], { assignmentId: newerId, status: 'assigned', assignmentStatus: 'accepted' })
  await expireAssignments({ db, now })
  assert.equal(String(db.records().bookings[0].assignmentId), String(newerId))
  assert.equal(db.records().bookings[0].assignmentStatus, 'accepted')
})
test('assignment expiry offers the booking to the next online eligible worker', async () => {
  const now = new Date(), bookingId = new mongoose.Types.ObjectId()
  const oldAssignmentId = new mongoose.Types.ObjectId()
  const serviceId = new mongoose.Types.ObjectId(), areaId = new mongoose.Types.ObjectId()
  const workerId = new mongoose.Types.ObjectId(), userId = new mongoose.Types.ObjectId()
  const startsAt = new Date(now.getTime() + 60 * 60 * 1000)
  const booking = {
    _id: bookingId,
    assignmentId: oldAssignmentId,
    status: 'assigned',
    assignmentStatus: 'offered',
    workerId: new mongoose.Types.ObjectId(),
    items: [{ serviceId }],
    serviceAreaId: areaId,
    startsAt,
    endsAt: new Date(startsAt.getTime() + 30 * 60 * 1000),
    assignmentTimeoutMinutes: 5,
  }
  const db = memoryDatabase({
    bookings: [booking],
    booking_assignments: [{
      _id: oldAssignmentId,
      bookingId,
      status: 'offered',
      expiresAt: new Date(now.getTime() - 1000),
    }],
    workers: [{
      _id: workerId,
      userId,
      status: 'approved',
      isActive: true,
      isOnline: true,
      serviceIds: [serviceId],
      serviceAreaIds: [areaId],
      compensationRule: { amountPaise: 2500, effectiveFrom: new Date(0) },
    }],
    users: [{ _id: userId, userType: 'worker', status: 'active', isActive: true }],
  })
  assert.equal(await expireAssignments({ db, now, legacyWorkerOffersEnabled: true }), 1)
  assert.equal(db.records().bookings[0].assignmentStatus, 'offered')
  assert.equal(String(db.records().bookings[0].workerId), String(workerId))
  assert.equal(db.records().booking_assignments.length, 2)
})
