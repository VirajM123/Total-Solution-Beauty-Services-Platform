const { createHash, createHmac, timingSafeEqual, randomBytes } = require('node:crypto')
const env = require('../config/env')
const { HttpError } = require('./errorHandler')

const COOKIE_NAME = env.NODE_ENV === 'production' ? '__Host-hi_admin_session' : 'hi_admin_session'

function hashToken(token) {
  return createHash('sha256').update(token).digest('hex')
}

function csrfToken(token, secret = env.SESSION_COOKIE_SECRET) {
  return createHmac('sha256', secret).update(`csrf:${token}`).digest('base64url')
}

function safeEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

function readCookie(req, name = COOKIE_NAME) {
  const header = req.get('cookie') || ''
  for (const entry of header.split(';')) {
    const separator = entry.indexOf('=')
    if (separator < 0 || entry.slice(0, separator).trim() !== name) continue
    try {
      return decodeURIComponent(entry.slice(separator + 1).trim())
    } catch {
      return ''
    }
  }
  return ''
}

function createAuthentication({ AuthSession, User, Role, secret = env.SESSION_COOKIE_SECRET }) {
  async function requireAuthenticated(req, res, next) {
    if (!secret) return next(new HttpError(503, 'AUTH_NOT_CONFIGURED', 'Admin authentication is not configured.'))

    const token = readCookie(req)
    if (!token || token.length > 128) return next(new HttpError(401, 'UNAUTHENTICATED', 'Sign in is required.'))

    try {
      const session = await AuthSession.findOne({
        refreshTokenHash: hashToken(token),
        appType: 'admin',
        revokedAt: null,
        expiresAt: { $gt: new Date() },
        isActive: true,
      }).lean()
      if (!session) return next(new HttpError(401, 'UNAUTHENTICATED', 'Your session has expired. Sign in again.'))

      const user = await User.findById(session.userId).select('-passwordHash').lean()
      if (!isActiveAdmin(user)) return next(new HttpError(401, 'UNAUTHENTICATED', 'Your Admin account is inactive.'))
      const role = await Role.findById(user.roleId).lean()
      if (!isActiveRole(role)) return next(new HttpError(403, 'FORBIDDEN', 'Your account has no active Admin role.'))

      req.auth = { user, role, session, token }
      next()
    } catch (error) {
      next(error)
    }
  }

  function requirePermission(permission) {
    return (req, res, next) => {
      if (!req.auth) return next(new HttpError(401, 'UNAUTHENTICATED', 'Sign in is required.'))
      if (!Array.isArray(req.auth.role.permissions) || !req.auth.role.permissions.includes(permission)) {
        return next(new HttpError(403, 'FORBIDDEN', 'Your Admin role does not allow this action.'))
      }
      next()
    }
  }

  function requireCsrf(req, res, next) {
    if (!req.auth) return next(new HttpError(401, 'UNAUTHENTICATED', 'Sign in is required.'))
    const suppliedCsrf = req.get('x-csrf-token')
    if (!safeEqual(suppliedCsrf, csrfToken(req.auth.token, secret))) {
      return next(new HttpError(403, 'CSRF_REJECTED', 'The security token is invalid. Refresh your session and try again.'))
    }
    next()
  }

  return { requireAuthenticated, requirePermission, requireCsrf }
}

function isActiveRole(role) {
  return Boolean(role && role.isActive === true && typeof role.roleCode === 'string' && role.roleCode.trim()
    && Array.isArray(role.permissions) && role.permissions.every(value => typeof value === 'string'))
}

function isActiveAdmin(user) {
  return Boolean(
    user
    && user.isActive === true
    && typeof user.userType === 'string'
    && user.userType.toLowerCase() === 'admin'
    && typeof user.status === 'string'
    && user.status.toLowerCase() === 'active',
  )
}

function issueSessionToken() {
  return randomBytes(32).toString('base64url')
}

function cookieOptions(maxAge, secure = env.NODE_ENV === 'production') {
  return {
    httpOnly: true,
    secure,
    sameSite: 'strict',
    path: '/',
    maxAge,
  }
}

module.exports = {
  COOKIE_NAME,
  cookieOptions,
  createAuthentication,
  csrfToken,
  hashToken,
  isActiveAdmin,
  isActiveRole,
  issueSessionToken,
  readCookie,
  safeEqual,
}