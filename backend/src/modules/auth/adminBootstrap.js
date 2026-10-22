const argon2 = require('argon2')
const { Types } = require('mongoose')
const { z } = require('zod')
const ROLE_CODE = 'SUPER_ADMIN'
const PERMISSIONS = require('../../platform/definitions').permissions
const identitySchema = z.object({
  fullName: z.string().trim().min(2).max(120),
  email: z.string().trim().email().max(254).transform(value => value.toLowerCase()),
  mobileNumber: z.string().regex(/^\+[1-9]\d{7,14}$/),
  password: z.string().min(16).max(128),
}).strict()
function assertDevelopment(env, db) {
  if (env.NODE_ENV !== 'development' || env.MONGODB_DB_NAME !== 'hii_beauty_dev'
    || db.databaseName !== 'hii_beauty_dev' || !env.MONGODB_URI
    || !env.SESSION_COOKIE_SECRET || env.SESSION_COOKIE_SECRET.length < 32
    || env.ADMIN_CATALOG_API_ENABLED) {
    throw new Error('Requires configured development credentials, hii_beauty_dev, and catalog disabled.')
  }
}
async function inspect(db, options = {}) {
  const roles = await db.collection('roles').find({}, options)
    .project({ roleCode: 1, permissions: 1, isActive: 1 }).toArray()
  const admins = await db.collection('users').find({ userType: /^admin$/i }, options)
    .project({ roleId: 1, status: 1, isActive: 1 }).toArray()
  const suitable = admins.filter(user => user.isActive === true && /^active$/i.test(user.status || '')
    && roles.some(role => String(role._id) === String(user.roleId) && role.isActive === true
      && Array.isArray(role.permissions) && PERMISSIONS.every(p => role.permissions.includes(p))))
  return { roles, adminCount: admins.length, suitableAdminCount: suitable.length }
}
async function bootstrap({ db, client, env, identity, approved }) {
  assertDevelopment(env, db)
  if (approved !== true) throw new Error('Explicit account creation approval is required.')
  const input = identitySchema.parse(identity)
  // Metadata commands must run before the transaction (MongoDB disallows them inside it).
  const collections = await db.listCollections({}, { nameOnly: true }).toArray()
  for (const name of ['users', 'roles', 'auth_sessions', 'audit_logs']) {
    if (!collections.some(collection => collection.name === name)) throw new Error('Required existing collection missing.')
  }
  const indexes = await db.collection('roles').listIndexes().toArray()
  if (!indexes.some(i => i.unique === true && i.key.roleCode === 1
    && Object.keys(i.key).length === 1 && !i.sparse && !i.partialFilterExpression)) {
    throw new Error('Existing unique roleCode index required; no indexes will be created.')
  }
  const passwordHash = await argon2.hash(input.password, {
    type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1,
  })
  const session = client.startSession()
  try {
    // Transaction plus the existing unique roleCode index serialize concurrent bootstraps.
    await session.withTransaction(async () => {
      const options = { session }
      const state = await inspect(db, options)
      if (state.suitableAdminCount || state.roles.some(role => ['SUPER_ADMIN', 'HII_BEAUTY_SUPER_ADMIN'].includes(role.roleCode))) {
        throw new Error('Existing suitable Admin or bootstrap role; review instead of duplicating.')
      }
      const conflict = await db.collection('users').findOne({
        $or: [
          { $expr: { $eq: [{ $toLower: '$email' }, input.email] } },
          { mobileNumber: input.mobileNumber },
        ],
      }, options)
      if (conflict) throw new Error('Identity already exists; no privileges changed.')
      const now = new Date()
      const userId = new Types.ObjectId()
      const roleId = new Types.ObjectId()
      const metadata = { createdAt: now, updatedAt: now, isActive: true, schemaVersion: 1 }
      await db.collection('roles').insertOne({
        _id: roleId, ...metadata, roleCode: ROLE_CODE, roleName: 'Hii Beauty Super Admin',
        description: 'Explicit development catalog administrator',
        permissions: [...PERMISSIONS], isSystemRole: true,
      }, options)
      await db.collection('users').insertOne({
        _id: userId, ...metadata, fullName: input.fullName, email: input.email,
        mobileNumber: input.mobileNumber, userType: 'admin', status: 'active',
        authProvider: 'password', passwordHash, roleId,
      }, options)
      await db.collection('audit_logs').insertOne({
        _id: new Types.ObjectId(), ...metadata, actorUserId: userId, actorRole: ROLE_CODE,
        action: 'admin.bootstrap', entityType: 'users', entityId: userId,
        changes: { roleCode: ROLE_CODE, permissions: [...PERMISSIONS], approval: 'local-terminal' },
        result: 'success', userAgent: 'development-bootstrap',
      }, options)
    })
  } finally { await session.endSession() }
}
module.exports = { ROLE_CODE, PERMISSIONS, identitySchema, assertDevelopment, inspect, bootstrap }
