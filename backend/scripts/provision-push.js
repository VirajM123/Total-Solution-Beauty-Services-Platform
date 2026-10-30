// Explicit schema provisioning; never rewrites an existing collection or its validator.
require('dotenv').config({ quiet: true })
const mongoose = require('mongoose')

async function provisionPush(db) {
  const schemas = {
    notification_preferences: {required:['_id','appType','notificationsEnabled','marketingNotificationsEnabled','updatedAt'],properties:{
      _id:{bsonType:'objectId'},appType:{enum:['customer','worker']},notificationsEnabled:{bsonType:'bool'},marketingNotificationsEnabled:{bsonType:'bool'},updatedAt:{bsonType:'date'},
    }},
    push_campaigns: { required: ['_id', 'resource', 'entityId', 'audiences', 'status', 'createdAt', 'createdBy', 'startsAt', 'lastUserId', 'processedCount'], properties: {
      _id: { bsonType: 'objectId' }, resource: { enum: ['offers', 'packages', 'banners'] }, entityId: { bsonType: 'objectId' },
      audiences: { bsonType: 'array', items: { enum: ['customer', 'worker'] }, minItems: 1, maxItems: 2 },
      status: { enum: ['pending', 'completed', 'cancelled'] }, createdAt: { bsonType: 'date' }, createdBy: { bsonType: 'objectId' },
      startsAt: { bsonType: 'date' }, lastUserId: { bsonType: 'objectId' }, processedCount: { bsonType: ['int', 'long', 'double'], minimum: 0 },
      completedAt: { bsonType: 'date' }, updatedAt: { bsonType: 'date' }, _revision: { bsonType: ['int', 'long', 'double'] },
    } },
    push_devices: { required: ['_id', 'userId', 'sessionId', 'appType', 'token', 'platform', 'isActive', 'registeredAt', 'updatedAt'], properties: {
      _id: { bsonType: 'objectId' }, userId: { bsonType: 'objectId' }, sessionId: { bsonType: 'objectId' },
      appType: { enum: ['customer', 'worker'] }, token: { bsonType: 'string', minLength: 20, maxLength: 4096 },
      platform: { enum: ['android', 'ios'] }, isActive: { bsonType: 'bool' }, registeredAt: { bsonType: 'date' }, updatedAt: { bsonType: 'date' },
    } },
    push_deliveries: { required: ['_id', 'notificationId', 'deviceId', 'status', 'attempts', 'nextAttemptAt', 'leaseUntil', 'expiresAt'], properties: {
      _id: { bsonType: 'objectId' }, notificationId: { bsonType: 'objectId' }, deviceId: { bsonType: 'objectId' },
      status: { enum: ['pending', 'sending', 'sent', 'failed', 'skipped'] }, attempts: { bsonType: ['int', 'long', 'double'], minimum: 0, maximum: 5 },
      nextAttemptAt: { bsonType: 'date' }, leaseUntil: { bsonType: 'date' }, expiresAt: { bsonType: 'date' }, sentAt: { bsonType: 'date' }, errorCode: { bsonType: 'string' },
    } },
  }
  const existing = await db.listCollections().toArray()
  for (const [name, schema] of Object.entries(schemas)) {
    const validator = { $jsonSchema: { bsonType: 'object', additionalProperties: false, ...schema } }
    const found = existing.find(item => item.name === name)
    if (!found) await db.createCollection(name, { validator, validationLevel: 'strict', validationAction: 'error' })
    else if (found.options?.validationLevel !== 'strict' || found.options?.validationAction !== 'error'
      || JSON.stringify(found.options?.validator) !== JSON.stringify(validator)) {
      throw Error(`Review the existing ${name} validator before enabling push; no schema was overwritten.`)
    }
  }
  await db.collection('push_deliveries').createIndex({ status: 1, nextAttemptAt: 1, leaseUntil: 1 })
  await db.collection('push_devices').createIndex({ userId: 1, appType: 1, isActive: 1 })
  await db.collection('push_devices').createIndex({ sessionId: 1 })
  await db.collection('push_deliveries').createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 })
  await db.collection('push_campaigns').createIndex({ status: 1, startsAt: 1 })
  await db.collection('notifications').createIndex({ createdAt: 1, _id: 1 })
  await db.collection('notifications').createIndex({ recipientUserId: 1, createdAt: 1, _id: 1 })
}

if (require.main === module) (async () => {
  const env = require('../src/config/env')
  if (!env.MONGODB_URI) throw Error('MONGODB_URI is required.')
  try {
    await mongoose.connect(env.MONGODB_URI, { dbName: env.MONGODB_DB_NAME })
    await provisionPush(mongoose.connection.db)
    console.log('Push collections and indexes are ready.')
  } finally { await mongoose.disconnect() }
})().catch(error => { console.error(error.message); process.exitCode = 1 })

module.exports = { provisionPush }
