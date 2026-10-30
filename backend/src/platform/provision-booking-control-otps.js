const env = require('../config/env')
const collectionName = 'booking_control_otps'
const number = { bsonType: ['int', 'long', 'double'] }
const validator = { $jsonSchema: {
  bsonType: 'object', additionalProperties: false,
  required: ['bookingId', 'workerUserId', 'purpose', 'otpHash', 'attemptCount', 'maxAttempts', 'createdAt', 'expiresAt', 'issuedBy', 'status', 'isActive'],
  properties: {
    _id: { bsonType: 'objectId' }, bookingId: { bsonType: 'objectId' },
    workerUserId: { bsonType: 'objectId' }, assignmentId: { bsonType: ['objectId', 'null'] },
    issuedBy: { bsonType: 'objectId' },
    purpose: { enum: ['duration_extension', 'service_completion'] },
    otpHash: { bsonType: 'string' }, attemptCount: { ...number, minimum: 0 },
    maxAttempts: { ...number, minimum: 1, maximum: 10 },
    status: { enum: ['active', 'revoked', 'expired', 'locked', 'consumed'] },
    isActive: { bsonType: 'bool' }, createdAt: { bsonType: 'date' },
    expiresAt: { bsonType: 'date' }, revokedAt: { bsonType: 'date' },
    consumedAt: { bsonType: 'date' }, verifiedAt: { bsonType: 'date' },
    updatedAt: { bsonType: 'date' }, _revision: number, schemaVersion: number,
  },
} }
async function provisionBookingControlOtps(db) {
  if (env.NODE_ENV !== 'development' || env.MONGODB_DB_NAME !== 'hii_beauty_dev' || db.databaseName !== 'hii_beauty_dev') {
    throw new Error('Booking control OTP provisioning is restricted to hii_beauty_dev development.')
  }
  if ((await db.listCollections({ name: collectionName }).toArray()).length) return
  try {
    await db.createCollection(collectionName, { validator, validationLevel: 'strict', validationAction: 'error' })
  } catch (error) {
    if (error.code !== 48) throw error // Another startup may have created it.
  }
}
module.exports = { provisionBookingControlOtps, validator }
