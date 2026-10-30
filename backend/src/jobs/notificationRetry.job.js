const { id } = require('../platform/core')
const { digest, notificationCopy } = require('../platform/push-notifications')

// Scan committed inbox events. A push outage never rolls back a booking or a payment.
function createNotificationDispatcher({ db, provider, now = () => new Date() }) {
  let cursor = null
  return async function dispatch() {
    if (!provider) return
    const time = now(), earliest = new Date(+time - 24 * 3600000)
    const filter = { isActive: true, createdAt: { $gte: earliest, $lte: time } }
    if (cursor) filter.$or = [{ createdAt: { $gt: cursor.createdAt } }, { createdAt: cursor.createdAt, _id: { $gt: cursor._id } }]
    const scanned = await db.collection('notifications').find(filter).sort({ createdAt: 1, _id: 1 }).limit(100).toArray()
    // Due deliveries remain retryable even when their original event leaves the discovery window.
    const due = await db.collection('push_deliveries').find({status:{$in:['pending','sending']},attempts:{$lt:5},nextAttemptAt:{$lte:time},leaseUntil:{$lte:time},expiresAt:{$gt:time}}).sort({nextAttemptAt:1,_id:1}).limit(100).toArray()
    const retries = due.length ? await db.collection('notifications').find({_id:{$in:due.map(item=>item.notificationId)},isActive:true}).toArray() : []
    const events = [...new Map([...retries,...scanned].map(event=>[String(event._id),event])).values()]
    const processEvent = async event => {
      const catalog = { 'offer.published': 'offers', 'package.published': 'service_packages', 'banner.published': 'promotional_banners' }[event.type]
      if (catalog) {
        const item = await db.collection(catalog).findOne({ _id: event.entityId, isActive: true, status: 'published', isDeleted: { $ne: true } })
        if (!item || item.startsAt && new Date(item.startsAt) > time || item.endsAt && new Date(item.endsAt) <= time) return
      }
      const user = await db.collection('users').findOne({ _id: event.recipientUserId, userType: { $in: ['customer', 'worker'] }, isActive: true, status: 'active' })
      if (!user) return
      const profile = await db.collection(user.userType === 'worker' ? 'workers' : 'customers').findOne({ userId: user._id })
      const preferences = await db.collection('notification_preferences').findOne({ _id: user._id })
      if ((preferences?.notificationsEnabled ?? profile?.notificationsEnabled) === false || profile?.isActive === false || catalog && (preferences?.marketingNotificationsEnabled ?? profile?.marketingNotificationsEnabled) === false) return
      if (user.userType === 'worker' && ['rejected', 'suspended'].includes(profile?.status) && !event.type.startsWith('worker.')) return
      const devices = await db.collection('push_devices').find({ userId: user._id, appType: user.userType, isActive: true, registeredAt: { $lte: event.createdAt } }).limit(20).toArray()
      for (const device of devices) {
        const enrolledSession = await db.collection('auth_sessions').findOne({ _id: device.sessionId, userId: user._id, appType: user.userType })
        // Enrollment survives normal API-session expiry/TTL cleanup, so alerts keep arriving while the app is closed.
        // Explicit logout/revocation and account suspension still stop delivery.
        if (enrolledSession && (enrolledSession.isActive !== true || enrolledSession.revokedAt)) continue
        const _id = id(digest(String(event._id) + ':' + String(device._id)).slice(0, 24))
        await db.collection('push_deliveries').updateOne({ _id }, { $setOnInsert: {
          notificationId: event._id, deviceId: device._id, status: 'pending', attempts: 0,
          nextAttemptAt: time, leaseUntil: new Date(0), expiresAt: new Date(+time + 7 * 86400000),
        } }, { upsert: true })
        const claim = await db.collection('push_deliveries').findOneAndUpdate({ _id, status: { $in: ['pending', 'sending'] },
          attempts: { $lt: 5 }, nextAttemptAt: { $lte: time }, leaseUntil: { $lte: time },
        }, { $set: { status: 'sending', leaseUntil: new Date(+time + 60000) }, $inc: { attempts: 1 } }, { returnDocument: 'after' })
        if (!claim) continue
        try {
          // Re-check ownership after claiming: another user may have signed in on this installation.
          const current = await db.collection('push_devices').findOne({ _id: device._id, userId: user._id, sessionId: device.sessionId, isActive: true })
          if (!current) {
            await db.collection('push_deliveries').updateOne({ _id }, { $set: { status: 'skipped' } })
            continue
          }
          await provider.send({ token: current.token, notification: notificationCopy(event.type),
            data: { notificationId: String(event._id), type: event.type, entityId: String(event.entityId || '') },
            android: { priority: 'high', notification: { channelId: 'hii_beauty_updates', tag: String(event._id), icon: 'ic_stat_beauty' } },
            apns: { headers: { 'apns-collapse-id': String(event._id) }, payload: { aps: { sound: 'default' } } },
          })
          await db.collection('push_deliveries').updateOne({ _id }, { $set: { status: 'sent', sentAt: now() } })
        } catch (error) {
          const invalid = ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(error.code)
          if (invalid) await db.collection('push_devices').updateOne({ _id: device._id, token: device.token }, { $set: { isActive: false } })
          await db.collection('push_deliveries').updateOne({ _id }, { $set: {
            status: invalid || claim.attempts >= 5 ? 'failed' : 'pending',
            leaseUntil: new Date(0), nextAttemptAt: new Date(+time + Math.min(3600000, 15000 * 2 ** claim.attempts)),
            errorCode: typeof error.code === 'string' && /^messaging\/[a-z-]+$/.test(error.code) ? error.code : 'push-unavailable',
          } })
        }
      }
    }
    let next = 0
    const results = await Promise.allSettled(Array.from({length:Math.min(5,events.length)},async()=>{
      while(next<events.length) await processEvent(events[next++])
    }))
    const failure = results.find(result=>result.status==='rejected')
    if(failure)throw failure.reason
    cursor = scanned.length === 100 ? scanned.at(-1) : null
  }
}

function startNotificationRetryJob({ db, provider, logger, intervalMs = 5000 }) {
  if (!provider) return () => {}
  const dispatch = createNotificationDispatcher({ db, provider })
  let busy = false, stopped = false
  const tick = async () => {
    if (busy || stopped) return
    busy = true
    try {
      await require('../platform/push-campaigns').expandPushCampaigns({ db })
      await dispatch()
    } catch (error) { logger.error({ errorName: error.name }, 'Push notification dispatch failed') }
    finally { busy = false }
  }
  const timer = setInterval(tick, intervalMs)
  timer.unref?.()
  void tick()
  return () => { stopped = true; clearInterval(timer) }
}

module.exports = { createNotificationDispatcher, startNotificationRetryJob }
