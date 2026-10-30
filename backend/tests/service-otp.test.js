const test = require('node:test')
const assert = require('node:assert/strict')
const mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { createServiceOtp } = require('../src/platform/service-otp')

function fixture(options = {}) {
  const objectId = () => new mongoose.Types.ObjectId()
  const customerId = objectId()
  const workerId = objectId()
  const bookingId = objectId()
  const assignmentId = objectId()
  const booking = {
    _id: bookingId,
    customerId,
    workerId,
    workerUserId: workerId,
    assignmentId,
    status: 'confirmed',
    assignmentStatus: 'accepted',
    isActive: true,
  }
  const db = memoryDatabase({
    bookings: [booking],
    workers: [{ _id: workerId, userId: workerId, status: 'approved', isActive: true }],
    users: [{ _id: workerId, status: 'active', isActive: true }],
    booking_assignments: [{
      _id: assignmentId,
      bookingId,
      workerId,
      workerUserId: workerId,
      status: 'accepted',
    }],
  })
  const req = {
    id: 'service-otp-test',
    auth: { user: { _id: customerId }, role: { roleCode: 'CUSTOMER' } },
    body: {},
  }
  return {
    booking,
    bookingId,
    customerId,
    workerId,
    db,
    req,
    serviceOtp: createServiceOtp({ db, ...options }),
  }
}

test('booking OTP is generated and hashed by the backend, then revealed only to its owner', async () => {
  const f = fixture()
  const session = f.db.transactionClient.startSession()
  await session.withTransaction(() =>
    f.serviceOtp.createForBooking({ booking: f.booking, session }),
  )

  const initialChallenge = f.db.records().service_otp_challenges[0]
  assert.match(initialChallenge.otpHash, /^\$argon2id\$/)
  assert.equal(initialChallenge.otp, undefined)
  assert.equal(initialChallenge.purpose, 'service_start')
  assert.equal(f.booking.serviceOtpIssueCount, 1)

  const revealed = await f.serviceOtp.reveal({
    bookingId: f.bookingId,
    customerId: f.customerId,
    req: f.req,
  })
  assert.match(revealed.otp, /^\d{6}$/)
  assert.equal(revealed.delivery, 'authenticated_owner_reveal')
  assert.equal(initialChallenge.status, 'revoked')
  assert.equal((await f.serviceOtp.availability(f.booking)).status, 'available')
})

test('only the assigned worker can consume a revealed code, and attempts are limited', async () => {
  const f = fixture({ maxAttempts: 2 })
  const session = f.db.transactionClient.startSession()
  await session.withTransaction(() =>
    f.serviceOtp.createForBooking({ booking: f.booking, session }),
  )
  const revealed = await f.serviceOtp.reveal({
    bookingId: f.bookingId,
    customerId: f.customerId,
    req: f.req,
  })
  f.booking.status = 'arrived'

  const wrongWorker = await f.serviceOtp.verify({
    booking: f.booking,
    workerUserId: new mongoose.Types.ObjectId(),
    code: revealed.otp,
    session,
    req: f.req,
  })
  assert.equal(wrongWorker, false)

  const badCode = revealed.otp === '000000' ? '000001' : '000000'
  assert.equal(await f.serviceOtp.verify({
    booking: f.booking,
    workerUserId: f.workerId,
    code: badCode,
    session,
    req: f.req,
  }), false)
  assert.equal(await f.serviceOtp.verify({
    booking: f.booking,
    workerUserId: f.workerId,
    code: badCode,
    session,
    req: f.req,
  }), false)
  const challenges = f.db.records().service_otp_challenges
  assert.equal(challenges[challenges.length - 1].status, 'locked')
  assert.equal(await f.serviceOtp.verify({
    booking: f.booking,
    workerUserId: f.workerId,
    code: revealed.otp,
    session,
    req: f.req,
  }), false)
})

test('owner reveal rejects other customers and expired challenges', async () => {
  const f = fixture({ ttlSeconds: 1 })
  const session = f.db.transactionClient.startSession()
  await session.withTransaction(() =>
    f.serviceOtp.createForBooking({ booking: f.booking, session }),
  )
  await assert.rejects(() => f.serviceOtp.reveal({
    bookingId: f.bookingId,
    customerId: new mongoose.Types.ObjectId(),
    req: f.req,
  }), error => error.code === 'NOT_FOUND')

  const revealed = await f.serviceOtp.reveal({
    bookingId: f.bookingId,
    customerId: f.customerId,
    req: f.req,
  })
  f.booking.status = 'arrived'
  const challenges = f.db.records().service_otp_challenges
  const challenge = challenges[challenges.length - 1]
  challenge.codeExpiresAt = new Date(Date.now() - 1)
  assert.equal(await f.serviceOtp.verify({
    booking: f.booking,
    workerUserId: f.workerId,
    code: revealed.otp,
    session,
    req: f.req,
  }), false)
  assert.equal(challenge.status, 'expired')
})
