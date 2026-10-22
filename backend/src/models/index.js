const mongoose = require('mongoose')

const { Schema } = mongoose
const objectId = Schema.Types.ObjectId
const mixed = Schema.Types.Mixed

function defineModel(modelName, collectionName, fields, indexes = []) {
  const schema = new Schema(fields, {
    collection: collectionName,
    strict: false,
    autoCreate: false,
    autoIndex: false,
    timestamps: false,
    versionKey: false,
    minimize: false,
  })
  for (const [keys, options] of indexes) schema.index(keys, options)
  return mongoose.models[modelName] || mongoose.model(modelName, schema, collectionName)
}

const sharedFields = {
  createdAt: Date,
  updatedAt: Date,
  createdBy: objectId,
  updatedBy: objectId,
  isActive: Boolean,
  schemaVersion: mixed,
}

const User = defineModel('User', 'users', {
  ...sharedFields,
  userType: String,
  fullName: String,
  mobileNumber: String,
  countryCode: String,
  email: String,
  emailVerifiedAt: Date,
  mobileVerifiedAt: Date,
  roleId: objectId,
  status: String,
  profileImageId: objectId,
  lastLoginAt: Date,
  authProvider: String,
  passwordHash: { type: String, select: false },
}, [[{ mobileNumber: 1 }, { unique: true }], [{ roleId: 1, status: 1 }]])

const Role = defineModel('Role', 'roles', {
  ...sharedFields,
  roleCode: String,
  roleName: String,
  description: String,
  permissions: [String],
  isSystemRole: Boolean,
}, [[{ roleCode: 1 }, { unique: true }]])

const AuthSession = defineModel('AuthSession', 'auth_sessions', {
  ...sharedFields,
  userId: objectId,
  refreshTokenHash: String,
  deviceId: String,
  devicePlatform: String,
  appType: String,
  ipAddress: String,
  userAgent: String,
  issuedAt: Date,
  expiresAt: Date,
  revokedAt: Date,
  lastSeenAt: Date,
}, [[{ userId: 1 }], [{ expiresAt: 1 }, { expireAfterSeconds: 0 }]])

const AuditLog = defineModel('AuditLog', 'audit_logs', {
  ...sharedFields,
  actorUserId: objectId,
  actorRole: String,
  action: String,
  entityType: String,
  entityId: objectId,
  changes: mixed,
  requestId: String,
  ipAddress: String,
  userAgent: String,
  result: String,
}, [[{ entityType: 1, entityId: 1, createdAt: -1 }]])

const ServiceCategory = defineModel('ServiceCategory', 'service_categories', {
  ...sharedFields,
  categoryCode: String,
  name: String,
  slug: String,
  description: String,
  thumbnailMediaId: objectId,
  bannerMediaId: objectId,
  iconKey: String,
  displayOrder: mixed,
  status: String,
  publishedAt: Date,
}, [[{ categoryCode: 1 }, { unique: true }], [{ slug: 1 }, { unique: true }]])

const Service = defineModel('Service', 'services', {
  ...sharedFields,
  serviceCode: String,
  categoryId: objectId,
  name: String,
  slug: String,
  shortDescription: String,
  fullDescription: String,
  benefits: [String],
  durationMinutes: mixed,
  pricePaise: Schema.Types.BigInt,
  compareAtPricePaise: Schema.Types.BigInt,
  imageMediaIds: [objectId],
  thumbnailMediaId: objectId,
  skillRequirements: [objectId],
  isHomeServiceAvailable: Boolean,
  serviceAreaIds: [objectId],
  displayOrder: mixed,
  status: String,
  publishedAt: Date,
}, [[{ serviceCode: 1 }, { unique: true }], [{ categoryId: 1, status: 1, displayOrder: 1 }]])

const MediaAsset = defineModel('MediaAsset', 'media_assets', {
  ...sharedFields,
  storageProvider: String,
  storageKey: String,
  publicUrl: String,
  mimeType: String,
  fileName: String,
  fileSizeBytes: mixed,
  width: mixed,
  height: mixed,
  altText: String,
  visibility: String,
  uploadedBy: objectId,
  uploadStatus: String,
}, [[{ storageProvider: 1, storageKey: 1 }]])

const ServiceArea = defineModel('ServiceArea', 'service_areas', {
  ...sharedFields,
  areaCode: String,
  name: String,
  city: String,
  state: String,
  postalCodes: [String],
  boundary: mixed,
  isServiceable: Boolean,
  operatingHours: mixed,
  displayOrder: mixed,
}, [[{ areaCode: 1 }, { unique: true }]])

module.exports = {
  User,
  Role,
  AuthSession,
  AuditLog,
  ServiceCategory,
  Service,
  MediaAsset,
  ServiceArea,
}
