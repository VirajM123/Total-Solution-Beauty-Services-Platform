const express = require('express')
const { randomBytes, createHash } = require('node:crypto')
const mongoose = require('mongoose')
const { rateLimit } = require('express-rate-limit')
const { z } = require('zod')
const logger = require('../config/logger')
const { id, fail, handler, reply, atomic } = require('./core')
const { normalizeIndianMobile } = require('./msg91-otp')

const hash = value => createHash('sha256').update(value).digest('hex')
const maxResends = 3
const providerFailureCategories = [
  'timeout',
  'network_error',
  'invalid_response',
  'configuration',
  'authentication',
  'insufficient_balance',
  'widget_inactive',
  'messaging_configuration',
  'rate_limited',
  'invalid_request',
  'otp_rejected',
  'provider_server_error',
  'provider_rejected',
]
const categoryByProviderCode = {
  MSG91_TIMEOUT: 'timeout',
  MSG91_NETWORK_ERROR: 'network_error',
  MSG91_INVALID_RESPONSE: 'invalid_response',
  MSG91_AUTH_FAILED: 'authentication',
  MSG91_SEND_FAILED: 'provider_rejected',
  MSG91_INVALID_OTP: 'otp_rejected',
  MSG91_REJECTED: 'provider_rejected',
  OTP_CONFIGURATION_MISSING: 'configuration',
}

