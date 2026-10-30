const assert = require('node:assert/strict')
const { createHmac } = require('node:crypto')
const test = require('node:test')
const { createRazorpay, isConfigured } = require('../src/platform/razorpay')

const config = {
  RAZORPAY_ENABLED: true,
  RAZORPAY_QR_ENABLED: true,
  RAZORPAY_MODE: 'test',
  RAZORPAY_KEY_ID: 'rzp_test_example',
  RAZORPAY_KEY_SECRET: 'test-secret',
  RAZORPAY_WEBHOOK_SECRET: 'webhook-secret',
}

test('Razorpay creates a fixed single-use UPI QR for the exact paise total', async () => {
  let request
  const razorpay = createRazorpay({
    config,
    fetchImpl: async (url, options) => {
      request = { url, options }
      return {
        ok: true,
        async json() {
          return { id: 'qr_test_1', image_url: 'https://razorpay.test/qr.png' }
        },
      }
    },
  })

  const result = await razorpay.createQrCode({
    bookingId: 'booking-test',
    amountPaise: 156050,
  })
  const body = JSON.parse(request.options.body)
  assert.equal(request.url, 'https://api.razorpay.com/v1/payments/qr_codes')
  assert.equal(request.options.method, 'POST')
  assert.equal(request.options.headers.authorization, `Basic ${Buffer.from('rzp_test_example:test-secret').toString('base64')}`)
  assert.equal(body.type, 'upi_qr')
  assert.equal(body.usage, 'single_use')
  assert.equal(body.fixed_amount, true)
  assert.equal(body.payment_amount, 156050)
  assert.deepEqual(body.notes, { bookingId: 'booking-test' })
  assert.equal(result.id, 'qr_test_1')
})

test('Razorpay failures do not expose provider response or credential values', async () => {
  const razorpay = createRazorpay({
    config,
    fetchImpl: async () => ({
      ok: false,
      async json() {
        return { error: { description: 'private provider diagnostic' } }
      },
    }),
  })
  await assert.rejects(
    razorpay.createQrCode({ bookingId: 'booking-test', amountPaise: 100 }),
    error => error.code === 'RAZORPAY_QR_FAILED' &&
      !error.message.includes('private provider diagnostic'),
  )
})

test('Razorpay configuration is fail-closed for disabled and placeholder credentials', () => {
  assert.equal(isConfigured({ ...config, RAZORPAY_ENABLED: false }), false)
  assert.equal(isConfigured({ ...config, RAZORPAY_KEY_SECRET: 'YOUR_TEST_KEY_SECRET' }), false)
})

test('Razorpay webhook verification checks the exact raw body signature', () => {
  const rawBody = Buffer.from('{"event":"qr_code.credited"}')
  const signature = createHmac('sha256', config.RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest('hex')
  const razorpay = createRazorpay({ config })

  assert.equal(razorpay.verifyWebhook(rawBody, signature), true)
  assert.equal(razorpay.verifyWebhook(rawBody, '0'.repeat(64)), false)
  assert.equal(razorpay.verifyWebhook(Buffer.from('{}'), signature), false)
})
