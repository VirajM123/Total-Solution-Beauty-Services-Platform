const assert = require('node:assert/strict')
const http = require('node:http')
const argon2 = require('argon2')
const mongoose = require('mongoose')
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

function createAuthModels(user, role) {
  let sessionRecord
  class AuthSession {
    constructor(fields) {
      this._id = new mongoose.Types.ObjectId()
      Object.assign(this, fields)
    }

    async save() {
      sessionRecord = this
    }

    static findOne(filter) {
      return {
        lean: async () => sessionRecord
          && sessionRecord.refreshTokenHash === filter.refreshTokenHash
          && sessionRecord.appType === filter.appType
          && sessionRecord.isActive === filter.isActive
          && !sessionRecord.revokedAt
          && sessionRecord.expiresAt > filter.expiresAt.$gt
          ? sessionRecord
          : null,
      }
    }

    static async updateOne(filter, update) {
      if (sessionRecord && sessionRecord._id.equals(filter._id)) {
        Object.assign(sessionRecord, update.$set)
      }
    }
  }

  class AuditLog {
    constructor(fields) {
      Object.assign(this, fields)
    }

    async save() {}
  }

  const userQuery = {
    select() { return this },
    lean: async () => user,
  }
  return {
    User: {
      findOne: () => userQuery,
      findById: () => ({ select() { return this }, lean: async () => user }),
    },
    Role: { findById: () => ({ lean: async () => role }) },
    AuthSession,
    AuditLog,
    ServiceCategory: {},
    Service: {},
    MediaAsset: {},
    ServiceArea: {},
  }
}

test('Admin login creates an HttpOnly session; CSRF and role permissions are enforced', async () => {
  const userId = new mongoose.Types.ObjectId()
  const roleId = new mongoose.Types.ObjectId()
  const user = {
    _id: userId,
    roleId,
    fullName: 'Admin User',
    email: 'admin@example.test',
    userType: 'admin',
    status: 'active',
    isActive: true,
    passwordHash: await argon2.hash('correct password', { type: argon2.argon2id }),
  }
  const role = {
    _id: roleId,
    roleCode: 'ADMIN',
    permissions: [],
    isActive: true,
  }
  const app = createApp({
    apiEnabled: true,
    models: createAuthModels(user, role),
    sessionSecret: 'test-session-secret-'.padEnd(32, 'x'),
    isDatabaseReady: () => true,
  })

  await withServer(app, async baseUrl => {
    const login = await fetch(`${baseUrl}/api/admin/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: 'http://localhost:5173' },
      body: JSON.stringify({ email: 'ADMIN@example.test', password: 'correct password' }),
    })
    const loginBody = await login.json()
    const setCookie = login.headers.get('set-cookie')
    assert.equal(login.status, 200)
    assert.match(setCookie, /HttpOnly/i)
    assert.ok(loginBody.data.csrfToken)
    assert.equal(loginBody.data.admin.email, 'admin@example.test')

    const cookie = setCookie.match(/hi_admin_session=([^;]+)/)[0]
    const session = await fetch(`${baseUrl}/api/admin/auth/session`, { headers: { Cookie: cookie } })
    assert.equal(session.status, 200)

    const denied = await fetch(`${baseUrl}/api/admin/categories`, {
      headers: { Cookie: cookie },
    })
    assert.equal(denied.status, 403)
    assert.equal((await denied.json()).error.code, 'FORBIDDEN')

    const badCsrf = await fetch(`${baseUrl}/api/admin/auth/logout`, {
      method: 'POST',
      headers: { Origin: 'http://localhost:5173', Cookie: cookie, 'Content-Type': 'application/json' },
      body: '{}',
    })
    assert.equal(badCsrf.status, 403)
    assert.equal((await badCsrf.json()).error.code, 'CSRF_REJECTED')

    const logout = await fetch(`${baseUrl}/api/admin/auth/logout`, {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:5173',
        Cookie: cookie,
        'X-CSRF-Token': loginBody.data.csrfToken,
        'Content-Type': 'application/json',
      },
      body: '{}',
    })
    assert.equal(logout.status, 200)

    const revoked = await fetch(`${baseUrl}/api/admin/auth/session`, { headers: { Cookie: cookie } })
    assert.equal(revoked.status, 401)
  })
})

test('authentication works with catalog disabled and leaves every catalog route unavailable', async () => {
  const user = {
    _id: new mongoose.Types.ObjectId(), roleId: new mongoose.Types.ObjectId(),
    fullName: 'Development Admin', email: 'admin@example.test', userType: 'admin',
    status: 'active', isActive: true,
    passwordHash: await argon2.hash('correct password', { type: argon2.argon2id }),
  }
  const role = { _id: user.roleId, roleCode: 'HII_BEAUTY_SUPER_ADMIN', isActive: true,
    permissions: ['catalog.categories.create'] }
  await withServer(createApp({ models: createAuthModels(user, role),
    sessionSecret: 'test-session-secret-'.padEnd(32, 'x'), isDatabaseReady: () => true }),
  async baseUrl => {
    const login = await fetch(baseUrl + '/api/admin/auth/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'http://localhost:5173' },
      body: JSON.stringify({ email: user.email, password: 'correct password' }),
    })
    assert.equal(login.status, 200)
    const cookie = login.headers.get('set-cookie').split(';')[0]
    const body = await login.json()
    assert.equal((await fetch(baseUrl + '/api/admin/auth/session', { headers: { Cookie: cookie } })).status, 200)
    for (const [method, route] of ['GET', 'POST'].flatMap(method => ['/api/admin/categories', '/api/admin/services', '/api/admin/media/uploads', '/api/catalog/categories'].map(route => [method, route]))) {
      assert.equal((await fetch(baseUrl + route, { method, headers: {
        Cookie: cookie, Origin: 'http://localhost:5173', 'X-CSRF-Token': body.data.csrfToken,
      } })).status, 503)
    }
    assert.equal((await fetch(baseUrl + '/api/admin/auth/logout', { method: 'POST', headers: {
      Cookie: cookie, Origin: 'http://localhost:5173', 'X-CSRF-Token': body.data.csrfToken,
    } })).status, 200)
    assert.equal((await fetch(baseUrl + '/api/admin/auth/session', { headers: { Cookie: cookie } })).status, 401)
  })
})
test('auth-only mode fails closed for missing secret and database loss', async () => {
  for (const [secret, ready] of [[null, true], ['test-secret'.padEnd(32, 'x'), false]]) {
    await withServer(createApp({ models: createAuthModels(null, null),
      sessionSecret: secret, isDatabaseReady: () => ready }), async baseUrl => {
      assert.equal((await fetch(baseUrl + '/api/admin/auth/session')).status, 503)
    })
  }
})
test('malformed and inactive database roles fail closed', () => {
  const { isActiveRole } = require('../src/middleware/authenticate')
  for (const role of [null, {}, { isActive: true, roleCode: '' },
    { isActive: true, roleCode: 'ADMIN', permissions: [123] },
    { isActive: false, roleCode: 'ADMIN', permissions: [] }]) assert.equal(isActiveRole(role), false)
  assert.equal(isActiveRole({ isActive: true, roleCode: 'ADMIN', permissions: [] }), true)
})
