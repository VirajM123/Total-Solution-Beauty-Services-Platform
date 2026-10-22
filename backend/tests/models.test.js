const assert = require('node:assert/strict')
const test = require('node:test')
const models = require('../src/models')

const expectedCollections = {
  User: 'users',
  Role: 'roles',
  AuthSession: 'auth_sessions',
  AuditLog: 'audit_logs',
  ServiceCategory: 'service_categories',
  Service: 'services',
  MediaAsset: 'media_assets',
  ServiceArea: 'service_areas',
}

test('verified models target existing collection names and cannot auto-create collections or indexes', () => {
  for (const [name, collection] of Object.entries(expectedCollections)) {
    const model = models[name]
    assert.equal(model.collection.name, collection)
    assert.equal(model.schema.options.collection, collection)
    assert.equal(model.schema.options.autoCreate, false)
    assert.equal(model.schema.options.autoIndex, false)
    assert.equal(model.schema.options.strict, false)
  }
})

test('verified models do not invent required fields absent from MongoDB validators', () => {
  for (const model of Object.values(models)) {
    for (const path of Object.values(model.schema.paths)) {
      assert.notEqual(path.isRequired, true, `${model.collection.name}.${path.path} must remain optional`)
    }
  }
})

test('service price fields use BSON-compatible integer storage types', () => {
  assert.equal(models.Service.schema.path('pricePaise').instance, 'BigInt')
  assert.equal(models.Service.schema.path('compareAtPricePaise').instance, 'BigInt')

  const mongoose = require('mongoose')
  const document = new models.Service({ pricePaise: 1234n })
  const serialized = mongoose.mongo.BSON.serialize(document.toBSON())
  const decoded = mongoose.mongo.BSON.deserialize(serialized, { promoteLongs: false })
  assert.equal(decoded.pricePaise._bsontype, 'Long')
  assert.equal(decoded.pricePaise.toString(), '1234')
})

test('verified references and media metadata have matching Mongoose types', () => {
  assert.equal(models.Service.schema.path('categoryId').instance, 'ObjectId')
  assert.equal(models.Service.schema.path('imageMediaIds').embeddedSchemaType.instance, 'ObjectId')
  assert.equal(models.ServiceCategory.schema.path('thumbnailMediaId').instance, 'ObjectId')
  assert.equal(models.ServiceArea.schema.path('postalCodes').embeddedSchemaType.instance, 'String')
  assert.equal(models.AuthSession.schema.path('expiresAt').instance, 'Date')
})

test('models declare every field observed in the eight live validators', () => {
  const expectedFields = {
    User: 'userType fullName mobileNumber countryCode email emailVerifiedAt mobileVerifiedAt roleId status profileImageId lastLoginAt authProvider passwordHash',
    Role: 'roleCode roleName description permissions isSystemRole',
    AuthSession: 'userId refreshTokenHash deviceId devicePlatform appType ipAddress userAgent issuedAt expiresAt revokedAt lastSeenAt',
    AuditLog: 'actorUserId actorRole action entityType entityId changes requestId ipAddress userAgent result',
    ServiceCategory: 'categoryCode name slug description thumbnailMediaId bannerMediaId iconKey displayOrder status publishedAt',
    Service: 'serviceCode categoryId name slug shortDescription fullDescription benefits durationMinutes pricePaise compareAtPricePaise imageMediaIds thumbnailMediaId skillRequirements isHomeServiceAvailable serviceAreaIds displayOrder status publishedAt',
    MediaAsset: 'storageProvider storageKey publicUrl mimeType fileName fileSizeBytes width height altText visibility uploadedBy uploadStatus',
    ServiceArea: 'areaCode name city state postalCodes boundary isServiceable operatingHours displayOrder',
  }

  for (const [modelName, fields] of Object.entries(expectedFields)) {
    const model = models[modelName]
    for (const field of fields.split(' ')) {
      assert.ok(model.schema.path(field), `${model.collection.name}.${field} must match the live validator`)
    }
  }
})

test('model index definitions match inspected MongoDB indexes without enabling automatic creation', () => {
  const expectedIndexes = {
    User: [
      [{ mobileNumber: 1 }, { unique: true }],
      [{ roleId: 1, status: 1 }, {}],
    ],
    Role: [[{ roleCode: 1 }, { unique: true }]],
    AuthSession: [
      [{ userId: 1 }, {}],
      [{ expiresAt: 1 }, { expireAfterSeconds: 0 }],
    ],
    AuditLog: [[{ entityType: 1, entityId: 1, createdAt: -1 }, {}]],
    ServiceCategory: [
      [{ categoryCode: 1 }, { unique: true }],
      [{ slug: 1 }, { unique: true }],
    ],
    Service: [
      [{ serviceCode: 1 }, { unique: true }],
      [{ categoryId: 1, status: 1, displayOrder: 1 }, {}],
    ],
    MediaAsset: [[{ storageProvider: 1, storageKey: 1 }, {}]],
    ServiceArea: [[{ areaCode: 1 }, { unique: true }]],
  }

  for (const [modelName, expected] of Object.entries(expectedIndexes)) {
    const model = models[modelName]
    assert.deepEqual(model.schema.indexes(), expected, `${model.collection.name} index definitions`)
    assert.equal(model.schema.options.autoIndex, false)
  }
})
