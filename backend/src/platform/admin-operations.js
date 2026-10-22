const { z } = require('zod')
const { idSchema, id, money, fail, reply, handler, protectedRouter, atomic, requestIdentity, compareAndSet, requireRecord, list } = require('./core')
const { cartSchema, quote, reserveCoupon, paise, discountFor } = require('./business')
const reason = z.string().trim().min(3).max(1000)
const addressSchema = z.object({ line1: z.string().trim().min(3).max(200), line2: z.string().trim().max(200).default(''), city: z.string().trim().min(1).max(100), postalCode: z.string().regex(/^\d{6}$/), serviceAreaId: idSchema }).strict()
const adminCartSchema = z.union([cartSchema, z.object({ packageId: idSchema, serviceAreaId: idSchema, couponCode: z.string().regex(/^[A-Z0-9_-]{3,24}$/).optional() }).strict()])

async function adminQuote(db, customerId, cart, session) {
  if (!cart.packageId) {
    const result = await quote(db, customerId, cart, session)
    if (result.offerId) {
      const offer = await requireRecord(db, 'offers', result.offerId, session)
      if (offer.packageIds?.length) fail(400, 'COUPON_INELIGIBLE', 'This coupon requires an eligible package.')
    }
    return result
  }
  const pkg = await requireRecord(db, 'service_packages', cart.packageId, session, { status: 'published', isActive: true })
  const base = await quote(db, customerId, { serviceAreaId: cart.serviceAreaId, items: pkg.components.map(c => ({ serviceId: String(c.serviceId), quantity: c.quantity })) }, session)
  const subtotal = paise(pkg.pricePaise)
  let offer, discount = 0
  if (cart.couponCode) {
    const now = new Date()
    offer = await db.collection('offers').findOne({ code: cart.couponCode, status: 'published', isActive: true, startsAt: { $lte: now }, endsAt: { $gt: now } }, { session })
    if (!offer || subtotal < paise(offer.minimumOrderPaise)) fail(400, 'COUPON_INELIGIBLE', 'Coupon eligibility or minimum spend is unmet.')
    if (offer.packageIds?.length && !offer.packageIds.some(p => String(p) === String(pkg._id)) || offer.serviceIds?.length && base.items.some(i => !offer.serviceIds.some(s => String(s) === String(i.serviceId))) || offer.categoryIds?.length && base.items.some(i => !offer.categoryIds.some(c => String(c) === String(i.categoryId)))) fail(400, 'COUPON_INELIGIBLE', 'Coupon excludes this package or one of its components.')
    if ((offer.redeemedCount || 0) >= offer.totalLimit || await db.collection('coupon_redemptions').countDocuments({ offerId: offer._id, customerId }, { session }) >= offer.perCustomerLimit) fail(409, 'COUPON_EXHAUSTED', 'Coupon usage limit reached.')
    if (offer.newCustomerOnly && await db.collection('bookings').findOne({ customerId }, { session })) fail(400, 'COUPON_INELIGIBLE', 'Coupon is for a first-time customer.')
    discount = discountFor(offer, subtotal)
  }
  return { ...base, subtotalPaise: subtotal, totalPaise: subtotal - discount, discountPaise: discount, offerId: offer?._id, packageId: pkg._id, packageSnapshot: { name: pkg.name, pricePaise: subtotal, components: pkg.components } }
}

