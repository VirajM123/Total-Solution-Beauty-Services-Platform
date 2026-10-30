const ENDPOINT = 'https://api.msg91.com/api/v5/widget'

class Msg91OtpError extends Error {
  constructor(code, metadata = {}) {
    super(code)
    this.name = 'Msg91OtpError'
    this.code = code
    Object.assign(this, metadata)
  }
}

function normalizeIndianMobile(value) {
  if (typeof value !== 'string') return undefined
  const digits = value.replace(/[\s()-]/g, '')
  const match = digits.match(/^(?:\+?91)?([6-9]\d{9})$/)
  return match ? `+91${match[1]}` : undefined
}

function success(payload) {
  return payload && String(payload.type || '').toLowerCase() === 'success'
}

function providerErrorCode(payload, status, action) {
  const detail = `${payload?.code || ''} ${payload?.message || ''}`.toLowerCase()
  if (status === 401 || status === 403 || /auth|credential|unauthori[sz]ed/.test(detail)) return 'MSG91_AUTH_FAILED'
  if (/credit|balance|channel|sms|delivery/.test(detail)) return 'MSG91_SEND_FAILED'
  if (action === 'verifyOtp' && /invalid|incorrect|expired|not match|wrong otp/.test(detail)) return 'MSG91_INVALID_OTP'
  return 'MSG91_REJECTED'
}

function safeProviderErrorCode(payload) {
  const value = payload?.code
  const code = typeof value === 'string' ? value.trim() : Number.isInteger(value) ? String(value) : ''
  return /^(?:[A-Z][A-Z0-9_-]{0,31}|\d{1,6})$/.test(code) ? code : undefined
}

function failureCategory(payload, status, code) {
  const detail = `${payload?.code || ''} ${payload?.message || ''}`.toLowerCase()
  if (code === 'MSG91_TIMEOUT') return 'timeout'
  if (code === 'MSG91_NETWORK_ERROR') return 'network_error'
  if (code === 'MSG91_INVALID_RESPONSE') return 'invalid_response'
  if (status === 401 || /auth|credential|unauthori[sz]ed/.test(detail)) return 'authentication'
  if (/insufficient.{0,20}(credit|balance)|(credit|balance).{0,20}insufficient|low balance|out of credits/.test(detail)) {
    return 'insufficient_balance'
  }
  if (/widget.{0,30}(inactive|disabled|expired)|(?:inactive|disabled|expired).{0,30}widget/.test(detail)) {
    return 'widget_inactive'
  }
  if (/channel|template|\bdlt\b|sender.?id|approval|approved|entity.?id/.test(detail)) {
    return 'messaging_configuration'
  }
  if (status === 403) return 'authentication'
  if (code === 'MSG91_INVALID_OTP') return 'otp_rejected'
  if (status === 429) return 'rate_limited'
  if (/invalid|incorrect|required|missing|malformed|unsupported/.test(detail)) return 'invalid_request'
  if (Number.isInteger(status) && status >= 500) return 'provider_server_error'
  return 'provider_rejected'
}

function providerError(payload, status, action) {
  const code = providerErrorCode(payload, status, action)
  return new Msg91OtpError(code, {
    providerHttpStatus: Number.isInteger(status) ? status : undefined,
    providerErrorCode: safeProviderErrorCode(payload),
    failureCategory: failureCategory(payload, status, code),
  })
}

function invalidResponse(status) {
  return new Msg91OtpError('MSG91_INVALID_RESPONSE', {
    providerHttpStatus: Number.isInteger(status) ? status : undefined,
    failureCategory: 'invalid_response',
  })
}

function headerValue(headers, name) {
  if (typeof headers?.get === 'function') return headers.get(name)
  const key = Object.keys(headers || {}).find(value => value.toLowerCase() === name.toLowerCase())
  return key ? headers[key] : undefined
}

