const { randomBytes } = require('node:crypto')
const argon2 = require('argon2')
const express = require('express')
const mongoose = require('mongoose')
const { z } = require('zod')
const env = require('../../config/env')
const { HttpError } = require('../../middleware/errorHandler')
const { requireSameOrigin } = require('../../middleware/authorize')
const { adminLoginLimiter } = require('../../middleware/rateLimiter')
const {
  COOKIE_NAME,
  cookieOptions,
  createAuthentication,
  csrfToken,
  hashToken,
  isActiveAdmin,
  isActiveRole,
  issueSessionToken,
} = require('../../middleware/authenticate')

const loginSchema = z.object({
  email: z.string().trim().email().max(254).transform(value => value.toLowerCase()),
  password: z.string().min(1).max(1024),
}).strict()

const dummyHash = argon2.hash(randomBytes(32), { type: argon2.argon2id })

function success(res, req, data, status = 200) {
  res.status(status).json({ success: true, data, requestId: req.id })
}

function setSessionCookie(res, token, ttlMs) {
  res.cookie(COOKIE_NAME, token, cookieOptions(ttlMs))
}

function clearSessionCookie(res) {
  res.clearCookie(COOKIE_NAME, cookieOptions(0))
}

function adminIdentity(user, role) {
  return {
    id: user._id.toString(),
    name: user.fullName,
    email: user.email,
    role: role.roleCode,
    permissions: role.permissions,
  }
}

async function writeAudit(AuditLog, req, actor, action, result) {
  const record = new AuditLog({
    actorUserId: actor.user._id,
    actorRole: actor.role.roleCode,
    action,
    entityType: 'admin_auth',
    entityId: actor.user._id,
    changes: {},
    requestId: req.id,
    ipAddress: req.ip,
    userAgent: req.get('user-agent') || '',
    result,
    createdAt: new Date(),
    isActive: true,
  })
  await record.save()
}

function createAdminAuthRouter({
  models,
  sessionSecret = env.SESSION_COOKIE_SECRET,
  loginLimiter = adminLoginLimiter,
}) {
  const router = express.Router()
  const { User, Role, AuthSession, AuditLog } = models
  const auth = createAuthentication({ User, Role, AuthSession, secret: sessionSecret })
  const ttlMs = env.ADMIN_SESSION_TTL_HOURS * 60 * 60 * 1000

  router.post('/login', loginLimiter, requireSameOrigin, async (req, res, next) => {
    if (!sessionSecret) return next(new HttpError(503, 'AUTH_NOT_CONFIGURED', 'Admin authentication is not configured.'))
    const parsed = loginSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Enter a valid email address and password.'))

    try {
      const user = await User.findOne({ email: parsed.data.email }).select('+passwordHash').lean()
      const hash = user?.passwordHash
      const passwordValid = typeof hash === 'string' && hash.startsWith('$argon2id$')
        ? await argon2.verify(hash, parsed.data.password)
        : await argon2.verify(await dummyHash, parsed.data.password)

      if (!passwordValid || !isActiveAdmin(user)) {
        return next(new HttpError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.'))
      }

      const role = await Role.findById(user.roleId).lean()
      if (!isActiveRole(role)) {
        return next(new HttpError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.'))
      }

      const token = issueSessionToken()
      const now = new Date()
      const session = new AuthSession({
        userId: user._id,
        refreshTokenHash: hashToken(token),
        appType: 'admin',
        issuedAt: now,
        expiresAt: new Date(now.getTime() + ttlMs),
        lastSeenAt: now,
        isActive: true,
      })

      await session.save()
      try {
        await writeAudit(AuditLog, req, { user, role }, 'admin.login', 'success')
      } catch (error) {
        await AuthSession.updateOne({ _id: session._id }, { $set: { revokedAt: new Date(), isActive: false } })
        throw error
      }

      setSessionCookie(res, token, ttlMs)
      success(res, req, { admin: adminIdentity(user, role), csrfToken: csrfToken(token, sessionSecret) })
    } catch (error) {
      next(error)
    }
  })

  router.get('/session', auth.requireAuthenticated, (req, res) => {
    success(res, req, {
      admin: adminIdentity(req.auth.user, req.auth.role),
      csrfToken: csrfToken(req.auth.token, sessionSecret),
    })
  })

  router.post('/logout', requireSameOrigin, auth.requireAuthenticated, auth.requireCsrf, async (req, res, next) => {
    try {
      const now = new Date()
      await AuthSession.updateOne(
        { _id: req.auth.session._id, revokedAt: null },
        { $set: { revokedAt: now, isActive: false, updatedAt: now } },
      )
      await writeAudit(AuditLog, req, req.auth, 'admin.logout', 'success')
      clearSessionCookie(res)
      success(res, req, { loggedOut: true })
    } catch (error) {
      next(error)
    }
  })

  router.post('/password/change', requireSameOrigin, auth.requireAuthenticated, auth.requireCsrf, async (req,res,next) => {
    const parsed=z.object({currentPassword:z.string().min(1).max(1024),newPassword:z.string().min(16).max(128)}).strict().safeParse(req.body)
    if(!parsed.success)return next(new HttpError(400,'VALIDATION_ERROR','Enter the current password and a new password of 16 to 128 characters.'))
    let session
    try {
      const user=await User.findById(req.auth.user._id).select('+passwordHash').lean()
      if(!user?.passwordHash || !await argon2.verify(user.passwordHash,parsed.data.currentPassword))return next(new HttpError(401,'INVALID_CREDENTIALS','Current password is incorrect.'))
      const passwordHash=await argon2.hash(parsed.data.newPassword,{type:argon2.argon2id,memoryCost:65536,timeCost:3,parallelism:1})
      session=await mongoose.startSession()
      await session.withTransaction(async()=>{
        const updated=await User.updateOne({_id:user._id,passwordHash:user.passwordHash},{$set:{passwordHash,updatedAt:new Date()}},{session})
        if(updated.modifiedCount!==1)throw new HttpError(409,'STALE_RECORD','Account changed. Sign in again.')
        await AuthSession.updateMany({userId:user._id},{$set:{isActive:false,revokedAt:new Date()}},{session})
        await new AuditLog({actorUserId:user._id,actorRole:req.auth.role.roleCode,action:'admin.password.change',entityType:'users',entityId:user._id,changes:{},createdAt:new Date(),requestId:req.id,result:'success',isActive:true}).save({session})
      })
      clearSessionCookie(res);success(res,req,{changed:true,signInRequired:true})
    }catch(error){next(error)}finally{if(session)await session.endSession()}
  })
  router.post('/password/reset', loginLimiter, requireSameOrigin, (req,res,next) => {
    next(new HttpError(503,'RECOVERY_NOT_CONFIGURED','An approved secure recovery process is not configured.'))
  })
  return router
}

module.exports = { createAdminAuthRouter, loginSchema }
