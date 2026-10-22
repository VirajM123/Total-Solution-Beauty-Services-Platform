const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const test = require('node:test')
const env = require('../src/config/env')
const { connectDatabase, connectionOptions } = require('../src/config/database')

test('database configuration explicitly selects hii_beauty_dev without auto-creating collections or indexes', () => {
  assert.equal(env.MONGODB_DB_NAME, 'hii_beauty_dev')
  assert.equal(env.ADMIN_CATALOG_API_ENABLED, false)
  assert.equal(connectionOptions.dbName, 'hii_beauty_dev')
  assert.equal(connectionOptions.autoCreate, false)
  assert.equal(connectionOptions.autoIndex, false)
})

test('connection uses the explicit database name regardless of URI path', async () => {
  let receivedUri
  let receivedOptions
  const connectionLogger = { info() {}, warn() {}, error() {} }
  const connected = await connectDatabase({
    uri: 'mongodb://unit-test.invalid/totalsolution',
    connectionLogger,
    connect: async (uri, options) => {
      receivedUri = uri
      receivedOptions = options
    },
  })

  assert.equal(connected, true)
  assert.equal(receivedUri, 'mongodb://unit-test.invalid/totalsolution')
  assert.equal(receivedOptions.dbName, 'hii_beauty_dev')
  assert.equal(receivedOptions.autoCreate, false)
  assert.equal(receivedOptions.autoIndex, false)
})

test('database configuration does not attempt a connection without a URI', async () => {
  let connectionAttempted = false
  const connected = await connectDatabase({
    uri: '',
    connectionLogger: { info() {}, warn() {}, error() {} },
    connect: async () => { connectionAttempted = true },
  })

  assert.equal(connected, false)
  assert.equal(connectionAttempted, false)
})

test('backend refuses to start with a database name other than hii_beauty_dev', () => {
  const result = spawnSync(process.execPath, ['-e', "require('./src/config/env')"], {
    cwd: process.cwd(),
    env: { ...process.env, NODE_ENV: 'test', MONGODB_DB_NAME: 'production' },
    encoding: 'utf8',
  })
  assert.notEqual(result.status, 0)
})
