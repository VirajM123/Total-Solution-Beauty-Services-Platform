const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { installDeviceRoutes, createAdminNotificationRouter } = require('../src/platform/push-notifications')
const { createNotificationDispatcher } = require('../src/jobs/notificationRetry.job')
const { createPushCampaignRouter, expandPushCampaigns } = require('../src/platform/push-campaigns')
const { createWorkflowsRouter } = require('../src/platform/workflows.routes')
const { createMobileRouter } = require('../src/platform/mobile.routes')
const { errorHandler } = require('../src/middleware/errorHandler')
const oid = () => new mongoose.Types.ObjectId()

function fixture() {
  const userId = oid(), sessionId = oid(), deviceId = oid(), eventId = oid(), entityId = oid()
  let time = new Date('2026-10-30T10:00:00Z')
  const db = memoryDatabase({
    users: [{ _id: userId, userType: 'worker', status: 'active', isActive: true }],
    workers: [{ userId, isActive: true }],
    auth_sessions: [{ _id: sessionId, userId, appType: 'worker', isActive: true, revokedAt: null, expiresAt: new Date(+time + 86400000) }],
    push_devices: [{ _id: deviceId, userId, sessionId, appType: 'worker', token: 'private-fcm-token-for-worker', platform: 'android', isActive: true, registeredAt: new Date(+time - 60000) }],
    notifications: [{ _id: eventId, recipientUserId: userId, entityId, type: 'assignment.assigned', isActive: true, isRead: false, createdAt: time }],
  })
  return { db, userId, sessionId, eventId, entityId, deviceId, now: () => time, advance: n => { time = new Date(+time + n) } }
}

async function serve(router, actor, run) {
  const app = express()
  app.use(express.json(), (req, res, next) => { req.auth = actor; next() }, router, errorHandler)
  const server = app.listen(0, '127.0.0.1')
  await new Promise(resolve => server.once('listening', resolve))
  try { await run('http://127.0.0.1:' + server.address().port) }
  finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)) }
}
const auth = { requireAuthenticated(req, res, next) { next() }, requireCsrf(req, res, next) { next() },
  requirePermission(permission) { return (req, res, next) => req.auth.role.permissions.includes(permission) ? next() : res.sendStatus(403) } }

test('committed task notifications send once per device, with OS display payload and no OTP/token in data', async () => {
  const f = fixture(), sent = []
  const dispatch = createNotificationDispatcher({ db: f.db, now: f.now, provider: { async send(message) { sent.push(message) } } })
  await dispatch(); await dispatch()
  assert.equal(sent.length, 1)
  assert.equal(sent[0].notification.title, 'New task assigned')
  assert.equal(sent[0].android.notification.channelId, 'hii_beauty_updates')
  assert.equal(sent[0].data.entityId, String(f.entityId))
  assert.deepEqual(Object.keys(sent[0].data).sort(), ['entityId', 'notificationId', 'type'])
  assert.equal(f.db.records().push_deliveries[0].status, 'sent')
})

test('transient push failure backs off, survives dispatcher restart, and retries without changing booking records', async () => {
  const f = fixture(); let calls = 0
  const provider = { async send() { if (++calls === 1) throw Error('private provider response') } }
  await createNotificationDispatcher({ db: f.db, now: f.now, provider })()
  assert.equal(f.db.records().push_deliveries[0].status, 'pending')
  assert.equal(f.db.records().push_deliveries[0].errorCode, 'push-unavailable')
  const restarted = createNotificationDispatcher({ db: f.db, now: f.now, provider })
  await restarted(); assert.equal(calls, 1)
  f.advance(31000); await restarted()
  assert.equal(calls, 2)
  assert.equal(f.db.records().push_deliveries[0].status, 'sent')
  assert.equal(f.db.records().bookings, undefined)
})

test('invalid FCM tokens are deactivated and not retried', async () => {
  const f = fixture(); let calls = 0
  const dispatch = createNotificationDispatcher({ db: f.db, now: f.now, provider: { async send() { calls++; throw Object.assign(Error('invalid'), { code: 'messaging/registration-token-not-registered' }) } } })
  await dispatch(); f.advance(60000); await dispatch()
  assert.equal(calls, 1)
  assert.equal(f.db.records().push_devices[0].isActive, false)
  assert.equal(f.db.records().push_deliveries[0].status, 'failed')
})

test('phone alerts survive normal API session expiry and TTL cleanup while explicit device enrollment remains active', async () => {
  for (const removeSession of [false, true]) {
    const f = fixture(); let calls = 0
    if (removeSession) f.db.records().auth_sessions.length = 0
    else f.db.records().auth_sessions[0].expiresAt = new Date(+f.now() - 1000)
    await createNotificationDispatcher({ db: f.db, now: f.now, provider: { async send() { calls++ } } })()
    assert.equal(calls, 1)
  }
})

