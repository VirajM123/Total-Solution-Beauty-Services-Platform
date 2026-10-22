const test = require('node:test')
const assert = require('node:assert/strict')
const argon2 = require('argon2')
const { bootstrap, assertDevelopment, identitySchema, ROLE_CODE, PERMISSIONS } = require('../src/modules/auth/adminBootstrap')
const env = { NODE_ENV: 'development', MONGODB_DB_NAME: 'hii_beauty_dev',
  MONGODB_URI: 'test-only-placeholder', SESSION_COOKIE_SECRET: 'x'.repeat(32), ADMIN_CATALOG_API_ENABLED: false }
const identity = { fullName: 'Test Admin', email: 'admin@example.test', mobileNumber: '+919876543210',
  password: 'test only password 1234' }
function fixture({ conflict = false, auditFailure = false, roles = [], users = [] } = {}) {
  let records = { roles: [...roles], users: [...users], audit_logs: [] }
  let ended = false
  const session = {
    async withTransaction(run) {
      const original = structuredClone(records)
      try { await run() } catch (error) { records = original; throw error }
    },
    async endSession() { ended = true },
  }
  const db = { databaseName: 'hii_beauty_dev',
    listCollections() { return { toArray: async () => ['users', 'roles', 'auth_sessions', 'audit_logs'].map(name => ({ name })) } },
    collection(name) {
    return {
      find() { return { project() { return { toArray: async () => records[name] } } } },
      listIndexes() { return { toArray: async () => [{ unique: true, key: { roleCode: 1 } }] } },
      async findOne() { return conflict ? { _id: 'existing' } : null },
      async insertOne(record) {
        if (name === 'audit_logs' && auditFailure) throw new Error('audit failed')
        records[name].push(record)
      },
    }
  } }
  return { db, client: { startSession: () => session }, get records() { return records }, get ended() { return ended } }
}
test('bootstrap refuses unsafe environment, missing approval, and invalid identity before writes', async () => {
  for (const change of [{ NODE_ENV: 'production' }, { MONGODB_DB_NAME: 'other' },
    { MONGODB_URI: '' }, { SESSION_COOKIE_SECRET: '' }, { ADMIN_CATALOG_API_ENABLED: true }]) {
    assert.throws(() => assertDevelopment({ ...env, ...change }, { databaseName: 'hii_beauty_dev' }))
  }
  assert.equal(identitySchema.safeParse({ ...identity, password: 'short' }).success, false)
  const f = fixture()
  await assert.rejects(bootstrap({ ...f, env, identity, approved: false }))
  assert.equal(f.records.users.length, 0)
})
test('bootstrap writes only explicit role, Argon2id user and safe audit; repeat is refused', async () => {
  const f = fixture()
  await bootstrap({ db: f.db, client: f.client, env, identity, approved: true })
  assert.equal(f.records.roles[0].roleCode, ROLE_CODE)
  assert.deepEqual(f.records.roles[0].permissions, [...PERMISSIONS])
  assert.equal(f.records.users[0].password, undefined)
  assert.match(f.records.users[0].passwordHash, /^\$argon2id\$/)
  assert.equal(await argon2.verify(f.records.users[0].passwordHash, identity.password), true)
  assert.equal(f.records.audit_logs[0].action, 'admin.bootstrap')
  assert.equal(JSON.stringify(f.records.audit_logs).includes(identity.password), false)
  await assert.rejects(bootstrap({ db: f.db, client: f.client, env, identity, approved: true }))
  assert.equal(f.records.users.length, 1)
  assert.equal(f.ended, true)
})
test('bootstrap never elevates an existing identity and rolls back when audit fails', async () => {
  for (const options of [{ conflict: true }, { auditFailure: true }]) {
    const f = fixture(options)
    await assert.rejects(bootstrap({ db: f.db, client: f.client, env, identity, approved: true }))
    assert.equal(f.records.users.length, 0)
    assert.equal(f.records.roles.length, 0)
    assert.equal(f.ended, true)
  }
})

test('bootstrap refuses missing collections or unique role index without creating either', async () => {
  for (const missing of ['collection', 'index']) {
    const f = fixture()
    if (missing === 'collection') f.db.listCollections = () => ({ toArray: async () => [] })
    else { const collection = f.db.collection; f.db.collection = name => ({ ...collection(name), listIndexes: () => ({ toArray: async () => [] }) }) }
    await assert.rejects(bootstrap({ db: f.db, client: f.client, env, identity, approved: true }))
    assert.equal(f.records.users.length, 0)
  }
})