function validateSlot(area, policy, startsAt, durationMinutes, now = Date.now()) {
  const minutes = value => {
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value || '')) fail(503, 'POLICY_NOT_CONFIGURED', 'Valid operating hours are required.')
    return Number(value.slice(0, 2)) * 60 + Number(value.slice(3))
  }
  if (!policy || !Number.isInteger(policy.slotMinutes) || policy.slotMinutes < 5 || !Number.isInteger(policy.bookingLeadMinutes) || policy.bookingLeadMinutes < 0 || !Number.isInteger(policy.assignmentTimeoutMinutes) || policy.assignmentTimeoutMinutes < 1) fail(503, 'POLICY_NOT_CONFIGURED', 'A complete business policy is required.')
  const start = new Date(startsAt), local = new Date(start.getTime() + 330 * 60000)
  const hours = policy.operatingHours || area.operatingHours
  const opens = minutes(hours?.opens), closes = minutes(hours?.closes)
  const minute = local.getUTCHours() * 60 + local.getUTCMinutes()
  if (!Number.isFinite(start.getTime()) || start.getTime() < now + policy.bookingLeadMinutes * 60000 || local.getUTCSeconds() || local.getUTCMilliseconds() || !Number.isInteger(durationMinutes) || durationMinutes < 1 || minute < opens || minute + durationMinutes > closes || (minute - opens) % policy.slotMinutes) fail(400, 'INVALID_SLOT', 'Select a future slot within operating hours and the configured slot interval.')
  return { startsAt: start, endsAt: new Date(start.getTime() + durationMinutes * 60000) }
}

async function customerRecord(db, resourceId, session) {
  const customer = await requireRecord(db, 'customers', resourceId, session, { isActive: true, status: 'active' })
  // Existing application records use user IDs as booking customer IDs.
  return { customer, customerId: customer.userId || customer._id }
}

async function replay(db, collection, identity, session) {
  const previous = await db.collection(collection).findOne({ _id: identity._id }, { session })
  if (previous && previous.requestHash !== identity.requestHash) fail(409, 'IDEMPOTENCY_CONFLICT', 'This key was used with a different request.')
  return previous
}

