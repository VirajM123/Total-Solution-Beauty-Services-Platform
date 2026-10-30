const { randomInt } = require('node:crypto')
const argon2 = require('argon2')
const mongoose = require('mongoose')
const { id, fail, atomic, compareAndSet, requireRecord } = require('./core')

function createServiceOtp({
  db,
  ttlSeconds = 300,
  maxAttempts = 5,
  cooldownSeconds = 60,
  maxIssues = 10,
  clock = () => new Date(),
}) {
  for (const [value, min, max] of [
    [ttlSeconds, 1, 900],
    [maxAttempts, 1, 10],
    [cooldownSeconds, 1, 300],
    [maxIssues, 1, 20],
  ]) {
    if (!Number.isInteger(value) || value < min || value > max) {
      throw new Error('Invalid service OTP security policy.')
    }
  }

  async function assignmentFor(booking, session) {
    const assignment = booking.assignmentId && await db.collection('booking_assignments').findOne({
      _id: booking.assignmentId,
      bookingId: booking._id,
      workerId: booking.workerId,
      workerUserId: booking.workerUserId,
      status: { $in: ['accepted', 'assigned'] },
    }, { session })
    const worker = await db.collection('workers').findOne({
      _id: booking.workerId,
      userId: booking.workerUserId,
      status: 'approved',
      isActive: true,
    }, { session })
    const user = worker && await db.collection('users').findOne({
      _id: worker.userId,
      isActive: true,
      status: 'active',
    }, { session })
    if (!assignment || !worker || !user || !['accepted', 'assigned'].includes(booking.assignmentStatus)) {
      fail(409, 'ASSIGNMENT_UNAVAILABLE', 'An active approved assignment is required.')
    }
    return { worker }
  }

  async function makeHash() {
    const code = String(randomInt(100000, 1000000))
    return {
      code,
      otpHash: await argon2.hash(code, {
        type: argon2.argon2id,
        memoryCost: 65536,
        timeCost: 3,
        parallelism: 1,
      }),
    }
  }

  return {
    configured: true,

    async createForBooking({ booking, session }) {
      const { otpHash } = await makeHash()
      const now = clock()
      const challengeId = new mongoose.Types.ObjectId()
      const record = {
        _id: challengeId,
        bookingId: booking._id,
        customerId: booking.customerId,
        purpose: 'service_start',
        schemaVersion: 3,
        authorizationVersion: 0,
        otpHash,
        attemptCount: 0,
        maxAttempts,
        createdAt: now,
        codeExpiresAt: new Date(+now + ttlSeconds * 1000),
        status: 'active',
        isActive: true,
      }
      await db.collection('service_otp_challenges').insertOne(record, { session })
      Object.assign(booking, {
        serviceOtpChallengeId: challengeId,
        serviceOtpAuthorizationVersion: 0,
        serviceOtpIssueCount: 1,
      })
      return { challengeId, expiresAt: record.codeExpiresAt }
    },

    async availability(booking) {
      const revealPath = `/api/mobile/customer/bookings/${booking._id}/service-otp/reveal`
      if (!['confirmed', 'assigned', 'travelling', 'arrived'].includes(booking.status) ||
          booking.isActive === false) {
        return {
          status: ['completed', 'in_progress'].includes(booking.status) ? 'consumed' : 'unavailable',
          revealAllowed: false,
        }
      }

      const challenge = booking.serviceOtpChallengeId && await db.collection('service_otp_challenges').findOne({
        _id: booking.serviceOtpChallengeId,
        bookingId: booking._id,
      })
      const expiresAt = challenge?.codeExpiresAt || challenge?.expiresAt
      const locked = challenge?.status === 'locked' && expiresAt > clock()
      return {
        status: locked
          ? 'locked'
          : challenge?.isActive && expiresAt > clock()
            ? 'available'
            : 'regeneration_required',
        revealAllowed: !locked &&
          !(booking.serviceOtpNextIssueAt > clock()) &&
          (booking.serviceOtpIssueCount || 0) < maxIssues,
        ...(booking.serviceOtpNextIssueAt
          ? { nextRevealAt: booking.serviceOtpNextIssueAt }
          : {}),
        ...(expiresAt ? { expiresAt } : {}),
        revealPath,
      }
    },

    async reveal({ bookingId, customerId, req }) {
      await requireRecord(db, 'bookings', bookingId, undefined, {
        customerId: id(customerId),
        isActive: true,
      })
      const { code, otpHash } = await makeHash()
      const challengeId = new mongoose.Types.ObjectId()
      const result = await atomic(db, req, 'service.otp_reveal', 'service_otp_challenges', async session => {
        const booking = await requireRecord(db, 'bookings', bookingId, session, {
          customerId: id(customerId),
          isActive: true,
        })
        if (!['confirmed', 'assigned', 'travelling', 'arrived'].includes(booking.status)) {
          fail(409, 'INVALID_TRANSITION', 'Service OTP cannot be revealed in this booking state.')
        }
        const now = clock()
        if (booking.serviceOtpNextIssueAt > now) {
          fail(429, 'SERVICE_OTP_COOLDOWN', 'Wait before requesting a replacement service OTP.')
        }
        if ((booking.serviceOtpIssueCount || 0) >= maxIssues) {
          fail(429, 'SERVICE_OTP_ISSUE_LIMIT', 'Service OTP issue limit reached; contact support.')
        }
        const previous = booking.serviceOtpChallengeId &&
          await db.collection('service_otp_challenges').findOne({
            _id: booking.serviceOtpChallengeId,
          }, { session })
        if (previous?.status === 'locked' &&
            (previous.codeExpiresAt || previous.expiresAt) > now) {
          fail(423, 'SERVICE_OTP_LOCKED', 'OTP is locked until its validity window expires.')
        }
        if (previous?.isActive) {
          await compareAndSet(db, 'service_otp_challenges', previous, {
            status: 'revoked',
            isActive: false,
            revokedAt: now,
          }, session)
        }
        const record = {
          _id: challengeId,
          bookingId: booking._id,
          customerId: booking.customerId,
          purpose: 'service_start',
          schemaVersion: 3,
          authorizationVersion: booking.serviceOtpAuthorizationVersion || 0,
          otpHash,
          attemptCount: 0,
          maxAttempts,
          createdAt: now,
          codeExpiresAt: new Date(+now + ttlSeconds * 1000),
          status: 'active',
          isActive: true,
        }
        await db.collection('service_otp_challenges').insertOne(record, { session })
        await compareAndSet(db, 'bookings', booking, {
          serviceOtpChallengeId: challengeId,
          serviceOtpIssueCount: (booking.serviceOtpIssueCount || 0) + 1,
          serviceOtpNextIssueAt: new Date(+now + cooldownSeconds * 1000),
        }, session)
        return record
      })
      return {
        bookingId: result.bookingId,
        challengeId: result._id,
        otp: code,
        expiresAt: result.codeExpiresAt,
        delivery: 'authenticated_owner_reveal',
      }
    },

    async verify({ booking, workerUserId, code, session, req }) {
      const now = clock()
      if (booking.status !== 'arrived' ||
          String(booking.workerUserId) !== String(workerUserId)) return false
      const { worker } = await assignmentFor(booking, session)
      await compareAndSet(db, 'workers', worker, { lastServiceOtpCheckAt: now }, session)
      const challenge = booking.serviceOtpChallengeId &&
        await db.collection('service_otp_challenges').findOne({
          _id: booking.serviceOtpChallengeId,
          bookingId: booking._id,
          purpose: 'service_start',
          status: 'active',
          isActive: true,
        }, { session })
      if (!challenge || challenge.consumedAt) return false
      if (challenge.schemaVersion >= 3) {
        if (String(challenge.customerId) !== String(booking.customerId) ||
            challenge.authorizationVersion !== (booking.serviceOtpAuthorizationVersion || 0)) {
          return false
        }
      } else if (String(challenge.assignmentId) !== String(booking.assignmentId) ||
          String(challenge.workerUserId) !== String(booking.workerUserId)) {
        return false
      }

      let valid = false
      let status = 'active'
      const deadline = challenge.codeExpiresAt || challenge.expiresAt
      if (!(deadline instanceof Date) || deadline <= now) {
        status = 'expired'
      } else if (challenge.attemptCount >= challenge.maxAttempts) {
        status = 'locked'
      } else {
        valid = typeof code === 'string' &&
          /^\d{6}$/.test(code) &&
          await argon2.verify(challenge.otpHash, code)
      }
      const attempts = challenge.attemptCount + Number(status === 'active')
      if (valid) status = 'consumed'
      else if (attempts >= challenge.maxAttempts && status === 'active') status = 'locked'
      await compareAndSet(db, 'service_otp_challenges', challenge, {
        attemptCount: attempts,
        status,
        isActive: status === 'active',
        ...(valid ? { consumedAt: now, verifiedAt: now } : {}),
      }, session)
      await db.collection('audit_logs').insertOne({
        action: 'service.otp_verify',
        actorUserId: id(workerUserId),
        actorRole: 'worker',
        entityType: 'service_otp_challenges',
        entityId: challenge._id,
        requestId: req.id,
        result: valid ? 'success' : 'failure',
        createdAt: now,
        isActive: true,
      }, { session })
      return valid
    },
  }
}

module.exports = { createServiceOtp }