function createMsg91OtpProvider({
  authKey,
  widgetId,
  widgetToken,
  enabled = true,
  timeoutMs = 10000,
  fetchImpl = globalThis.fetch,
} = {}) {
  const configured = enabled
    && Boolean(widgetId)
    && Boolean(authKey || widgetToken)
    && typeof fetchImpl === 'function'

  function assertConfigured() {
    if (!configured) throw new Msg91OtpError('OTP_CONFIGURATION_MISSING')
  }

  function headers() {
    return {
      'content-type': 'application/json',
      ...(authKey ? { authkey: authKey } : {}),
    }
  }

  function body(values, includeWidgetId = true) {
    return {
      ...(includeWidgetId ? { widgetId } : {}),
      ...values,
      ...(!authKey && widgetToken ? { tokenAuth: widgetToken } : {}),
    }
  }

  async function request(action, values, { includeWidgetId = true } = {}) {
    let response
    try {
      response = await fetchImpl(`${ENDPOINT}/${action}`, {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify(body(values, includeWidgetId)),
        signal: AbortSignal.timeout(timeoutMs),
      })
    } catch (error) {
      const timeout = error?.name === 'TimeoutError' || error?.name === 'AbortError'
      throw new Msg91OtpError(timeout ? 'MSG91_TIMEOUT' : 'MSG91_NETWORK_ERROR', {
        failureCategory: timeout ? 'timeout' : 'network_error',
      })
    }

    let payload = {}
    let text
    try {
      text = await response.text()
    } catch {
      throw new Msg91OtpError('MSG91_NETWORK_ERROR', {
        providerHttpStatus: Number.isInteger(response.status) ? response.status : undefined,
        failureCategory: 'network_error',
      })
    }
    try {
      if (text) payload = JSON.parse(text)
    } catch {
      throw invalidResponse(response.status)
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw invalidResponse(response.status)
    }
    if (!response.ok) {
      throw providerError(payload, response.status, action)
    }
    return { payload, response }
  }

  return {
    configured,
    async send({ mobileNumber }) {
      assertConfigured()
      const normalized = normalizeIndianMobile(mobileNumber)
      if (!normalized) throw new Msg91OtpError('INVALID_MOBILE')
      const { payload, response } = await request('sendOtp', {
        identifier: normalized.slice(1),
      })
      if (!success(payload)) throw providerError(payload, response.status, 'sendOtp')
      const requestId = payload.reqId || payload.requestId || payload.message
      if (typeof requestId !== 'string' || !requestId.trim() || requestId.length > 256) {
        throw invalidResponse()
      }
      return { requestId: requestId.trim() }
    },
    async resend({ requestId }) {
      assertConfigured()
      if (typeof requestId !== 'string' || !requestId.trim()) {
        throw invalidResponse()
      }
      const { payload, response } = await request('retryOtp', { reqId: requestId })
      if (!success(payload)) throw providerError(payload, response.status, 'retryOtp')
      return true
    },
    async verify({ mobileNumber, requestId, code }) {
      assertConfigured()
      const normalized = normalizeIndianMobile(mobileNumber)
      if (!normalized || typeof requestId !== 'string' || !requestId.trim()) {
        throw invalidResponse()
      }

      const verifiedOtp = await request('verifyOtp', { reqId: requestId, otp: code })
      const rawPayload = verifiedOtp.payload || {}
      const otpAccessToken = headerValue(verifiedOtp.response.headers, 'access-token')
        || rawPayload['access-token']
        || rawPayload.accessToken
        || (typeof rawPayload.message === 'string' && rawPayload.message.startsWith('eyJ') ? rawPayload.message : undefined)
        || (typeof rawPayload.data === 'string' && rawPayload.data.startsWith('eyJ') ? rawPayload.data : undefined)
        || (typeof rawPayload.data?.['access-token'] === 'string' ? rawPayload.data['access-token'] : undefined)
        || (typeof rawPayload.data?.token === 'string' ? rawPayload.data.token : undefined)
        || (typeof rawPayload.token === 'string' ? rawPayload.token : undefined)

      if (!success(rawPayload) && !otpAccessToken) {
        if (rawPayload.type === 'error') {
          const detail = String(rawPayload.message || '').toLowerCase()
          if (/already verif/.test(detail)) {
            return true
          }
          const error = providerError(rawPayload, verifiedOtp.response.status, 'verifyOtp')
          if (error.code === 'MSG91_INVALID_OTP') return false
          throw error
        }
        throw invalidResponse(verifiedOtp.response.status)
      }

      if (!otpAccessToken) {
        return success(rawPayload)
      }

      let identity
      try {
        identity = await request('verifyAccessToken', { 'access-token': otpAccessToken }, { includeWidgetId: false })
      } catch (error) {
        if (error instanceof Msg91OtpError && error.code === 'MSG91_AUTH_FAILED') return false
        throw error
      }
      if (!success(identity.payload)) return false
      const verifiedIdentifier = identity.payload.message
        || identity.payload.identifier
        || identity.payload.mobile
        || identity.payload.data?.identifier
        || identity.payload.data?.mobile
      return normalizeIndianMobile(verifiedIdentifier) === normalized
    },
  }
}

module.exports = { createMsg91OtpProvider, Msg91OtpError, normalizeIndianMobile }
