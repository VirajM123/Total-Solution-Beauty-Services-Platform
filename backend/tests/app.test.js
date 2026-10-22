const assert = require('node:assert/strict')
const http = require('node:http')
const test = require('node:test')
const { createApp } = require('../src/app')

async function withServer(app, run) {
  const server = http.createServer(app)
  await new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', resolve)
  })
  try {
    const address = server.address()
    await run(`http://127.0.0.1:${address.port}`)
  } finally {
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
}

test('liveness endpoint responds without a database connection', async () => {
  await withServer(createApp({ isDatabaseReady: () => false }), async baseUrl => {
    const response = await fetch(`${baseUrl}/health/live`)
    const body = await response.json()
    assert.equal(response.status, 200)
    assert.equal(body.success, true)
    assert.equal(body.data.status, 'live')
    assert.ok(response.headers.get('x-request-id'))
    assert.ok(response.headers.get('x-content-type-options'))
  })
})

test('readiness endpoint reports disconnected database as unavailable', async () => {
  await withServer(createApp({ isDatabaseReady: () => false }), async baseUrl => {
    const response = await fetch(`${baseUrl}/health/ready`)
    const body = await response.json()
    assert.equal(response.status, 503)
    assert.equal(body.success, false)
    assert.equal(body.data.database, 'disconnected')
  })
})

test('readiness endpoint succeeds only when database is connected', async () => {
  await withServer(createApp({ isDatabaseReady: () => true }), async baseUrl => {
    const response = await fetch(`${baseUrl}/health/ready`)
    const body = await response.json()
    assert.equal(response.status, 200)
    assert.equal(body.success, true)
    assert.equal(body.data.database, 'connected')
  })
})

test('business APIs remain explicitly unavailable until schemas and auth are verified', async () => {
  await withServer(createApp(), async baseUrl => {
    const response = await fetch(`${baseUrl}/api/admin/categories`)
    const body = await response.json()
    assert.equal(response.status, 503)
    assert.equal(body.error.code, 'API_NOT_CONFIGURED')
  })
})

test('unknown routes return the standard error response', async () => {
  await withServer(createApp(), async baseUrl => {
    const response = await fetch(`${baseUrl}/not-a-route`)
    const body = await response.json()
    assert.equal(response.status, 404)
    assert.equal(body.success, false)
    assert.equal(body.error.code, 'NOT_FOUND')
  })
})

test('CORS allows configured Admin origins and omits headers for other origins', async () => {
  await withServer(createApp(), async baseUrl => {
    const allowed = await fetch(`${baseUrl}/health/live`, { headers: { Origin: 'http://localhost:5173' } })
    const blocked = await fetch(`${baseUrl}/health/live`, { headers: { Origin: 'https://untrusted.example' } })
    assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173')
    assert.equal(blocked.headers.get('access-control-allow-origin'), null)
  })
})

test('malformed JSON returns a safe validation error', async () => {
  await withServer(createApp(), async baseUrl => {
    const response = await fetch(`${baseUrl}/health/live`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{',
    })
    const body = await response.json()
    assert.equal(response.status, 400)
    assert.equal(body.error.code, 'INVALID_JSON')
  })
})
