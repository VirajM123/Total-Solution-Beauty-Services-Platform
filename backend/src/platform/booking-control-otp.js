const { randomInt } = require('node:crypto')
const argon2 = require('argon2')
const mongoose = require('mongoose')
const { id, fail, atomic, compareAndSet, requireRecord } = require('./core')
const { notify } = require('./business')

function createBookingControlOtp({ db, ttlSeconds = 600, maxAttempts = 5, clock = () => new Date() }) {
 if (!Number.isInteger(ttlSeconds) || ttlSeconds < 60 || ttlSeconds > 1800) throw Error('Invalid booking control OTP expiry policy.')
 if (!Number.isInteger(maxAttempts) || maxAttempts < 1 || maxAttempts > 10) throw Error('Invalid booking control OTP attempt policy.')

 async function issue({ bookingId, purpose, req }) {
  const code = String(randomInt(100000, 1000000))
  const otpHash = await argon2.hash(code, { type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1 })
  const challengeId = new mongoose.Types.ObjectId()
  const now = clock()
  const result = await atomic(db, req, 'booking.' + purpose + '.otp_issue', 'booking_control_otps', async session => {
   const booking = await requireRecord(db, 'bookings', bookingId, session)
   if (booking.status !== 'in_progress' || !booking.workerUserId) fail(409, 'INVALID_TRANSITION', 'An active worker booking is required.')
   if (purpose === 'duration_extension' && (booking.serviceFinishedAt || !['pending', 'approved'].includes(booking.durationExtension?.status) || booking.durationExtension?.adminOtpVerifiedAt)) {
    fail(409, 'EXTENSION_NOT_DUE', 'An unresolved duration extension without an admin OTP is required.')
   }
   if (purpose === 'service_completion' && (!booking.serviceFinishedAt || booking.paymentStatus !== 'paid')) {
    fail(409, 'PAYMENT_PENDING', 'Verified payment is required before issuing the completion OTP.')
   }
   await db.collection('booking_control_otps').updateMany(
    { bookingId: booking._id, purpose, status: 'active', isActive: true },
    { $set: { status: 'revoked', isActive: false, revokedAt: now } },
    { session },
   )
   const challenge = {
    _id: challengeId,
    bookingId: booking._id,
    workerUserId: booking.workerUserId,
    assignmentId: booking.assignmentId,
    purpose,
    otpHash,
    attemptCount: 0,
    maxAttempts,
    createdAt: now,
    expiresAt: new Date(+now + ttlSeconds * 1000),
    issuedBy: req.auth.user._id,
    status: 'active',
    isActive: true,
   }
   await db.collection('booking_control_otps').insertOne(challenge, { session })
   await notify(db, session, booking.workerUserId, 'booking.' + purpose + '_otp_issued', booking._id, String(challengeId))
   return { _id: challengeId, bookingId: booking._id, expiresAt: challenge.expiresAt }
  })
  return { ...result, purpose, otp: code }
 }

 async function verify({ booking, bookingId, workerUserId, purpose, code, session }) {
  if (String(booking.workerUserId) !== String(workerUserId)) return false
  const challenge = await db.collection('booking_control_otps').findOne({
   bookingId: id(bookingId),
   workerUserId: id(workerUserId),
   assignmentId: booking.assignmentId,
   purpose,
   status: 'active',
   isActive: true,
  }, { session })
  if (!challenge || challenge.consumedAt) return false
  const now = clock()
  let valid = false
  let status = 'active'
  if (!(challenge.expiresAt instanceof Date) || challenge.expiresAt <= now) status = 'expired'
  else if (challenge.attemptCount >= challenge.maxAttempts) status = 'locked'
  else valid = typeof code === 'string' && /^\d{6}$/.test(code) && await argon2.verify(challenge.otpHash, code)
  const attempts = challenge.attemptCount + Number(status === 'active')
  if (valid) status = 'consumed'
  else if (attempts >= challenge.maxAttempts && status === 'active') status = 'locked'
  await compareAndSet(db, 'booking_control_otps', challenge, {
   attemptCount: attempts,
   status,
   isActive: status === 'active',
   ...(valid ? { consumedAt: now, verifiedAt: now } : {}),
  }, session)
  return valid ? challenge : false
 }

 return { issue, verify }
}

module.exports = { createBookingControlOtp }
