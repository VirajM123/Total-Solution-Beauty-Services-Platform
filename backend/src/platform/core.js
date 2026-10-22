const express = require('express')
const { createHash } = require('node:crypto')
const mongoose = require('mongoose')
const { z } = require('zod')
const { HttpError } = require('../middleware/errorHandler')
const { requireSameOrigin } = require('../middleware/authorize')
const idSchema = z.string().regex(/^[a-f0-9]{24}$/i)
const money = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER)
const id = value => new mongoose.Types.ObjectId(idSchema.parse(String(value)))
const fail = (status, code, message) => { throw new HttpError(status, code, message) }
const reply = (req, res, data, status = 200) => res.status(status).json({ success: true, data: serialize(data), requestId: req.id })
function serialize(value) {
  if (typeof value === 'bigint' || value?._bsontype === 'Long') return value.toString()
  if (value instanceof Date) return value.toISOString()
  if (value?._bsontype === 'ObjectId') return value.toHexString()
  if (Array.isArray(value)) return value.map(serialize)
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k,serialize(v)]))
  return value
}
const handler = run => (req,res,next) => Promise.resolve().then(() => run(req,res)).catch(next)
function protectedRouter(auth) {
  const router = express.Router()
  router.use(auth.requireAuthenticated)
  router.use((req,res,next) => {
    if (['GET','HEAD','OPTIONS'].includes(req.method)) return next()
    requireSameOrigin(req,res,error => error ? next(error) : auth.requireCsrf(req,res,next))
  })
  return router
}
const listSchema = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(25),
  search: z.string().trim().max(100).optional(), status: z.string().max(40).optional(),
  from: z.iso.date().optional(), to: z.iso.date().optional(),
}).strict().refine(q => !q.from || !q.to || q.from <= q.to, 'Invalid date range')
function listFilter(query, fields = ['name'], dateField = 'createdAt') {
  const q = listSchema.parse(query), filter = {}
  if (q.status) filter.status = q.status
  if (q.search) {
    // Escape every non-word character; user text can never become a regex operator.
    const pattern = new RegExp(q.search.replace(/[^a-zA-Z0-9_]/g, char => '\\' + char), 'i')
    filter.$or = fields.map(field => ({ [field]: pattern }))
  }
  if (q.from || q.to) {
    filter[dateField] = {}
    if (q.from) filter[dateField].$gte = new Date(q.from + 'T00:00:00+05:30')
    if (q.to) filter[dateField].$lt = new Date(new Date(q.to + 'T00:00:00+05:30').getTime() + 86400000)
  }
  return { q, filter }
}
async function list(db, collection, query, { fields, projection, scope = {}, dateField } = {}) {
  const { q, filter } = listFilter(query, fields, dateField)
  const where = { $and: [scope, filter] }
  const [items,total] = await Promise.all([
    db.collection(collection).find(where, { projection }).sort({ createdAt: -1, _id: 1 })
      .skip((q.page-1)*q.limit).limit(q.limit).toArray(),
    db.collection(collection).countDocuments(where),
  ])
  return { items, pagination: { page:q.page, limit:q.limit,total,pages:Math.ceil(total/q.limit) } }
}
async function atomic(db, req, action, collection, run) {
  const client = db.transactionClient || mongoose.connection.getClient()
  const session = client.startSession()
  let result
  try {
    await session.withTransaction(async () => {
      result = await run(session)
      await db.collection('audit_logs').insertOne({
        actorUserId: req.auth.user._id, actorRole: req.auth.role?.roleCode || req.actorType,
        action, entityType:collection, entityId:result._id,
        changes:{ fields:Object.keys(req.body || {}).filter(k => !/password|token|otp|secret/i.test(k)) },
        requestId:req.id, createdAt:new Date(), result:'success', isActive:true,
      }, { session })
    })
    return result
  } finally { await session.endSession() }
}
function requestIdentity(req, namespace) {
  const key = z.string().min(16).max(100).regex(/^[a-zA-Z0-9_-]+$/).parse(req.get('x-idempotency-key'))
  return {
    _id: new mongoose.Types.ObjectId(createHash('sha256').update(String(req.auth.user._id)+':'+namespace+':'+key).digest('hex').slice(0,24)),
    requestHash: createHash('sha256').update(JSON.stringify(req.body)).digest('hex'),
  }
}
async function compareAndSet(db, collection, before, changes, session) {
  const result = await db.collection(collection).findOneAndUpdate(
    { _id:before._id, _revision: before._revision === undefined ? { $exists:false } : before._revision },
    { $set:{ ...changes, updatedAt:new Date() }, $inc:{ _revision:1 } },
    { session, returnDocument:'after' },
  )
  if (!result) fail(409,'STALE_RECORD','This record changed. Refresh and retry.')
  return result
}
async function requireRecord(db, collection, resourceId, session, scope = {}) {
  const record = await db.collection(collection).findOne({ _id:id(resourceId), ...scope }, { session })
  if (!record) fail(404,'NOT_FOUND','Record was not found.')
  return record
}
function csv(rows) {
  return '\uFEFF'+rows.map(row => row.map(value => '"'+String(value ?? '').replace(/^[ \t\r\n]*[=+@-]/, "'$&").replaceAll('"','""')+'"').join(',')).join('\r\n')
}
module.exports = { idSchema, money, id, fail, reply, serialize, handler, protectedRouter, listSchema, listFilter, list, atomic, requestIdentity, compareAndSet, requireRecord, csv }