test('revoked sessions, disabled preferences and tokens registered after an event receive no push', async () => {
  for (const change of [f => { f.db.records().auth_sessions[0].isActive = false },
    f => { f.db.records().workers[0].notificationsEnabled = false },
    f => { f.db.records().push_devices[0].registeredAt = new Date(+f.now() + 1) },
    f => { f.db.records().users[0].isActive = false }]) {
    const f = fixture(); change(f)
    let calls = 0
    await createNotificationDispatcher({ db: f.db, now: f.now, provider: { async send() { calls++ } } })()
    assert.equal(calls, 0)
  }
})

test('delivery attempts are bounded, and one failing device does not duplicate another device delivery', async () => {
  const f = fixture(), good = { ...f.db.records().push_devices[0], _id: oid(), token: 'another-private-device-token' }
  f.db.records().push_devices.push(good)
  const calls = []
  const dispatch = createNotificationDispatcher({ db: f.db, now: f.now, provider: { async send(message) { calls.push(message.token); if (message.token !== good.token) throw Error('unavailable') } } })
  for (let n = 0; n < 7; n++) { await dispatch(); f.advance(3600000) }
  assert.equal(calls.filter(token => token === good.token).length, 1)
  assert.equal(calls.filter(token => token !== good.token).length, 5)
})

