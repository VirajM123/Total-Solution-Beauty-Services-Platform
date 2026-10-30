const { createHmac, timingSafeEqual } = require('node:crypto')
const env = require('../config/env')
const { fail } = require('./core')

function isConfigured(config) {
  return config.RAZORPAY_ENABLED &&
    config.RAZORPAY_QR_ENABLED &&
    Boolean(config.RAZORPAY_KEY_ID) &&
    Boolean(config.RAZORPAY_KEY_SECRET) &&
    Boolean(config.RAZORPAY_WEBHOOK_SECRET) &&
    !config.RAZORPAY_KEY_ID.includes('YOUR_') &&
    !config.RAZORPAY_KEY_SECRET.includes('YOUR_')
}

function createRazorpay({ config = env, fetchImpl = globalThis.fetch } = {}) {
  return {
    isConfigured: () => isConfigured(config),

    async createQrCode({ bookingId, amountPaise }) {
      if (!isConfigured(config)) {
        fail(503, 'RAZORPAY_NOT_CONFIGURED', 'Razorpay QR payments are not configured.')
      }

      if (!Number.isSafeInteger(amountPaise) || amountPaise <= 0) fail(400, 'INVALID_BOOKING_AMOUNT', 'Use a positive integer paise amount.')
      let response
      try {
        response = await fetchImpl('https://api.razorpay.com/v1/payments/qr_codes', {
          method: 'POST',
          headers: {
            authorization: `Basic ${Buffer.from(
              `${config.RAZORPAY_KEY_ID}:${config.RAZORPAY_KEY_SECRET}`,
            ).toString('base64')}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            type: 'upi_qr',
            name: `Hii Beauty booking ${bookingId}`,
            usage: 'single_use',
            fixed_amount: true,
            payment_amount: amountPaise,
            currency: config.RAZORPAY_CURRENCY || 'INR',
            description: `Service payment for booking ${bookingId}`,
            notes: { bookingId },
          }),
          signal: AbortSignal.timeout(12000),
        })
      } catch {
        fail(502, 'RAZORPAY_UNAVAILABLE', 'Razorpay could not be reached. Please retry.')
      }

      let result
      try {
        result = await response.json()
      } catch {
        fail(502, 'RAZORPAY_INVALID_RESPONSE', 'Razorpay returned an invalid response.')
      }
      if (!response.ok || typeof result?.id !== 'string' ||
          typeof result?.image_url !== 'string') {
        fail(502, 'RAZORPAY_QR_FAILED', 'Razorpay could not create the payment QR code.')
      }
      return result
    },

    async fetchQrCode(qrCodeId) {
      if (!isConfigured(config)) fail(503, 'RAZORPAY_NOT_CONFIGURED', 'Razorpay is not configured.')
      if (!/^qr_[a-zA-Z0-9]+$/.test(qrCodeId)) fail(400, 'INVALID_PAYMENT_QR', 'Enter a valid Razorpay QR identifier.')
      let response, result
      try {
        response = await fetchImpl('https://api.razorpay.com/v1/payments/qr_codes/' + encodeURIComponent(qrCodeId), {
          headers: { authorization: 'Basic ' + Buffer.from(config.RAZORPAY_KEY_ID + ':' + config.RAZORPAY_KEY_SECRET).toString('base64') },
          signal: AbortSignal.timeout(12000),
        })
        result = await response.json()
      } catch { fail(502, 'RAZORPAY_UNAVAILABLE', 'The provider lookup could not be completed. The payment reservation was retained.') }
      if (!response.ok || result?.id !== qrCodeId) fail(502, 'RAZORPAY_LOOKUP_FAILED', 'The provider did not confirm this QR identifier.')
      return result
    },

    verifyWebhook(rawBody, signature) {
      if (!config.RAZORPAY_WEBHOOK_SECRET) {
        fail(503, 'RAZORPAY_WEBHOOK_NOT_CONFIGURED', 'Razorpay webhook verification is not configured.')
      }
      if (!Buffer.isBuffer(rawBody) || typeof signature !== 'string' ||
          !/^[a-f0-9]{64}$/i.test(signature)) {
        return false
      }
      const expected = createHmac('sha256', config.RAZORPAY_WEBHOOK_SECRET)
        .update(rawBody)
        .digest()
      return timingSafeEqual(expected, Buffer.from(signature, 'hex'))
    },
  }
}

module.exports = { createRazorpay, isConfigured }
