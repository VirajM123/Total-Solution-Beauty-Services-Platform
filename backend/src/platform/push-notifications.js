const { createHash } = require('node:crypto')
const { z } = require('zod')
const { id, fail, handler, reply, protectedRouter } = require('./core')

const digest = value => createHash('sha256').update(value).digest('hex')
const tokenInput = z.object({ token: z.string().trim().min(20).max(4096), platform: z.enum(['android', 'ios']) }).strict()

function installDeviceRoutes(area, { db, app, enabled = require('../config/env').FCM_ENABLED }) {
  area.post('/push-device', handler(async (req, res) => {
    if (!enabled) fail(503, 'PUSH_NOT_CONFIGURED', 'Device push is not configured on this server.')
    const input = tokenInput.parse(req.body)
    const now = new Date(), _id = id(digest(app + ':' + input.token).slice(0, 24))
    // Only the current authenticated installation owns this token. Never accept a user ID from the phone.
    await db.collection('push_devices').updateMany({ sessionId: req.auth.session._id, _id: { $ne: _id } }, { $set: { isActive: false } })
    const previous = await db.collection('push_devices').findOne({ _id })
    const sameOwner = previous && String(previous.userId) === String(req.auth.user._id) && previous.isActive
    await db.collection('push_devices').updateOne({ _id }, { $set: {
      userId: req.auth.user._id, sessionId: req.auth.session._id, appType: app,
      token: input.token, platform: input.platform, isActive: true, updatedAt: now,
      registeredAt: sameOwner ? previous.registeredAt : now,
    } }, { upsert: true })
    res.set('Cache-Control', 'no-store')
    reply(req, res, { registered: true })
  }))
  area.post('/push-device/remove', handler(async (req, res) => {
    await db.collection('push_devices').updateMany({ sessionId: req.auth.session._id, userId: req.auth.user._id }, { $set: { isActive: false } })
    reply(req, res, { removed: true })
  }))
}

// Notification text is server-owned. OTPs, phone numbers and payment details never enter push payloads.
function notificationCopy(type) {
  const messages = {
    'booking.created': ['New booking', 'A new order needs your attention.'],
    'booking.confirmed': ['Booking confirmed', 'Your beauty service booking is confirmed.'],
    'assignment.assigned': ['New task assigned', 'You have a new booking. Open Hi Beauty to see the details.'],
    'assignment.offered': ['Booking offer', 'A new booking is available. Open Hi Beauty to respond.'],
    'booking.assigned': ['Expert assigned', 'An expert has been assigned to your booking.'],
    'booking.travelling': ['Expert on the way', 'Your expert has started travelling to your booking.'],
    'booking.arrived': ['Expert arrived', 'Your expert has arrived. Open the booking for your service OTP.'],
    'booking.in_progress': ['Service started', 'Your service is now in progress.'],
    'booking.completed': ['Service completed', 'Your service is complete. Your receipt is available in the app.'],
    'booking.cancelled': ['Booking cancelled', 'Your booking has been cancelled. Open the app for details.'],
    'booking.rescheduled': ['Booking rescheduled', 'A booking schedule has changed. Open Hi Beauty to check your current tasks.'],
    'assignment.revoked': ['Assignment updated', 'A booking assignment has changed. Open your task list for current details.'],
    'booking.extra_service.approved': ['Extra service approved', 'The customer approved an extra service. Open the booking for details.'],
    'booking.extra_service.declined': ['Extra service declined', 'The customer declined the extra service. Continue with the confirmed services.'],
    'booking.duration_extension_approved': ['Extra time approved', 'Extra time has been approved. Check the booking for continuation requirements.'],
    'booking.duration_extension_declined': ['Extra time declined', 'Extra time was declined. Finish the original service and follow the payment steps.'],
    'booking.duration_extension_expired': ['Extra-time request expired', 'No extra time was authorized. Open the booking for the next step.'],
    'booking.extra_service.requested': ['Extra service requested', 'Open your booking to approve or decline the extra service.'],
    'booking.duration_extension_requested': ['Extra time requested', 'Your service time has ended. Open the booking to review extra time.'],
    'booking.duration_extension_otp_issued': ['Continuation authorized', 'Contact the administrator for the continuation OTP.'],
    'booking.service_completion_otp_issued': ['Completion authorized', 'Contact the administrator for the completion OTP.'],
    'booking.payment_received': ['Payment verified', 'Payment for your booking has been verified.'],
    'worker.approved': ['Registration approved', 'Your worker account has been approved.'],
    'offer.published': ['New offer', 'A new Hi Beauty offer is available. Open the app to explore.'],
    'package.published': ['New package', 'A new beauty package is available. Open the app to explore.'],
    'banner.published': ['New Hi Beauty offer', 'A new offer is available. Open Hi Beauty to explore.'],
  }
  const [title, body] = messages[type] || ['Hi Beauty update', 'You have a new update. Open Hi Beauty for details.']
  return { title, body }
}

function createAdminNotificationRouter({ db, auth }) {
  const router = protectedRouter(auth)
  router.get('/notification-feed', handler(async (req, res) => {
    const input = z.object({ after: z.iso.datetime().optional(), afterId: z.string().regex(/^[a-f0-9]{24}$/i).optional() }).strict().parse(req.query)
    const initialTime = new Date()
    const scope = { recipientUserId: req.auth.user._id, isActive: true }
    if (input.after) scope.$or = [
      { createdAt: { $gt: new Date(input.after) } },
      { createdAt: new Date(input.after), _id: { $gt: input.afterId ? id(input.afterId) : id('000000000000000000000000') } },
    ]
    let items = await db.collection('notifications').find(scope, { projection: { _id: 1, type: 1, entityId: 1, createdAt: 1, isRead: 1 } })
      .sort(input.after ? { createdAt: 1, _id: 1 } : { createdAt: -1, _id: -1 }).limit(100).toArray()
    if (!input.after) items = items.reverse()
    const last = items.at(-1)
    res.set('Cache-Control', 'no-store')
    reply(req, res, { items: items.map(item => ({ ...item, ...notificationCopy(item.type) })),
      cursor: last ? { at: last.createdAt, id: last._id } : input.after ? { at: input.after, id: input.afterId } : { at: initialTime, id: '000000000000000000000000' } })
  }))
  router.patch('/notification-feed/:id/read', handler(async (req, res) => {
    await db.collection('notifications').updateOne({ _id: id(req.params.id), recipientUserId: req.auth.user._id }, { $set: { isRead: true } })
    reply(req, res, { read: true })
  }))
  return router
}

function createPushProvider({ enabled = false, projectId } = {}) {
  if (!enabled) return null
  const { initializeApp, getApps, applicationDefault } = require('firebase-admin/app')
  const { getMessaging } = require('firebase-admin/messaging')
  const app = getApps().find(item => item.name === 'hii-beauty-push') || initializeApp({
    credential: applicationDefault(), ...(projectId ? { projectId } : {}), httpTimeout: 10000,
  }, 'hii-beauty-push')
  return { send: message => getMessaging(app).send(message) }
}

module.exports = { installDeviceRoutes, createAdminNotificationRouter, createPushProvider, notificationCopy, digest }
