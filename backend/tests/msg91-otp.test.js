const test = require('node:test')
const assert = require('node:assert/strict')
const { createMsg91OtpProvider, normalizeIndianMobile } = require('../src/platform/msg91-otp')
const env = require('../src/config/env')

const credentialOptions = {
  authKey: 'test-auth-key',
  widgetId: 'test-widget',
  widgetToken: 'test-widget-token',
  timeoutMs: 1000,
}
function response(payload, { status = 200, headers = {} } = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: name => headers[name.toLowerCase()] },
    text: async () => payload === undefined ? '' : JSON.stringify(payload),
  }
}

test('MSG91 Widget send, retry, OTP verification, and identity proof use documented requests', async () => {
  const calls = []
  const provider = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async (url, options) => {
      const body = JSON.parse(options.body)
      calls.push({ url: new URL(url), options, body })
      if (calls.length === 1) return response({ type: 'success', message: 'widget-request-123' })
      if (calls.length === 2) return response({ type: 'success', message: 'widget-request-123' })
      if (calls.length === 3) {
        return response(undefined, { headers: { 'access-token': 'provider-jwt-proof' } })
      }
      return response({ type: 'success', message: '919876543210' })
    },
  })

  assert.equal(provider.configured, true)
  assert.deepEqual(await provider.send({ mobileNumber: '9876543210' }), { requestId: 'widget-request-123' })
  assert.equal(calls[0].url.href, 'https://api.msg91.com/api/v5/widget/sendOtp')
  assert.deepEqual(calls[0].body, { widgetId: 'test-widget', identifier: '919876543210' })
  assert.equal(calls[0].options.method, 'POST')
  assert.equal(calls[0].options.headers.authkey, 'test-auth-key')
  assert.equal(calls[0].options.headers['content-type'], 'application/json')

  assert.equal(await provider.resend({ requestId: 'widget-request-123' }), true)
  assert.equal(calls[1].url.href, 'https://api.msg91.com/api/v5/widget/retryOtp')
  assert.deepEqual(calls[1].body, { widgetId: 'test-widget', reqId: 'widget-request-123' })

  assert.equal(await provider.verify({
    mobileNumber: '+919876543210',
    requestId: 'widget-request-123',
    code: '123456',
  }), true)
  assert.equal(calls[2].url.href, 'https://api.msg91.com/api/v5/widget/verifyOtp')
  assert.deepEqual(calls[2].body, { widgetId: 'test-widget', reqId: 'widget-request-123', otp: '123456' })
  assert.equal(calls[3].url.href, 'https://api.msg91.com/api/v5/widget/verifyAccessToken')
  assert.deepEqual(calls[3].body, { 'access-token': 'provider-jwt-proof' })
  assert.equal(calls[0].url.search, '')
})

test('MSG91 Widget token authentication uses tokenAuth instead of an Auth Key header', async () => {
  let request
  const provider = createMsg91OtpProvider({
    widgetId: 'test-widget',
    widgetToken: 'test-widget-token',
    fetchImpl: async (url, options) => {
      request = { url, options, body: JSON.parse(options.body) }
      return response({ type: 'success', message: 'request-id' })
    },
  })
  await provider.send({ mobileNumber: '+91 98765 43210' })
  assert.equal(request.options.headers.authkey, undefined)
  assert.deepEqual(request.body, {
    widgetId: 'test-widget',
    identifier: '919876543210',
    tokenAuth: 'test-widget-token',
  })
})

test('MSG91 Widget rejects invalid numbers, OTPs, and identity mismatches', async () => {
  const provider = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async (url, options) => {
      if (url.endsWith('/verifyOtp')) return response({ type: 'error', message: 'Invalid OTP' })
      if (url.endsWith('/verifyAccessToken')) return response({ type: 'success', message: '919876543211' })
      return response({ type: 'success', message: 'request-id' })
    },
  })
  await assert.rejects(provider.send({ mobileNumber: '12345' }), { code: 'INVALID_MOBILE' })
  assert.equal(await provider.verify({
    mobileNumber: '+919876543210',
    requestId: 'request-id',
    code: '111111',
  }), false)

  const mismatchedProvider = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async url => url.endsWith('/verifyOtp')
      ? response(undefined, { headers: { 'access-token': 'provider-proof' } })
      : response({ type: 'success', message: '+919876543211' }),
  })
  assert.equal(await mismatchedProvider.verify({
    mobileNumber: '+919876543210',
    requestId: 'request-id',
    code: '123456',
  }), false)
})