test('device registration binds to the authenticated actor, rotates tokens and rejects caller supplied identity', async () => {
  const f = fixture(), area = express.Router()
  installDeviceRoutes(area, { db: f.db, app: 'worker', enabled: true })
  await serve(area, { user: { _id: f.userId }, session: { _id: f.sessionId } }, async base => {
    const post = body => fetch(base + '/push-device', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
    assert.equal((await post({ token: 'new-private-registration-token', platform: 'android', userId: String(oid()) })).status, 400)
    const response = await post({ token: 'new-private-registration-token', platform: 'android' })
    assert.equal(response.status, 200)
    assert.equal((await response.json()).data.token, undefined)
    assert.equal(f.db.records().push_devices[0].isActive, false)
    assert.equal(String(f.db.records().push_devices[1].userId), String(f.userId))
  })
})

test('admin notification feed and read controls stay scoped to their recipient, with a cursor even when empty', async () => {
  const f = fixture(), otherId = oid()
  await serve(createAdminNotificationRouter({ db: f.db, auth }), { user: { _id: otherId } }, async base => {
    const response = await fetch(base + '/notification-feed')
    const result = (await response.json()).data
    assert.deepEqual(result.items, [])
    assert.ok(result.cursor.at)
    await fetch(base + '/notification-feed/' + f.eventId + '/read', { method: 'PATCH', headers: { origin: 'http://localhost:5173', 'content-type': 'application/json' }, body: '{}' })
    assert.equal(f.db.records().notifications[0].isRead, false)
  })
  await serve(createAdminNotificationRouter({ db: f.db, auth }), { user: { _id: f.userId } }, async base => {
    const result = (await (await fetch(base + '/notification-feed')).json()).data
    assert.equal(result.items.length, 1)
    const next = await fetch(base + '/notification-feed?after=' + encodeURIComponent(result.cursor.at) + '&afterId=' + result.cursor.id)
    assert.deepEqual((await next.json()).data.items, [])
  })
})

test('mobile notification inbox uses readable push copy and excludes another user’s notifications', async () => {
  const f = fixture(), token = 'p'.repeat(43)
  Object.assign(f.db.records().auth_sessions[0], { refreshTokenHash: require('node:crypto').createHash('sha256').update(token).digest('hex') })
  Object.assign(f.db.records().workers[0], { _id: oid(), status: 'approved' })
  await f.db.collection('notifications').insertOne({ _id: oid(), recipientUserId: oid(), type: 'booking.created', isActive: true, createdAt: f.now() })
  await serve(createMobileRouter({ db: f.db, scheduling: {} }), {}, async base => {
    const response = await fetch(base + '/worker/notifications', { headers: { authorization: 'Bearer ' + token } })
    assert.equal(response.status, 200)
    const result = (await response.json()).data
    assert.equal(result.items.length, 1)
    assert.equal(result.items[0].title, 'New task assigned')
    assert.equal(result.items[0].message, result.items[0].body)
    assert.equal(result.items[0].token, undefined)
  })
})

test('publish-notify enforces publishing permission, queues once, and fans out only to the saved audience', async () => {
  const now = new Date(), bannerId = oid(), adminId = oid(), customerId = oid(), workerId = oid()
  const db = memoryDatabase({
    promotional_banners: [{ _id: bannerId, name: 'Saved offer', status: 'draft', isActive: true, audiences: ['worker'], startsAt: new Date(+now - 60000), endsAt: new Date(+now + 3600000), thumbnailMediaId: oid() }],
    users: [{ _id: workerId, userType: 'worker', status: 'active', isActive: true, createdAt: new Date(+now - 60000) }, { _id: customerId, userType: 'customer', status: 'active', isActive: true, createdAt: new Date(+now - 60000) }],
  })
  const actor = { user: { _id: adminId }, role: { permissions: [] } }
  const router = createPushCampaignRouter({ db, auth, storage: { isConfigured: true }, pushEnabled: true })
  await serve(router, actor, async base => {
    const send = () => fetch(base + '/banners/' + bannerId + '/publish-notify', { method: 'POST', headers: { origin: 'http://localhost:5173', 'content-type': 'application/json' }, body: '{}' })
    assert.equal((await send()).status, 403)
    actor.role.permissions.push('banners.publish')
    // Publishing validates persistent thumbnail media before queuing anything.
    assert.equal((await send()).status, 400)
    assert.equal((db.records().push_campaigns || []).length, 0)
    const thumbnailId = db.records().promotional_banners[0].thumbnailMediaId
    await db.collection('media_assets').insertOne({ _id: thumbnailId, visibility: 'public', uploadStatus: 'ready', isActive: true,
      storageProvider: 's3', storageKey: 'catalog/offer.jpg', publicUrl: 'https://assets.example.test/offer.jpg' })
    assert.equal((await send()).status, 200)
    assert.equal((await send()).status, 200)
  })
  // A valid offer has no required thumbnail; all published references still use existing validators.
  const offerId = oid()
  await db.collection('offers').insertOne({ _id: offerId, name: 'New offer', status: 'draft', isActive: true, discountType: 'fixed', value: 100, startsAt: new Date(+now - 60000), endsAt: new Date(+now + 3600000) })
  actor.role.permissions.push('offers.publish')
  await serve(router, actor, async base => {
    const send = () => fetch(base + '/offers/' + offerId + '/publish-notify', { method: 'POST', headers: { origin: 'http://localhost:5173', 'content-type': 'application/json' }, body: '{}' })
    assert.equal((await send()).status, 200)
    assert.equal((await send()).status, 200)
  })
  assert.equal(db.records().push_campaigns.length, 2)
  await expandPushCampaigns({ db }); await expandPushCampaigns({ db })
  assert.equal(db.records().notifications.length, 2)
  assert.equal(String(db.records().notifications.find(item => item.type === 'banner.published').recipientUserId), String(workerId))
  assert.equal(String(db.records().notifications.find(item => item.type === 'offer.published').recipientUserId), String(customerId))
  assert.equal(db.records().push_campaigns[0].status, 'completed')
})

test('scheduled campaigns wait; paused or expired content is never announced', async () => {
  const now = new Date(), entityId = oid(), campaignId = oid()
  const db = memoryDatabase({ offers: [{ _id: entityId, status: 'paused', isActive: true }],
    push_campaigns: [{ _id: campaignId, resource: 'offers', entityId, audiences: ['customer'], status: 'pending', startsAt: new Date(+now + 60000), createdAt: now, lastUserId: oid(), processedCount: 0 }] })
  await expandPushCampaigns({ db, now })
  assert.equal(db.records().push_campaigns[0].status, 'pending')
  await expandPushCampaigns({ db, now: new Date(+now + 120000) })
  assert.equal(db.records().push_campaigns[0].status, 'cancelled')
  assert.equal(db.records().notifications, undefined)
})

test('cancelling an assigned booking notifies both the customer and its worker', async () => {
  const f = fixture(), customerId = oid(), bookingId = oid()
  await f.db.collection('bookings').insertOne({ _id: bookingId, status: 'assigned', customerId, workerUserId: f.userId, assignmentStatus: 'assigned' })
  const actor = { user: { _id: oid() }, role: { permissions: ['bookings.cancel'] } }
  await serve(createWorkflowsRouter({ db: f.db, auth }), actor, async base => {
    const response = await fetch(base + '/bookings/' + bookingId + '/cancel', { method: 'POST', headers: { origin: 'http://localhost:5173', 'content-type': 'application/json' }, body: JSON.stringify({ reason: 'Customer requested cancellation' }) })
    assert.equal(response.status, 200)
  })
  const events = f.db.records().notifications.filter(item => item.type === 'booking.cancelled')
  assert.equal(events.length, 2)
  assert.deepEqual(events.map(item => String(item.recipientUserId)).sort(), [String(customerId), String(f.userId)].sort())
})

test('persisted preferences override profile defaults without changing booking records', async () => {
  const f=fixture();let sent=0
  f.db.records().notification_preferences=[{_id:f.userId,notificationsEnabled:false,marketingNotificationsEnabled:false}]
  await createNotificationDispatcher({db:f.db,now:f.now,provider:{async send(){sent++}}})()
  assert.equal(sent,0)
})

test('durable failed deliveries retry outside the inbox discovery window', async () => {
  const f=fixture();let calls=0
  const provider={async send(){if(++calls===1)throw Error('temporary outage')}}
  const dispatch=createNotificationDispatcher({db:f.db,now:f.now,provider})
  await dispatch();assert.equal(f.db.records().push_deliveries[0].status,'pending')
  f.advance(25*3600000)
  await dispatch();assert.equal(calls,2);assert.equal(f.db.records().push_deliveries[0].status,'sent')
})
