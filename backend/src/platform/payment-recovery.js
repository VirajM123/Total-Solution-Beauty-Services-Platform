const { z } = require('zod')
const { createHash } = require('node:crypto')
const { protectedRouter, handler, reply, fail, atomic, requireRecord, compareAndSet, id } = require('./core')
const { paise } = require('./business')

function createPaymentRecoveryRouter({ db, auth, razorpay }) {
  const router = protectedRouter(auth)
  router.post('/bookings/:id/payment-qr/recover', auth.requirePermission('payments.reconcile'), handler(async (req, res) => {
    const input = z.object({ providerQrCodeId: z.string().regex(/^qr_[a-zA-Z0-9]+$/) }).strict().parse(req.body)
    if (!razorpay?.fetchQrCode) fail(503, 'RAZORPAY_NOT_CONFIGURED', 'Provider lookup is not configured.')
    // External I/O stays outside the database transaction. The transaction revalidates the booking.
    const provider = await razorpay.fetchQrCode(input.providerQrCodeId)
    const before = await requireRecord(db, 'bookings', req.params.id)
    if (String(provider.notes?.bookingId) !== String(before._id) || provider.type !== 'upi_qr' || provider.usage !== 'single_use' || provider.fixed_amount !== true || !['active', 'closed'].includes(provider.status) || !Number.isSafeInteger(provider.payment_amount) || provider.payment_amount !== paise(before.totalPaise)) {
      fail(409, 'PAYMENT_QR_MISMATCH', 'Provider QR does not match this booking and its final bill.')
    }
    let image
    try { image = new URL(provider.image_url) } catch { fail(502, 'INVALID_PAYMENT_QR', 'Provider QR image is invalid.') }
    if (image.protocol !== 'https:' || image.username || image.password) fail(502, 'INVALID_PAYMENT_QR', 'Provider QR image is invalid.')
    const recovered = await atomic(db, req, 'payment.qr_recovered', 'bookings', async session => {
      const booking = await requireRecord(db, 'bookings', req.params.id, session)
      if (booking.paymentQrCodeId && booking.paymentQrCodeId !== provider.id) fail(409, 'PAYMENT_QR_CONFLICT', 'This booking already has another QR. No reservation was released.')
      if (paise(booking.totalPaise) !== provider.payment_amount || !booking.serviceFinishedAt || booking.paymentMethod !== 'razorpay_qr' || !booking.paymentQrRequestId || !['in_progress','completed'].includes(booking.status)) fail(409, 'PAYMENT_QR_CONFLICT', 'Booking is not awaiting recovery of this QR.')
      const existing = await db.collection('payment_qr_codes').findOne({ providerQrCodeId: provider.id }, { session })
      if (existing && String(existing.bookingId) !== String(booking._id)) fail(409, 'PAYMENT_QR_CONFLICT', 'QR is already linked to another booking.')
      if (!existing) await db.collection('payment_qr_codes').insertOne({
        _id: id(createHash('sha256').update('qr:' + provider.id).digest('hex').slice(0,24)), providerQrCodeId: provider.id,
        bookingId: booking._id, workerUserId: booking.workerUserId, amountPaise: provider.payment_amount, currency: 'INR',
        imageUrl: image.toString(), status: 'created', createdAt: new Date(), isActive: true,
      }, { session })
      return booking.paymentQrCodeId ? booking : compareAndSet(db, 'bookings', booking, { paymentQrCodeId: provider.id }, session)
    })
    reply(req, res, { bookingId: recovered._id, providerQrCodeId: provider.id, recovered: true, paymentStatus: recovered.paymentStatus,
      message: 'Original QR recovered. Payment status is unchanged. If already paid, replay its signed provider webhook to verify payment.' })
  }))
  return router
}
module.exports = { createPaymentRecoveryRouter }
