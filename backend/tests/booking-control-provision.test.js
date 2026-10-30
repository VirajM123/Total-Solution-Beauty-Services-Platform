const assert = require('node:assert/strict')
const test = require('node:test')
const env = require('../src/config/env')
const { provisionBookingControlOtps, validator } = require('../src/platform/provision-booking-control-otps')
test('development OTP provisioning creates only the missing collection and leaves existing validators intact', async () => {
  const previous = env.NODE_ENV
  env.NODE_ENV = 'development'
  const calls = []
  let exists = false
  const db = { databaseName: 'hii_beauty_dev', listCollections: () => ({ toArray: async () => exists ? [{}] : [] }),
    createCollection: async (name, options) => { calls.push({ name, options }); exists = true } }
  try {
    await provisionBookingControlOtps(db)
    await provisionBookingControlOtps(db)
    assert.equal(calls.length, 1)
    assert.equal(calls[0].name, 'booking_control_otps')
    assert.equal(calls[0].options.validationLevel, 'strict')
    assert.equal(calls[0].options.validator, validator)
    await assert.rejects(provisionBookingControlOtps({ ...db, databaseName: 'production' }))
    env.NODE_ENV = 'production'
    await assert.rejects(provisionBookingControlOtps(db))
    assert.equal(calls.length, 1)
  } finally { env.NODE_ENV = previous }
})