test('MSG91 errors and malformed responses fail closed without exposing provider details', async () => {
  const unavailable = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => { throw Object.assign(new Error('private network detail'), { code: 'ECONNRESET' }) },
  })
  await assert.rejects(unavailable.send({ mobileNumber: '+919876543210' }), { code: 'MSG91_NETWORK_ERROR' })

  const timeout = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => { throw Object.assign(new Error('timeout'), { name: 'TimeoutError' }) },
  })
  await assert.rejects(timeout.send({ mobileNumber: '+919876543210' }), { code: 'MSG91_TIMEOUT' })

  const malformed = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => ({ ok: true, status: 200, text: async () => '{' }),
  })
  await assert.rejects(malformed.send({ mobileNumber: '+919876543210' }), { code: 'MSG91_INVALID_RESPONSE' })

  const bodyNetworkError = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      text: async () => { throw new Error('private socket detail') },
    }),
  })
  await assert.rejects(bodyNetworkError.send({ mobileNumber: '+919876543210' }), {
    code: 'MSG91_NETWORK_ERROR',
    providerHttpStatus: 200,
    failureCategory: 'network_error',
  })

  const rejected = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => response({ type: 'error', code: 'BALANCE_LOW', message: 'insufficient credits' }),
  })
  await assert.rejects(rejected.send({ mobileNumber: '+919876543210' }), error => {
    assert.equal(error.code, 'MSG91_SEND_FAILED')
    assert.equal(error.providerHttpStatus, 200)
    assert.equal(error.providerErrorCode, 'BALANCE_LOW')
    assert.equal(error.failureCategory, 'insufficient_balance')
    assert.doesNotMatch(JSON.stringify(error), /insufficient credits|test-auth-key|\+?919876543210/)
    return true
  })

  const authRejected = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => response({ type: 'error', code: 'AUTH_INVALID', message: 'Invalid credentials' }, { status: 401 }),
  })
  await assert.rejects(authRejected.send({ mobileNumber: '+919876543210' }), {
    code: 'MSG91_AUTH_FAILED',
    providerHttpStatus: 401,
    providerErrorCode: 'AUTH_INVALID',
    failureCategory: 'authentication',
  })

  const unsafeCode = createMsg91OtpProvider({
    ...credentialOptions,
    fetchImpl: async () => response({ type: 'error', code: 'Bearer secret-token', message: 'Rejected' }, { status: 400 }),
  })
  await assert.rejects(unsafeCode.send({ mobileNumber: '+919876543210' }), error => {
    assert.equal(error.providerHttpStatus, 400)
    assert.equal(error.providerErrorCode, undefined)
    assert.equal(error.failureCategory, 'provider_rejected')
    return true
  })

  const unconfigured = createMsg91OtpProvider({})
  assert.equal(unconfigured.configured, false)
  await assert.rejects(unconfigured.send({ mobileNumber: '+919876543210' }), { code: 'OTP_CONFIGURATION_MISSING' })
})

test('MSG91 provider failures receive distinct diagnostic categories without logging message text', async () => {
  const cases = [
    {
      status: 403,
      payload: { code: 'WIDGET_INACTIVE', message: 'The widget is inactive' },
      category: 'widget_inactive',
    },
    {
      status: 400,
      payload: { code: 'TEMPLATE_PENDING', message: 'SMS template approval is pending' },
      category: 'messaging_configuration',
    },
    {
      status: 400,
      payload: { code: 'INVALID_IDENTIFIER', message: 'Invalid identifier' },
      category: 'invalid_request',
    },
    {
      status: 502,
      payload: { code: 'UPSTREAM_FAILURE', message: 'Provider unavailable' },
      category: 'provider_server_error',
    },
  ]

  for (const { status, payload, category } of cases) {
    const provider = createMsg91OtpProvider({
      ...credentialOptions,
      fetchImpl: async () => response(payload, { status }),
    })
    await assert.rejects(provider.send({ mobileNumber: '+919876543210' }), error => {
      assert.equal(error.providerHttpStatus, status)
      assert.equal(error.providerErrorCode, payload.code)
      assert.equal(error.failureCategory, category)
      return true
    })
  }
})

test('MSG91 identity normalization accepts Indian mobile formats only', () => {
  assert.equal(normalizeIndianMobile('9876543210'), '+919876543210')
  assert.equal(normalizeIndianMobile('919876543210'), '+919876543210')
  assert.equal(normalizeIndianMobile('+91 98765-43210'), '+919876543210')
  assert.equal(normalizeIndianMobile('+12025550123'), undefined)
})

test('MSG91 environment validation requires a supported, fully configured Widget provider', () => {
  const configured = {
    ...env,
    OTP_PROVIDER: 'msg91',
    MSG91_ENABLED: true,
    MSG91_AUTH_KEY: 'test-auth-key',
    MSG91_WIDGET_ID: 'test-widget',
  }
  assert.deepEqual(env.msg91ConfigProblems(configured), [])
  assert.deepEqual(env.msg91ConfigProblems({ ...configured, OTP_PROVIDER: 'none' }), [
    'MSG91_ENABLED requires OTP_PROVIDER=msg91',
  ])
  assert.deepEqual(env.msg91ConfigProblems({ ...configured, MSG91_WIDGET_ID: undefined }), [
    'MSG91_WIDGET_ID is required when MSG91 is enabled',
  ])
  assert.deepEqual(env.msg91ConfigProblems({
    ...configured,
    MSG91_AUTH_KEY: undefined,
    MSG91_WIDGET_TOKEN: undefined,
  }), ['MSG91_AUTH_KEY or MSG91_WIDGET_TOKEN is required when MSG91 is enabled'])
})
