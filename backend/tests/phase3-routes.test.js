const assert = require('node:assert/strict')
const http = require('node:http')
const test = require('node:test')
const models = require('../src/models')
const { createApp } = require('../src/app')
const { HttpError } = require('../src/middleware/errorHandler')
const { isPersistentPublicImage, priceRupeesToPaise, serviceUpdateSchema } = require('../src/modules/services/catalog.routes')
const { createMediaStorage } = require('../src/modules/media/media.routes')

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

test('Admin catalog writes reject unauthenticated requests', async () => {
  const app = createApp({
    apiEnabled: true,
    models,
    sessionSecret: 'test-session-secret-'.padEnd(32, 'x'),
    isDatabaseReady: () => true,
  })

  await withServer(app, async baseUrl => {
    const response = await fetch(`${baseUrl}/api/admin/categories`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: 'http://localhost:5173' },
      body: JSON.stringify({ name: 'Test category' }),
    })
    const body = await response.json()
    assert.equal(response.status, 401)
    assert.equal(body.error.code, 'UNAUTHENTICATED')
  })
})

test('Configured catalog routes remain unavailable while the database is disconnected', async () => {
  const app = createApp({
    apiEnabled: true,
    models,
    sessionSecret: 'test-session-secret-'.padEnd(32, 'x'),
    isDatabaseReady: () => false,
  })

  await withServer(app, async baseUrl => {
    const response = await fetch(`${baseUrl}/api/catalog/categories`)
    const body = await response.json()
    assert.equal(response.status, 503)
    assert.equal(body.error.code, 'API_NOT_CONFIGURED')
  })
})

test('rupee decimal strings convert exactly to integer paise', () => {
  assert.equal(priceRupeesToPaise('25').toString(), '2500')
  assert.equal(priceRupeesToPaise('25.5').toString(), '2550')
  assert.equal(priceRupeesToPaise('25.05').toString(), '2505')
  assert.throws(() => priceRupeesToPaise('25.005'), HttpError)
  assert.throws(() => priceRupeesToPaise('-1'), HttpError)
})

test('service updates accept partial patch payloads while rejecting empty patches', () => {
  assert.equal(serviceUpdateSchema.safeParse({ priceRupees: '15.50' }).success, true)
  assert.equal(serviceUpdateSchema.safeParse({}).success, false)
})

test('public catalog media rejects browser URLs and local filesystem paths', () => {
  const valid = { storageProvider: 's3', storageKey: 'catalog/image-1.webp', publicUrl: 'https://cdn.example/image-1.webp' }
  assert.equal(isPersistentPublicImage(valid), true)
  for (const storageKey of ['blob:https://localhost/image', 'data:image/png;base64,AA==', 'file:///image.png', '/uploads/image.png', 'C:\\uploads\\image.png', 'C:/uploads/image.png']) {
    assert.equal(isPersistentPublicImage({ ...valid, storageKey }), false)
  }
  assert.equal(isPersistentPublicImage({ ...valid, storageProvider: 'local' }), false)
  assert.equal(isPersistentPublicImage({ ...valid, publicUrl: 'http://cdn.example/image.webp' }), false)
})

test('media storage fails clearly when no persistent provider is configured', async () => {
  const storage = createMediaStorage()
  assert.equal(storage.isConfigured, false)
  await assert.rejects(storage.upload({}), error => {
    assert.ok(error instanceof HttpError)
    assert.equal(error.code, 'STORAGE_NOT_CONFIGURED')
    return true
  })
})
