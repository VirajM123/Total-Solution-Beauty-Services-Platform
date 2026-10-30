const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const mongoose = require('mongoose')
const { memoryDatabase } = require('./admin-test-db.cjs')
const { createAdminOperationsRouter, validateSlot, createCompensation, createScheduling } = require('../src/platform/admin-operations')
const { createResourcesRouter } = require('../src/platform/resources.routes')
const { errorHandler } = require('../src/middleware/errorHandler')
const oid = () => new mongoose.Types.ObjectId()
const ids = { admin: oid(), customer: oid(), user: oid(), address: oid(), area: oid(), service: oid(), category: oid() }
const headers = { origin: 'http://localhost:5173', 'content-type': 'application/json', 'x-csrf-token': 'valid', 'x-idempotency-key': 'admin-test-operation-key-123' }
const policy = { key: 'business', isActive: true, bookingLeadMinutes: 60, slotMinutes: 30, assignmentTimeoutMinutes: 10 }
const future = '2036-10-21T10:00:00+05:30'
function seed() { return {
  customers: [{ _id: ids.customer, userId: ids.user, status: 'active', isActive: true }],
  users: [{ _id: ids.user, userType: 'customer', status: 'active', isActive: true }],
  auth_sessions: [{ _id: oid(), userId: ids.user, isActive: true }],
  customer_addresses: [{ _id: ids.address, customerId: ids.user, serviceAreaId: ids.area, line1: 'Test address', city: 'Latur', postalCode: '413512', isActive: true }],
  service_areas: [{ _id: ids.area, city: 'Latur', postalCodes: ['413512'], isActive: true, isServiceable: true, operatingHours: { opens: '09:00', closes: '18:00' } }],
  services: [{ _id: ids.service, categoryId: ids.category, status: 'published', isActive: true, name: 'Test service', pricePaise: 219900, durationMinutes: 60 }],
  service_categories: [{ _id: ids.category, status: 'published', isActive: true }], app_settings: [policy],
} }
function authentication(permissions) { return {
  requireAuthenticated(req, res, next) { req.auth = { user: { _id: ids.admin }, role: { roleCode: 'ADMIN', permissions } }; next() },
  requirePermission(permission) { return (req, res, next) => permissions.includes(permission) ? next() : res.status(403).json({ success: false }) },
  requireCsrf(req, res, next) { return req.get('x-csrf-token') === 'valid' ? next() : res.status(403).json({ success: false }) },
} }
async function serve(db, run, permissions = ['bookings.create', 'bookings.read', 'bookings.reschedule', 'payments.refund', 'payments.refund.approve', 'payments.refund.record', 'customers.create', 'workers.create', 'customers.update', 'customers.publish', 'settlements.approve']) {
  const app = express(); app.use(express.json())
  const auth = authentication(permissions)
  app.use(createAdminOperationsRouter({ db, auth }), createResourcesRouter({ db, auth }), errorHandler)
  const server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)) })
  try { await run('http://127.0.0.1:' + server.address().port) } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)) }
}
const bookingBody = () => ({ customerId: String(ids.customer), addressId: String(ids.address), cart: { serviceAreaId: String(ids.area), items: [{ serviceId: String(ids.service), quantity: 1 }] }, startsAt: future, method: 'cash' })
const post = (base, route, body, key) => fetch(base + route, { method: 'POST', headers: { ...headers, ...(key ? { 'x-idempotency-key': key } : {}) }, body: JSON.stringify(body) })
test('slot rules reject invalid hours, alignment, closing overflow, seconds and insufficient lead time', () => {
  const area = seed().service_areas[0]
  assert.equal(validateSlot(area, policy, future, 60).endsAt.toISOString(), '2036-10-21T05:30:00.000Z')
  for (const start of ['2036-10-21T10:01:00+05:30', '2036-10-21T17:30:00+05:30', '2036-10-21T10:00:01+05:30', '2000-01-01T10:00:00+05:30']) assert.throws(() => validateSlot(area, policy, start, 60))
  assert.throws(() => validateSlot({ ...area, operatingHours: { opens: '29:00', closes: '30:00' } }, policy, future, 60))
  assert.throws(() => validateSlot(area, null, future, 60))
})
test('admin booking snapshots server prices, replays safely, rejects key conflict and reschedules without repricing', async () => {
  const db = memoryDatabase(seed())
  await serve(db, async base => {
    const response = await post(base, '/bookings', bookingBody()); assert.equal(response.status, 201)
    const booking = (await response.json()).data
    assert.equal(booking.totalPaise, 219900); assert.equal(booking.paymentStatus, 'pending'); assert.equal(booking.assignmentStatus, 'searching')
    assert.equal((await post(base, '/bookings', bookingBody())).status, 201)
    assert.equal(db.records().bookings.length, 1)
    assert.equal((await post(base, '/bookings', { ...bookingBody(), method: 'upi' })).status, 409)
    db.records().services[0].pricePaise = 999999
    db.records().bookings[0].status = 'assigned'
    await db.collection('booking_assignments').insertOne({_id:oid(),bookingId:db.records().bookings[0]._id,status:'assigned',reason:'assigned-history-regression'})
    const body = { startsAt: '2036-10-22T11:00:00+05:30', reason: 'Customer requested change' }
    assert.equal((await post(base, '/bookings/' + booking._id + '/reschedule', body, 'reschedule-test-key-123')).status, 200)
    assert.equal(db.records().bookings[0].totalPaise, 219900)
    assert.equal(db.records().booking_assignments[0].status, 'superseded')
    assert.equal((await post(base, '/bookings/' + booking._id + '/reschedule', body, 'reschedule-test-key-123')).status, 200)
    assert.equal(db.records().booking_events.filter(e => e.type === 'rescheduled').length, 1)
  })
})
test('booking rejects restricted customers, foreign addresses, client prices and unpublished services', async () => {
  for (const scenario of ['restricted', 'foreign-address', 'overpost', 'draft']) {
    const data = seed(), body = bookingBody()
    if (scenario === 'restricted') data.customers[0].status = 'suspended'
    if (scenario === 'foreign-address') data.customer_addresses[0].customerId = oid()
    if (scenario === 'overpost') body.totalPaise = 1
    if (scenario === 'draft') data.services[0].status = 'draft'
    const db = memoryDatabase(data)
    await serve(db, async base => { assert.ok((await post(base, '/bookings', body)).status >= 400); assert.equal((db.records().bookings || []).length, 0) })
  }
})
test('refunds preserve payment evidence, replay safely and reject over-refunding', async () => {
  const paymentId = oid(), db = memoryDatabase({ payments: [{ _id: paymentId, bookingId: oid(), status: 'paid', amountPaise: 10000, verification: 'authorized_reconciliation' }] })
  await serve(db, async base => {
    const body = { amountPaise: 6000, reference: 'BANK-REFUND-001', reason: 'Partial refund completed externally' }
    assert.equal((await post(base, '/payments/' + paymentId + '/refunds', body)).status, 201)
    assert.equal((await post(base, '/payments/' + paymentId + '/refunds', body)).status, 201)
    assert.equal(db.records().payments[0].refundedPaise, 6000)
    assert.equal((await post(base, '/payments/' + paymentId + '/refunds', { ...body, reference: 'BANK-REFUND-002' }, 'second-refund-key-123')).status, 409)
    assert.equal(db.records().payments[0].refundedPaise, 6000)
  })
})
test('customer profile edits do not suspend the account; status changes revoke sessions', async () => {
  const db = memoryDatabase(seed())
  await serve(db, async base => {
    const update = await fetch(base + '/customers/' + ids.customer, { method: 'PATCH', headers, body: JSON.stringify({ fullName: 'Updated name' }) })
    assert.equal(update.status, 200); assert.equal(db.records().users[0].isActive, true); assert.equal(db.records().auth_sessions[0].isActive, true)
    const suspend = await fetch(base + '/customers/' + ids.customer + '/status', { method: 'PATCH', headers, body: JSON.stringify({ status: 'suspended' }) })
    assert.equal(suspend.status, 200); assert.equal(db.records().users[0].isActive, false); assert.equal(db.records().auth_sessions[0].isActive, false)
  })
})
test('new admin operations reject missing permission and invalid CSRF', async () => {
  const db = { collection() { throw Error('Must not access database') } }
  await serve(db, async base => assert.equal((await post(base, '/bookings', bookingBody())).status, 403), [])
  await serve(db, async base => assert.equal((await fetch(base + '/bookings', { method: 'POST', headers: { ...headers, 'x-csrf-token': '' }, body: JSON.stringify(bookingBody()) })).status, 403))
})
test('compensation requires snapshots; scheduling requires an explicit availability window', async () => {
  const compensation = createCompensation()
  assert.deepEqual(await compensation.calculate({ jobs: [{ compensationPaise: 100 }, { compensationPaise: 200 }] }), { earningsPaise: 300, cashRemittedPaise: 0 })
  await assert.rejects(compensation.calculate({ jobs: [{}] }))
  const db = memoryDatabase(), worker = { _id: oid() }, booking = { startsAt: new Date('2036-10-21T04:30:00Z'), endsAt: new Date('2036-10-21T05:30:00Z') }
  assert.equal(await createScheduling({ db }).canAssign({ worker, booking }), false)
  assert.equal(await createScheduling({ db }).canAssign({ worker: { ...worker, isOnline: true }, booking }), true)
})
test('online workers can reserve a matching customer booking without a separate availability window', async () => {
  const areaId = oid(), serviceId = oid(), workerId = oid()
  const startsAt = new Date(Date.now() + 60 * 60 * 1000)
  const db = memoryDatabase({
    service_areas: [{ _id: areaId, isActive: true, isServiceable: true }],
    workers: [{
      _id: workerId,
      status: 'approved',
      isActive: true,
      isOnline: true,
      serviceAreaIds: [areaId],
      serviceIds: [serviceId],
    }],
  })
  assert.equal(await createScheduling({ db }).reserve({
    startsAt,
    endsAt: new Date(startsAt.getTime() + 30 * 60 * 1000),
    serviceAreaId: areaId,
    items: [{ serviceId }],
  }), true)
})
test('admin customer creation persists an unverified account, replays, and rejects duplicate identity', async () => {
  const db = memoryDatabase()
  await serve(db, async base => {
    const body = { fullName: 'Test customer', mobileNumber: '+919876543210', email: 'customer@example.test' }
    assert.equal((await post(base, '/customers', body)).status, 201)
    assert.equal((await post(base, '/customers', body)).status, 201)
    assert.equal(db.records().users.length, 1)
    assert.equal(db.records().users[0].mobileVerifiedAt, undefined)
    assert.equal(db.records().users[0].passwordHash, undefined)
    assert.equal((await post(base, '/customers', body, 'another-create-key-123')).status, 409)
  })
})
test('settlement replay does not spend balances twice and overpayment rolls back', async () => {
  const workerId = oid(), db = memoryDatabase({ workers: [{ _id: workerId, status: 'approved', isActive: true }], bookings: [{ _id: oid(), workerId, status: 'completed', compensationPaise: 1000 }], payments: [{ _id: oid(), workerId, status: 'paid', method: 'cash', verification: 'authorized_reconciliation', amountPaise: 5000 }] })
  await serve(db, async base => {
    const body = { workerId: String(workerId), cashRemittedPaise: 3000, compensationPaidPaise: 500, reference: 'HANDOVER-ONE', note: 'Isolated test' }
    assert.equal((await post(base, '/settlements/record', body)).status, 201)
    assert.equal((await post(base, '/settlements/record', body)).status, 201)
    assert.equal(db.records().worker_settlements.length, 1)
    assert.equal((await post(base, '/settlements/record', { ...body, reference: 'HANDOVER-TWO' }, 'another-settlement-key-123')).status, 409)
    assert.equal(db.records().worker_settlements.length, 1)
  })
})
test('refund review reserves balance, rejection releases it, and completion requires approval', async () => {
  const paymentId = oid(), db = memoryDatabase({ payments: [{ _id: paymentId, status: 'paid', amountPaise: 10000, verification: 'authorized_reconciliation' }] })
  await serve(db, async base => {
    const request = await post(base, '/payments/' + paymentId + '/refund-requests', { amountPaise: 6000, reason: 'Requested partial refund' })
    assert.equal(request.status, 201); const refund = (await request.json()).data
    assert.equal(db.records().payments[0].refundReservedPaise, 6000)
    assert.equal((await post(base, '/payments/' + paymentId + '/refund-requests', { amountPaise: 6000, reason: 'Another refund' }, 'another-request-key-123')).status, 409)
    assert.equal((await post(base, '/refunds/' + refund._id + '/record', { reference: 'BANK-REF-001' }, 'record-before-approval-123')).status, 404)
    assert.equal((await post(base, '/refunds/' + refund._id + '/approve', {}, 'approve-refund-key-123')).status, 200)
    assert.equal((await post(base, '/refunds/' + refund._id + '/record', { reference: 'BANK-REF-001' }, 'record-refund-key-123')).status, 200)
    assert.equal((await post(base, '/refunds/' + refund._id + '/record', { reference: 'BANK-REF-001' }, 'record-refund-key-123')).status, 200)
    assert.equal(db.records().payments[0].refundedPaise, 6000); assert.equal(db.records().payments[0].refundReservedPaise, 0)
    const next = await post(base, '/payments/' + paymentId + '/refund-requests', { amountPaise: 4000, reason: 'Request remaining balance' }, 'last-refund-request-123')
    const last = (await next.json()).data
    assert.equal((await post(base, '/refunds/' + last._id + '/reject', { note: 'Request rejected after review' }, 'reject-refund-key-123')).status, 200)
    assert.equal(db.records().payments[0].refundReservedPaise, 0)
  })
})
test('package booking stores package price and component snapshots independently of later catalog edits', async () => {
  const data = seed(), secondId = oid(), packageId = oid()
  data.services.push({ ...data.services[0], _id: secondId, name: 'Second service', pricePaise: 10000, durationMinutes: 30 })
  data.service_packages = [{ _id: packageId, name: 'Test package', status: 'published', isActive: true, pricePaise: 200000, components: [{ serviceId: ids.service, quantity: 1 }, { serviceId: secondId, quantity: 1 }] }]
  const db = memoryDatabase(data)
  await serve(db, async base => {
    const body = { ...bookingBody(), cart: { serviceAreaId: String(ids.area), packageId: String(packageId) } }
    const response = await post(base, '/bookings', body)
    assert.equal(response.status, 201); const booking = (await response.json()).data
    assert.equal(booking.totalPaise, 200000); assert.equal(booking.durationMinutes, 90); assert.equal(booking.items.length, 2)
    db.records().service_packages[0].pricePaise = 1
    assert.equal(db.records().bookings[0].packageSnapshot.pricePaise, 200000)
  })
})


test('admin-punched bookings create one persisted admin alert and customer confirmation, including replay', async () => {
  const data = seed(), roleId = oid()
  data.roles = [{ _id: roleId, isActive: true, permissions: ['bookings.read'] }]
  data.users.push({ _id: ids.admin, roleId, userType: 'admin', status: 'active', isActive: true })
  const db = memoryDatabase(data)
  await serve(db, async base => {
    assert.equal((await post(base, '/bookings', bookingBody())).status, 201)
    assert.equal((await post(base, '/bookings', bookingBody())).status, 201)
  })
  const alerts = db.records().notifications
  assert.equal(alerts.filter(item => item.type === 'booking.created' && String(item.recipientUserId) === String(ids.admin)).length, 1)
  assert.equal(alerts.filter(item => item.type === 'booking.confirmed' && String(item.recipientUserId) === String(ids.user)).length, 1)
})