function mobileAuth({db}){
 const forApp=app=>(req,res,next)=>Promise.resolve().then(async()=>{
  const token=req.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1]
  if(!token)fail(401,'UNAUTHENTICATED','Mobile sign-in is required.')
  const session=await db.collection('auth_sessions').findOne({refreshTokenHash:hash(token),appType:app,revokedAt:null,isActive:true,expiresAt:{$gt:new Date()}})
  if(!session)fail(401,'UNAUTHENTICATED','Session expired.')
  const user=await db.collection('users').findOne({_id:session.userId,userType:app,isActive:true,status:'active'},{projection:{passwordHash:0}})
  if(!user)fail(401,'UNAUTHENTICATED','Account is inactive.')
  req.auth={user,session};req.actorType=app;next()
 }).catch(next)
 return {forApp}
}
function createMobileAuthRouter({
  db,
  sms,
  otpLength = 6,
  otpExpirySeconds = 900,
  resendCooldownSeconds = 30,
  maxAttempts = 5,
}) {
  const router = express.Router()
  router.use(rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler(req, res) {
      res.status(429).json({
        success: false,
        error: { code: 'OTP_RATE_LIMITED', message: 'Too many verification requests. Try again later.' },
        requestId: req.id,
      })
    },
  }))

  const expiryMs = otpExpirySeconds * 1000
  const challengeRetentionMs = 24 * 60 * 60 * 1000
  const cooldownMs = resendCooldownSeconds * 1000
  const challengeExpiry = challenge => new Date(Math.min(
    +new Date(challenge.createdAt) + expiryMs,
    +new Date(challenge.expiresAt),
  ))
  const providerReady = () => Boolean(
    sms
      && typeof sms.send === 'function'
      && typeof sms.verify === 'function'
      && typeof sms.resend === 'function'
      && sms.configured !== false,
  )
  function requireProvider() {
    if (!providerReady()) fail(503, 'OTP_CONFIGURATION_MISSING', 'Mobile verification is not configured.')
  }
  function setPrivate(res) {
    res.set('Cache-Control', 'no-store')
    res.set('Pragma', 'no-cache')
  }
  function logProviderFailure(req, operation, error) {
    const providerCode = typeof error?.code === 'string' && /^[A-Z][A-Z0-9_]{0,63}$/.test(error.code)
      ? error.code
      : 'MSG91_UNKNOWN_ERROR'
    const category = providerFailureCategories.includes(error?.failureCategory)
      ? error.failureCategory
      : categoryByProviderCode[providerCode] || 'unknown'
    logger.warn({
      requestId: req.id,
      operation,
      providerCode,
      providerHttpStatus: Number.isInteger(error?.providerHttpStatus)
        && error.providerHttpStatus >= 100
        && error.providerHttpStatus <= 599
        ? error.providerHttpStatus
        : undefined,
      providerErrorCode: typeof error?.providerErrorCode === 'string'
        && /^(?:[A-Z][A-Z0-9_-]{0,31}|\d{1,6})$/.test(error.providerErrorCode)
        ? error.providerErrorCode
        : undefined,
      failureCategory: category,
    }, 'MSG91 mobile OTP operation failed')
  }
  function providerFailure(req, operation, error) {
    logProviderFailure(req, operation, error)
    if (error?.code === 'OTP_CONFIGURATION_MISSING') {
      fail(503, 'OTP_CONFIGURATION_MISSING', 'Mobile verification is not configured.')
    }
    if (error?.code === 'MSG91_INVALID_OTP') return false
    if (error?.code === 'MSG91_TIMEOUT' || error?.code === 'MSG91_NETWORK_ERROR' || error?.code === 'MSG91_AUTH_FAILED') {
      fail(503, 'OTP_PROVIDER_UNAVAILABLE', 'Mobile verification is temporarily unavailable.')
    }
    fail(502,
      operation === 'verify' ? 'OTP_VERIFICATION_FAILED' : 'OTP_SEND_FAILED',
      operation === 'verify'
        ? 'Verification could not be completed. Please retry.'
        : 'Verification message could not be sent.')
  }

  const otpPattern = new RegExp(`^\\d{${otpLength}}$`)
  const otpInput = z.object({
    challengeId: z.string().regex(/^[a-f0-9]{24}$/i),
    code: z.string().regex(otpPattern),
  }).strict()
  const mobileRequest = z.object({
    mobileNumber: z.string().trim().min(1).max(30),
    appType: z.enum(['customer', 'worker']),
    flow: z.enum(['login', 'registration']).default('login'),
  }).strict()

  router.post('/otp/request', handler(async (req, res) => {
    requireProvider()
    const parsed = mobileRequest.safeParse(req.body)
    if (!parsed.success) {
      const phone = req.body?.mobileNumber
      if (!normalizeIndianMobile(phone)) fail(400, 'INVALID_MOBILE', 'Enter a valid Indian mobile number.')
      throw parsed.error
    }
    const mobileNumber = normalizeIndianMobile(parsed.data.mobileNumber)
    if (!mobileNumber) fail(400, 'INVALID_MOBILE', 'Enter a valid Indian mobile number.')
    const now = new Date()
    const existing = await db.collection('users').findOne({ mobileNumber })
    if (parsed.data.flow === 'login' && !existing) {
      setPrivate(res)
      reply(req, res, {
        registrationRequired: true,
        appType: parsed.data.appType,
        mobileNumber,
      })
      return
    }
    if (parsed.data.flow === 'registration' && existing) {
      fail(409, 'MOBILE_ALREADY_REGISTERED', 'This mobile number is already registered. Sign in instead.')
    }
    if (parsed.data.flow === 'login' && existing && (
      existing.userType !== parsed.data.appType
      || existing.isActive !== true
      || existing.status !== 'active'
    )) {
      fail(403, 'ACCOUNT_DISABLED', 'This identity cannot sign in to this app.')
    }
    const requests = await db.collection('otp_challenges').countDocuments({
      mobileNumber,
      purpose: 'mobile_login',
      createdAt: { $gt: new Date(+now - 15 * 60 * 1000) },
    })
    const dailyRequests = await db.collection('otp_challenges').countDocuments({
      mobileNumber,
      purpose: 'mobile_login',
      createdAt: { $gt: new Date(+now - 24 * 60 * 60 * 1000) },
    })
    if (requests >= 3 || dailyRequests >= 10) {
      fail(429, 'OTP_RATE_LIMITED', 'Too many verification requests. Try again later.')
    }
    const previous = await db.collection('otp_challenges').findOne({
      mobileNumber,
      appType: parsed.data.appType,
      purpose: 'mobile_login',
      isActive: true,
    })
    if (previous && challengeExpiry(previous) > now && previous.nextResendAt > now) {
      fail(429, 'OTP_RESEND_COOLDOWN', 'Wait before requesting another verification code.')
    }
    if (previous) {
      await db.collection('otp_challenges').updateOne(
        { _id: previous._id, isActive: true },
        { $set: { isActive: false, status: 'superseded' } },
      )
    }

    const challenge = {
      _id: new mongoose.Types.ObjectId(),
      mobileNumber,
      appType: parsed.data.appType,
      purpose: 'mobile_login',
      provider: 'msg91_widget',
      status: 'sending',
      attempts: 0,
      resendCount: 0,
      createdAt: now,
      expiresAt: new Date(+now + challengeRetentionMs),
      nextResendAt: new Date(+now + cooldownMs),
      isActive: false,
    }
    await db.collection('otp_challenges').insertOne(challenge)
    let result
    try {
      result = await sms.send({ mobileNumber })
    } catch (error) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'sending' },
        { $set: { status: 'delivery_failed', isActive: false } },
      )
      providerFailure(req, 'send', error)
    }
    if (!result || typeof result.requestId !== 'string' || !result.requestId.trim()) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'sending' },
        { $set: { status: 'delivery_failed', isActive: false } },
      )
      logProviderFailure(req, 'send', { code: 'MSG91_INVALID_RESPONSE' })
      fail(503, 'OTP_PROVIDER_UNAVAILABLE', 'Mobile verification is temporarily unavailable.')
    }
    const activated = await db.collection('otp_challenges').updateOne(
      { _id: challenge._id, status: 'sending' },
      { $set: { status: 'active', isActive: true, providerRequestId: result.requestId } },
    )
    if (activated.modifiedCount !== 1) {
      fail(503, 'OTP_PROVIDER_UNAVAILABLE', 'Mobile verification is temporarily unavailable.')
    }
    setPrivate(res)
    reply(req, res, {
      challengeId: challenge._id,
      expiresInSeconds: otpExpirySeconds,
      resendAfterSeconds: resendCooldownSeconds,
    }, 201)
  }))

  router.post('/otp/resend', handler(async (req, res) => {
    requireProvider()
    const input = z.object({ challengeId: z.string().regex(/^[a-f0-9]{24}$/i) }).strict().parse(req.body)
    const now = new Date()
    const challenge = await db.collection('otp_challenges').findOne({
      _id: id(input.challengeId),
      purpose: 'mobile_login',
      status: 'active',
      isActive: true,
    })
    if (!challenge) fail(401, 'OTP_INVALID', 'Verification challenge is invalid.')
    const expiresAt = challengeExpiry(challenge)
    if (expiresAt <= now) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'active', isActive: true },
        { $set: { status: 'expired', isActive: false } },
      )
      fail(410, 'OTP_EXPIRED', 'Verification code has expired. Request a new code.')
    }
    if (challenge.nextResendAt > now) {
      fail(429, 'OTP_RESEND_COOLDOWN', 'Wait before requesting another verification code.')
    }
    if (challenge.resendCount >= maxResends) {
      fail(429, 'OTP_RATE_LIMITED', 'Verification code resend limit reached.')
    }
    const reserved = await db.collection('otp_challenges').updateOne(
      {
        _id: challenge._id,
        status: 'active',
        isActive: true,
        resendCount: challenge.resendCount,
        nextResendAt: { $lte: now },
      },
      {
        $inc: { resendCount: 1 },
        $set: { nextResendAt: new Date(+now + cooldownMs) },
      },
    )
    if (reserved.modifiedCount !== 1) {
      fail(429, 'OTP_RESEND_COOLDOWN', 'Wait before requesting another verification code.')
    }
    try {
      await sms.resend({ mobileNumber: challenge.mobileNumber, requestId: challenge.providerRequestId })
    } catch (error) {
      providerFailure(req, 'resend', error)
    }
    setPrivate(res)
    reply(req, res, {
      challengeId: challenge._id,
      expiresInSeconds: Math.max(0, Math.ceil((expiresAt - now) / 1000)),
      resendAfterSeconds: resendCooldownSeconds,
    })
  }))

  router.post('/otp/verify', handler(async (req, res) => {
    requireProvider()
    const input = otpInput.extend({
      fullName: z.string().trim().min(2).max(120).optional(),
    }).strict().parse(req.body)
    const now = new Date()
    const challengeId = id(input.challengeId)
    const challenge = await db.collection('otp_challenges').findOne({
      _id: challengeId,
      purpose: 'mobile_login',
    })
    if (!challenge) fail(401, 'OTP_INVALID', 'Verification code is invalid.')
    if (challengeExpiry(challenge) <= now) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, isActive: true },
        { $set: { status: 'expired', isActive: false } },
      )
      fail(410, 'OTP_EXPIRED', 'Verification code has expired. Request a new code.')
    }
    if (challenge.status === 'locked' || challenge.attempts >= maxAttempts) {
      fail(429, 'OTP_MAX_ATTEMPTS', 'Verification attempt limit reached.')
    }
    if (challenge.status !== 'active' || challenge.isActive !== true) {
      fail(401, 'OTP_INVALID', 'Verification code is invalid.')
    }
    const attempted = await db.collection('otp_challenges').findOneAndUpdate(
      {
        _id: challenge._id,
        purpose: 'mobile_login',
        status: 'active',
        isActive: true,
        attempts: { $lt: maxAttempts },
        createdAt: { $gt: new Date(+now - expiryMs) },
      },
      { $inc: { attempts: 1 } },
      { returnDocument: 'after' },
    )
    if (!attempted) fail(401, 'OTP_INVALID', 'Verification code is invalid or expired.')

    let verified
    try {
      verified = await sms.verify({
        mobileNumber: challenge.mobileNumber,
        requestId: challenge.providerRequestId,
        code: input.code,
      })
    } catch (error) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'active', attempts: attempted.attempts },
        { $inc: { attempts: -1 } },
      )
      providerFailure(req, 'verify', error)
    }
    if (!verified) {
      const status = attempted.attempts >= maxAttempts ? 'locked' : 'active'
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'active', isActive: true, attempts: attempted.attempts },
        { $set: { status, isActive: status === 'active' } },
      )
      if (status === 'locked') {
        fail(429, 'OTP_MAX_ATTEMPTS', 'Verification attempt limit reached.')
      }
      fail(401, 'OTP_INVALID', 'Verification code is invalid or expired.')
    }

    const existing = await db.collection('users').findOne({ mobileNumber: challenge.mobileNumber })
    if (existing && (
      existing.userType !== challenge.appType
      || existing.isActive !== true
      || existing.status !== 'active'
    )) {
      await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, isActive: true },
        { $set: { isActive: false, status: 'consumed', consumedAt: now } },
      )
      fail(403, 'ACCOUNT_DISABLED', 'This identity cannot sign in to this app.')
    }

    if (existing && challenge.appType === 'customer') {
      const profile = await db.collection('customers').findOne({
        $or: [{ userId: existing._id }, { _id: existing._id }],
      })
      if (profile && (profile.isActive === false || ['suspended', 'disabled', 'rejected'].includes(profile.status))) {
        await db.collection('otp_challenges').updateOne(
          { _id: challenge._id, isActive: true },
          { $set: { isActive: false, status: 'consumed', consumedAt: now } },
        )
        fail(403, 'ACCOUNT_DISABLED', 'This identity cannot sign in to this app.')
      }
    }

    if (!existing) {
      const registrationToken = randomBytes(32).toString('base64url')
      const registration = await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'active', isActive: true },
        {
          $set: {
            status: 'registration_pending',
            verifiedAt: now,
            registrationTokenHash: hash(registrationToken),
            registrationExpiresAt: new Date(+now + expiryMs),
          },
        },
      )
      if (registration.modifiedCount !== 1) {
        fail(409, 'OTP_INVALID', 'Verification code has already been used.')
      }
      setPrivate(res)
      reply(req, res, {
        registrationRequired: true,
        registrationToken,
        appType: challenge.appType,
        mobileNumber: challenge.mobileNumber,
        expiresInSeconds: otpExpirySeconds,
      })
      return
    }

    const token = randomBytes(32).toString('base64url')
    const request = { ...req, auth: { user: { _id: challenge._id } }, actorType: challenge.appType, body: {} }
    const sessionRecord = await atomic(db, request, 'mobile.login', 'auth_sessions', async session => {
      const currentUser = await db.collection('users').findOne({
        _id: existing._id,
        userType: challenge.appType,
        isActive: true,
        status: 'active',
      }, { session })
      if (!currentUser) fail(403, 'ACCOUNT_DISABLED', 'This identity cannot sign in to this app.')
      const consumed = await db.collection('otp_challenges').updateOne(
        { _id: challenge._id, status: 'active', isActive: true },
        { $set: { consumedAt: now, status: 'consumed', isActive: false } },
        { session },
      )
      if (consumed.modifiedCount !== 1) fail(409, 'OTP_INVALID', 'Verification code has already been used.')
      const profileCollection = challenge.appType === 'customer' ? 'customers' : 'workers'
      const profile = await db.collection(profileCollection).findOne({
        $or: [{ userId: existing._id }, { _id: existing._id }],
      }, { session })
      if (profile && (
        profile.isActive === false
        || (profile.status && profile.status !== 'active' && profile.status !== 'approved' && profile.status !== 'pending')
      )) {
        fail(403, 'ACCOUNT_DISABLED', 'This identity cannot sign in to this app.')
      }
      if (challenge.appType === 'customer' && !profile) {
        await db.collection('customers').insertOne({
          _id: existing._id,
          userId: existing._id,
          fullName: existing.fullName,
          status: 'active',
          createdAt: now,
          isActive: true,
          schemaVersion: 1,
        }, { session })
      }
      await db.collection('users').updateOne(
        { _id: existing._id, userType: challenge.appType, isActive: true, status: 'active' },
        { $set: { mobileVerifiedAt: currentUser.mobileVerifiedAt || now, updatedAt: now } },
        { session },
      )
      request.auth.user._id = existing._id
      return createSession(db, session, existing._id, challenge.appType, token, now)
    })
    const worker = challenge.appType === 'worker'
      ? await db.collection('workers').findOne({ userId: existing._id })
      : null
    setPrivate(res)
    reply(req, res, {
      accessToken: token,
      expiresAt: sessionRecord.expiresAt,
      appType: challenge.appType,
      ...(challenge.appType === 'worker' ? { workerStatus: worker?.status || 'not_registered' } : {}),
      user: { id: existing._id, fullName: existing.fullName, mobileNumber: existing.mobileNumber },
    })
  }))

  for (const appType of ['customer', 'worker']) {
    router.post(`/register/${appType}`, handler(async (req, res) => {
      const input = z.object({
        registrationToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
        fullName: z.string().trim().min(2).max(120),
        email: z.email().max(254).optional(),
      }).strict().parse(req.body)
      const now = new Date()
      const tokenHash = hash(input.registrationToken)
      const challenge = await db.collection('otp_challenges').findOne({
        registrationTokenHash: tokenHash,
        appType,
        purpose: 'mobile_login',
        status: 'registration_pending',
        isActive: true,
        registrationExpiresAt: { $gt: now },
      })
      if (!challenge) fail(401, 'REGISTRATION_EXPIRED', 'Verified registration has expired. Request a new code.')
      if (await db.collection('users').findOne({ mobileNumber: challenge.mobileNumber })) {
        fail(409, 'MOBILE_ALREADY_REGISTERED', 'This mobile number is already registered.')
      }

      const token = randomBytes(32).toString('base64url')
      const request = { ...req, auth: { user: { _id: challenge._id } }, actorType: appType, body: req.body }
      let user
      try {
        await atomic(db, request, 'mobile.register', 'users', async session => {
          const claimed = await db.collection('otp_challenges').updateOne(
            {
              _id: challenge._id,
              registrationTokenHash: tokenHash,
              status: 'registration_pending',
              isActive: true,
              registrationExpiresAt: { $gt: now },
            },
            { $set: { status: 'consumed', consumedAt: now, isActive: false, registrationTokenHash: null } },
            { session },
          )
          if (claimed.modifiedCount !== 1) fail(409, 'REGISTRATION_ALREADY_USED', 'Registration was already completed.')
          user = {
            _id: new mongoose.Types.ObjectId(),
            userType: appType,
            fullName: input.fullName,
            mobileNumber: challenge.mobileNumber,
            ...(input.email ? { email: input.email } : {}),
            authProvider: 'mobile_otp',
            mobileVerifiedAt: now,
            status: 'active',
            isActive: true,
            createdAt: now,
            schemaVersion: 1,
          }
          await db.collection('users').insertOne(user, { session })
          if (appType === 'customer') {
            await db.collection('customers').insertOne({
              _id: user._id,
              userId: user._id,
              fullName: user.fullName,
              ...(user.email ? { email: user.email } : {}),
              status: 'active',
              createdAt: now,
              isActive: true,
              schemaVersion: 1,
            }, { session })
          }
          request.auth.user._id = user._id
          return createSession(db, session, user._id, appType, token, now)
        })
      } catch (error) {
        if (error.code === 11000) fail(409, 'MOBILE_ALREADY_REGISTERED', 'This mobile number is already registered.')
        throw error
      }

      const sessionRecord = await db.collection('auth_sessions').findOne({
        userId: user._id,
        appType,
        refreshTokenHash: hash(token),
        isActive: true,
      })
      setPrivate(res)
      reply(req, res, {
        accessToken: token,
        expiresAt: sessionRecord.expiresAt,
        appType,
        ...(appType === 'worker' ? { workerStatus: 'not_registered' } : {}),
        user: { id: user._id, fullName: user.fullName, mobileNumber: user.mobileNumber },
      }, 201)
    }))
  }
  return router
}

async function createSession(db, session, userId, appType, token, now) {
  const record = {
    _id: new mongoose.Types.ObjectId(),
    userId,
    appType,
    refreshTokenHash: hash(token),
    issuedAt: now,
    expiresAt: new Date(+now + 24 * 60 * 60 * 1000),
    isActive: true,
  }
  await db.collection('auth_sessions').insertOne(record, { session })
  return record
}

module.exports = { mobileAuth, createMobileAuthRouter }