function createAdminOperationsRouter({ db, auth, storage }) {
  const router = protectedRouter(auth)
  router.get('/integrations', auth.requirePermission('settings.read'), handler(async (req, res) => {
    reply(req, res, { items: [{ _id: 'runtime', databaseConnected: true, adminAuthentication: true, storageConfigured: storage?.isConfigured === true, paymentProviderConfigured: false, appOtpConfigured: false, appNotificationsConfigured: false }], pagination: { page: 1, limit: 1, total: 1, pages: 1 } })
  }))
  for (const kind of ['customer', 'worker']) {
    const resource = kind === 'customer' ? 'customers' : 'workers'
    router.post('/' + resource, auth.requirePermission(resource + '.create'), handler(async (req, res) => {
      const input = z.object({ fullName: z.string().trim().min(2).max(120), mobileNumber: z.string().regex(/^\+[1-9]\d{7,14}$/), email: z.email().max(254).optional(), notes: z.string().max(2000).optional(), experienceYears: z.number().min(0).max(80).optional(), documents: z.array(z.object({ mediaAssetId: idSchema, kind: z.enum(['identity', 'certificate']) }).strict()).max(10).optional() }).strict().parse(req.body)
      if (kind === 'customer' && input.documents?.length) fail(400, 'INVALID_DOCUMENT', 'Customer creation does not accept verification documents.')
      if (kind === 'worker' && !input.documents?.some(d => d.kind === 'identity')) fail(400, 'IDENTITY_REQUIRED', 'Link a persistent private identity document.')
      const identity = requestIdentity(req, 'admin.' + kind + '.create')
      const result = await atomic(db, req, kind + '.create', resource, async session => {
        const previous = await replay(db, resource, identity, session); if (previous) return previous
        for (const document of input.documents || []) await requireRecord(db, 'media_assets', document.mediaAssetId, session, { uploadedBy: req.auth.user._id, visibility: 'private', uploadStatus: 'ready', isActive: true })
        if (await db.collection('users').findOne({ mobileNumber: input.mobileNumber }, { session })) fail(409, 'IDENTITY_EXISTS', 'This mobile number already belongs to an account.')
        const user = { _id: identity._id, userType: kind, fullName: input.fullName, mobileNumber: input.mobileNumber, ...(input.email ? { email: input.email.toLowerCase() } : {}), status: 'active', isActive: true, authProvider: 'admin_created', createdAt: new Date(), schemaVersion: 1 }
        // Contact verification timestamps intentionally remain absent.
        await db.collection('users').insertOne(user, { session })
        const record = { ...identity, userId: user._id, fullName: user.fullName, mobileNumber: user.mobileNumber, ...(user.email ? { email: user.email } : {}), notes: input.notes || '', status: kind === 'worker' ? 'pending' : 'active', ...(kind === 'worker' ? { experienceYears: input.experienceYears || 0, serviceIds: [], serviceAreaIds: [], isOnline: false } : {}), isActive: true, createdAt: new Date(), _revision: 0, schemaVersion: 1 }
        await db.collection(resource).insertOne(record, { session })
        for (const document of input.documents || []) await db.collection('worker_documents').insertOne({ _id: new (require('mongoose').Types.ObjectId)(), workerId: record._id, mediaAssetId: id(document.mediaAssetId), kind: document.kind, isActive: true, createdAt: new Date() }, { session })
        return record
      }); reply(req, res, result, 201)
    }))
  }
  router.post('/workers/:id/documents', auth.requirePermission('workers.update'), handler(async (req, res) => {
    const input = z.object({ mediaAssetId: idSchema, kind: z.enum(['identity', 'certificate']) }).strict().parse(req.body)
    const identity = requestIdentity(req, 'admin.worker.document.' + req.params.id)
    const result = await atomic(db, req, 'worker.document.link', 'worker_documents', async session => {
      const previous = await replay(db, 'worker_documents', identity, session); if (previous) return previous
      const worker = await requireRecord(db, 'workers', req.params.id, session)
      await requireRecord(db, 'media_assets', input.mediaAssetId, session, { uploadedBy: req.auth.user._id, visibility: 'private', uploadStatus: 'ready', isActive: true })
      const record = { ...identity, workerId: worker._id, mediaAssetId: id(input.mediaAssetId), kind: input.kind, isActive: true, createdAt: new Date() }
      await db.collection('worker_documents').insertOne(record, { session }); return record
    }); reply(req, res, result, 201)
  }))
  router.post('/workers/:id/availability', auth.requirePermission('workers.update'), handler(async (req, res) => {
    const input = z.object({ startsAt: z.iso.datetime({ offset: true }), endsAt: z.iso.datetime({ offset: true }), reason }).strict().refine(v => new Date(v.startsAt) < new Date(v.endsAt)).parse(req.body)
    const identity = requestIdentity(req, 'admin.worker.availability.' + req.params.id)
    const result = await atomic(db, req, 'worker.availability.record', 'worker_availability', async session => {
      const previous = await replay(db, 'worker_availability', identity, session); if (previous) return previous
      const worker = await requireRecord(db, 'workers', req.params.id, session, { status: 'approved', isActive: true })
      const record = { ...identity, workerId: worker._id, startsAt: new Date(input.startsAt), endsAt: new Date(input.endsAt), reason: input.reason, source: 'admin_recorded', isActive: true, createdAt: new Date() }
      await db.collection('worker_availability').insertOne(record, { session }); return record
    }); reply(req, res, result, 201)
  }))
  router.patch('/workers/:id/compensation', auth.requirePermission('workers.compensation.update'), handler(async (req, res) => {
    const input = z.object({ amountPaise: money, effectiveFrom: z.iso.datetime({ offset: true }), reason }).strict().parse(req.body)
    const result = await atomic(db, req, 'worker.compensation.update', 'workers', async session => {
      const before = await requireRecord(db, 'workers', req.params.id, session)
      return compareAndSet(db, 'workers', before, { compensationRule: { amountPaise: input.amountPaise, effectiveFrom: new Date(input.effectiveFrom), reason: input.reason } }, session)
    }); reply(req, res, result)
  }))
  router.post('/settlements/record', auth.requirePermission('settlements.approve'), handler(async (req, res) => {
    const input = z.object({ workerId: idSchema, cashRemittedPaise: money, compensationPaidPaise: money, reference: reason, note: z.string().max(1000).default('') }).strict().refine(v => v.cashRemittedPaise > 0 || v.compensationPaidPaise > 0).parse(req.body)
    const identity = requestIdentity(req, 'admin.settlement.record')
    const result = await atomic(db, req, 'settlement.record', 'worker_settlements', async session => {
      const previous = await replay(db, 'worker_settlements', identity, session); if (previous) return previous
      const worker = await requireRecord(db, 'workers', input.workerId, session)
      // Lock worker so concurrent handovers cannot spend the same outstanding balance.
      await compareAndSet(db, 'workers', worker, { lastSettlementCheckAt: new Date() }, session)
      const jobs = await db.collection('bookings').find({ workerId: worker._id, status: 'completed' }, { session }).toArray()
      const payments = await db.collection('payments').find({ workerId: worker._id, method: 'cash', status: 'paid', verification: { $in: ['authorized_reconciliation', 'provider_verified'] } }, { session }).toArray()
      const history = await db.collection('worker_settlements').find({ workerId: worker._id, status: 'paid' }, { session }).toArray()
      const sum = (records, field) => records.reduce((n, record) => { const total = n + paise(record[field] || 0); if (!Number.isSafeInteger(total)) fail(400, 'INVALID_MONEY', 'Balance exceeds supported limits.'); return total }, 0)
      if (jobs.some(job => job.compensationPaise === undefined)) fail(409, 'COMPENSATION_SNAPSHOT_MISSING', 'A completed booking needs its compensation snapshot reconciled.')
      const earnings = sum(jobs, 'compensationPaise'), cash = sum(payments, 'amountPaise')
      if (input.cashRemittedPaise > cash - sum(history, 'cashRemittedPaise') || input.compensationPaidPaise > earnings - sum(history, 'compensationPaidPaise')) fail(409, 'SETTLEMENT_LIMIT', 'Amounts exceed the outstanding cash or compensation balance.')
      if (await db.collection('worker_settlements').findOne({ reference: input.reference }, { session })) fail(409, 'DUPLICATE_REFERENCE', 'This reconciliation reference is already recorded.')
      const refId = id(require('node:crypto').createHash('sha256').update('settlement.reference:' + input.reference).digest('hex').slice(0, 24))
      await db.collection('audit_logs').insertOne({ _id: refId, action: 'settlement.reference', createdAt: new Date(), entityType: 'worker_settlements', entityId: identity._id }, { session })
      const now = new Date()
      const record = { ...identity, workerId: worker._id, date: new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(now), cashRemittedPaise: input.cashRemittedPaise, compensationPaidPaise: input.compensationPaidPaise, earningsPaise: input.compensationPaidPaise, reference: input.reference, note: input.note, status: 'paid', verification: 'authorized_reconciliation', settledBy: req.auth.user._id, settledAt: now, createdAt: now, isActive: true }
      await db.collection('worker_settlements').insertOne(record, { session }); return record
    }); reply(req, res, result, 201)
  }))
  router.get('/customers/:id/addresses', auth.requirePermission('customers.read'), handler(async (req, res) => {
    const { customerId } = await customerRecord(db, req.params.id)
    reply(req, res, await list(db, 'customer_addresses', req.query, { scope: { customerId, isActive: true }, fields: ['line1', 'city'] }))
  }))
  router.post('/customers/:id/addresses', auth.requirePermission('customers.update'), handler(async (req, res) => {
    const input = addressSchema.parse(req.body), identity = requestIdentity(req, 'admin.address.' + req.params.id)
    const result = await atomic(db, req, 'customer.address.create', 'customer_addresses', async session => {
      const previous = await replay(db, 'customer_addresses', identity, session); if (previous) return previous
      const { customerId } = await customerRecord(db, req.params.id, session)
      const area = await requireRecord(db, 'service_areas', input.serviceAreaId, session, { isActive: true, isServiceable: true })
      if (!area.postalCodes.includes(input.postalCode) || area.city !== input.city) fail(400, 'INVALID_ADDRESS', 'Address does not match its service area.')
      const record = { ...identity, ...input, customerId, serviceAreaId: area._id, isActive: true, createdAt: new Date(), _revision: 0 }
      await db.collection('customer_addresses').insertOne(record, { session }); return record
    }); reply(req, res, result, 201)
  }))
  const bookingSchema = z.object({ customerId: idSchema, addressId: idSchema, cart: adminCartSchema, startsAt: z.iso.datetime({ offset: true }), method: z.enum(['cash', 'upi']) }).strict()
  router.post('/bookings/quote', auth.requirePermission('bookings.create'), handler(async (req, res) => {
    const input = z.object({ customerId: idSchema, cart: adminCartSchema }).strict().parse(req.body)
    const { customerId } = await customerRecord(db, input.customerId)
    reply(req, res, await adminQuote(db, customerId, input.cart))
  }))
  router.post('/bookings', auth.requirePermission('bookings.create'), handler(async (req, res) => {
    const input = bookingSchema.parse(req.body), identity = requestIdentity(req, 'admin.booking.create')
    const result = await atomic(db, req, 'booking.create', 'bookings', async session => {
      const previous = await replay(db, 'bookings', identity, session); if (previous) return previous
      const { customerId } = await customerRecord(db, input.customerId, session)
      const address = await requireRecord(db, 'customer_addresses', input.addressId, session, { customerId, isActive: true })
      if (String(address.serviceAreaId) !== input.cart.serviceAreaId) fail(400, 'INVALID_ADDRESS', 'Address and service area must match.')
      const priced = await adminQuote(db, customerId, input.cart, session)
      const area = await requireRecord(db, 'service_areas', priced.serviceAreaId, session, { isActive: true, isServiceable: true })
      if (!area.postalCodes.includes(address.postalCode)) fail(400, 'INVALID_ADDRESS', 'Address is outside the service area.')
      const policy = await db.collection('app_settings').findOne({ key: 'business', isActive: true }, { session })
      const slot = validateSlot(area, policy, input.startsAt, priced.durationMinutes)
      const record = { ...identity, ...priced, ...slot, customerId, customerProfileId: id(input.customerId), addressSnapshot: address, assignmentTimeoutMinutes: policy.assignmentTimeoutMinutes, status: 'confirmed', assignmentStatus: 'searching', paymentStatus: 'pending', paymentMethod: input.method, createdAt: new Date(), isActive: true, schemaVersion: 1, _revision: 0 }
      await reserveCoupon(db, session, priced, customerId, record._id)
      await db.collection('bookings').insertOne(record, { session })
      await db.collection('booking_events').insertOne({ bookingId: record._id, type: 'confirmed', actorUserId: req.auth.user._id, createdAt: new Date() }, { session })
      return record
    }); reply(req, res, result, 201)
  }))
  router.get('/bookings/:id/events', auth.requirePermission('bookings.read'), handler(async (req, res) => {
    await requireRecord(db, 'bookings', req.params.id)
    reply(req, res, await list(db, 'booking_events', req.query, { scope: { bookingId: id(req.params.id) }, fields: ['type'] }))
  }))
  router.post('/bookings/:id/reschedule', auth.requirePermission('bookings.reschedule'), handler(async (req, res) => {
    const input = z.object({ startsAt: z.iso.datetime({ offset: true }), reason }).strict().parse(req.body)
    const identity = requestIdentity(req, 'admin.reschedule.' + req.params.id)
    const result = await atomic(db, req, 'booking.reschedule', 'booking_events', async session => {
      const previous = await replay(db, 'booking_events', identity, session); if (previous) return previous
      const before = await requireRecord(db, 'bookings', req.params.id, session)
      if (!['confirmed', 'assigned'].includes(before.status)) fail(409, 'INVALID_TRANSITION', 'Only confirmed or assigned bookings may be rescheduled.')
      const area = await requireRecord(db, 'service_areas', before.serviceAreaId, session, { isActive: true, isServiceable: true })
      const policy = await db.collection('app_settings').findOne({ key: 'business', isActive: true }, { session })
      const slot = validateSlot(area, policy, input.startsAt, before.durationMinutes)
      await compareAndSet(db, 'bookings', before, { ...slot, status: 'confirmed', assignmentStatus: 'searching', workerId: null, workerUserId: null, assignmentId: null }, session)
      await db.collection('booking_assignments').updateMany({ bookingId: before._id, status: { $in: ['offered', 'accepted'] } }, { $set: { status: 'superseded', updatedAt: new Date() } }, { session })
      const event = { ...identity, bookingId: before._id, type: 'rescheduled', reason: input.reason, ...slot, actorUserId: req.auth.user._id, createdAt: new Date() }
      await db.collection('booking_events').insertOne(event, { session }); return event
    }); reply(req, res, result)
  }))
  router.get('/payments/:id/receipt', auth.requirePermission('payments.read'), handler(async (req, res) => {
    const p = await requireRecord(db, 'payments', req.params.id, undefined, { status: 'paid' })
    reply(req, res, { _id: p._id, bookingId: p.bookingId, amountPaise: p.amountPaise, method: p.method, paidAt: p.paidAt, reference: p.evidenceReference, verification: p.verification })
  }))
  router.get('/refunds', auth.requirePermission('payments.read'), handler(async (req, res) => reply(req, res, await list(db, 'payment_events', req.query, { scope: { type: 'refund_request' }, fields: ['reason', 'reference'] }))))
  router.post('/payments/:id/refund-requests', auth.requirePermission('payments.refund'), handler(async (req, res) => {
    const input = z.object({ amountPaise: money.refine(v => v > 0), reason }).strict().parse(req.body)
    const identity = requestIdentity(req, 'admin.refund.request.' + req.params.id)
    const result = await atomic(db, req, 'refund.request', 'payment_events', async session => {
      const previous = await replay(db, 'payment_events', identity, session); if (previous) return previous
      const payment = await requireRecord(db, 'payments', req.params.id, session, { status: 'paid', verification: { $in: ['authorized_reconciliation', 'provider_verified'] } })
      const reserved = paise(payment.refundReservedPaise || 0)
      if (input.amountPaise > paise(payment.amountPaise) - paise(payment.refundedPaise || 0) - reserved) fail(409, 'REFUND_LIMIT', 'Refund exceeds the unreserved balance.')
      await compareAndSet(db, 'payments', payment, { refundReservedPaise: reserved + input.amountPaise }, session)
      const record = { ...identity, ...input, type: 'refund_request', status: 'requested', paymentId: payment._id, bookingId: payment.bookingId, requestedBy: req.auth.user._id, createdAt: new Date(), _revision: 0 }
      await db.collection('payment_events').insertOne(record, { session }); return record
    }); reply(req, res, result, 201)
  }))
  for (const action of ['approve', 'reject', 'record']) router.post('/refunds/:id/' + action, auth.requirePermission('payments.refund.' + (action === 'record' ? 'record' : 'approve')), handler(async (req, res) => {
    const input = z.object({ note: z.string().trim().max(1000).default(''), reference: z.string().trim().max(100).optional() }).strict().parse(req.body)
    if (action === 'reject' && input.note.length < 3 || action === 'record' && (!input.reference || input.reference.length < 3)) fail(400, 'EVIDENCE_REQUIRED', 'A rejection reason or completed refund reference is required.')
    const identity = requestIdentity(req, 'admin.refund.' + action + '.' + req.params.id)
    const result = await atomic(db, req, 'refund.' + action, 'payment_events', async session => {
      const previous = await replay(db, 'payment_events', identity, session); if (previous) return previous
      const refund = await requireRecord(db, 'payment_events', req.params.id, session, { type: 'refund_request', status: action === 'record' ? 'approved' : 'requested' })
      const changes = { status: { approve: 'approved', reject: 'rejected', record: 'refunded' }[action], reviewNote: input.note, reviewedBy: req.auth.user._id }
      if (action !== 'approve') {
        const payment = await requireRecord(db, 'payments', refund.paymentId, session)
        const reserved = paise(payment.refundReservedPaise || 0), amount = paise(refund.amountPaise)
        if (reserved < amount) fail(409, 'REFUND_RESERVATION_MISSING', 'Refund reservation must be reconciled first.')
        const paymentChanges = { refundReservedPaise: reserved - amount }
        if (action === 'record') {
          if (paise(payment.refundedPaise || 0) + amount > paise(payment.amountPaise)) fail(409, 'REFUND_LIMIT', 'Refund exceeds the verified collection.')
          const referenceId = id(require('node:crypto').createHash('sha256').update('refund:' + input.reference).digest('hex').slice(0, 24))
          await db.collection('payment_events').insertOne({ _id: referenceId, type: 'refund.reference', paymentId: payment._id, createdAt: new Date() }, { session })
          paymentChanges.refundedPaise = paise(payment.refundedPaise || 0) + amount
          changes.reference = input.reference; changes.completedAt = new Date(); changes.verification = 'authorized_reconciliation'
        }
        await compareAndSet(db, 'payments', payment, paymentChanges, session)
      }
      const updated = await compareAndSet(db, 'payment_events', refund, changes, session)
      const operation = { ...identity, type: 'refund_operation', refundId: refund._id, action, result: updated, createdAt: new Date() }
      await db.collection('payment_events').insertOne(operation, { session }); return operation
    }); reply(req, res, result.result || result)
  }))
  router.post('/payments/:id/refunds', auth.requirePermission('payments.refund'), handler(async (req, res) => {
    // Records a completed external refund; never claims to initiate a provider transfer.
    const input = z.object({ amountPaise: money.refine(v => v > 0), reference: reason, reason }).strict().parse(req.body)
    const identity = requestIdentity(req, 'admin.refund.' + req.params.id)
    const result = await atomic(db, req, 'payment.refund.record', 'payment_events', async session => {
      const previous = await replay(db, 'payment_events', identity, session); if (previous) return previous
      const payment = await requireRecord(db, 'payments', req.params.id, session, { status: 'paid', verification: { $in: ['authorized_reconciliation', 'provider_verified'] } })
      const refunded = paise(payment.refundedPaise || 0)
      if (input.amountPaise > paise(payment.amountPaise) - refunded - paise(payment.refundReservedPaise || 0)) fail(409, 'REFUND_LIMIT', 'Refund exceeds the remaining verified collection.')
      const referenceId = id(require('node:crypto').createHash('sha256').update('refund:' + input.reference).digest('hex').slice(0, 24))
      await db.collection('payment_events').insertOne({ _id: referenceId, type: 'refund.reference', paymentId: payment._id, createdAt: new Date() }, { session })
      await compareAndSet(db, 'payments', payment, { refundedPaise: refunded + input.amountPaise }, session)
      const event = { ...identity, ...input, paymentId: payment._id, bookingId: payment.bookingId, type: 'refund_recorded', verification: 'authorized_reconciliation', actorUserId: req.auth.user._id, createdAt: new Date() }
      await db.collection('payment_events').insertOne(event, { session }); return event
    }); reply(req, res, result, 201)
  }))
  return router
}

function createScheduling({ db }) {
  return { async canAssign({ worker, booking, session }) {
    const windows = await db.collection('worker_availability').find({ workerId: worker._id, isActive: true, startsAt: { $lte: booking.startsAt }, endsAt: { $gte: booking.endsAt } }, { session }).toArray()
    // Availability must be explicitly recorded; admin cannot manufacture worker consent.
    return windows.length > 0
  } }
}
function createCompensation() {
  return { async calculate({ jobs }) {
    let earningsPaise = 0
    for (const job of jobs) {
      if (job.compensationPaise === undefined) fail(409, 'COMPENSATION_SNAPSHOT_MISSING', 'A completed booking has no compensation snapshot.')
      earningsPaise += paise(job.compensationPaise)
      if (!Number.isSafeInteger(earningsPaise)) fail(400, 'INVALID_MONEY', 'Settlement exceeds supported bounds.')
    }
    return { earningsPaise, cashRemittedPaise: 0 }
  } }
}
module.exports = { createAdminOperationsRouter, validateSlot, createScheduling, createCompensation, addressSchema }
