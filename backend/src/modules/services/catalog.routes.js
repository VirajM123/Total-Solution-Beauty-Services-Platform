const express = require('express')
const mongoose = require('mongoose')
const { z } = require('zod')
const { HttpError } = require('../../middleware/errorHandler')
const { requireSameOrigin } = require('../../middleware/authorize')

const objectIdPattern = /^[a-f\d]{24}$/i
const objectIdSchema = z.string().regex(objectIdPattern, 'A valid resource id is required.')
const lifecycleSchema = z.enum(['draft', 'published', 'archived'])
const categoryFields = {
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(1000).optional(),
  thumbnailMediaId: objectIdSchema.nullable().optional(),
  displayOrder: z.number().int().min(0).max(100000).optional(),
}
const categoryCreateSchema = z.object({
  ...categoryFields,
  status: lifecycleSchema.default('draft'),
}).strict()
const categoryUpdateSchema = z.object(categoryFields).strict().refine(value => Object.keys(value).length > 0)
const statusSchema = z.object({ status: lifecycleSchema }).strict()
const serviceFields = {
  name: z.string().trim().min(2).max(120),
  categoryId: objectIdSchema,
  shortDescription: z.string().trim().max(240).optional(),
  fullDescription: z.string().trim().max(3000).optional(),
  priceRupees: z.string().regex(/^(?:0|[1-9]\d{0,8})(?:\.\d{1,2})?$/, 'Price must be rupees with at most two decimal places.'),
  durationMinutes: z.number().int().min(1).max(1440),
  imageMediaIds: z.array(objectIdSchema).max(10).optional(),
  thumbnailMediaId: objectIdSchema.nullable().optional(),
  serviceAreaIds: z.array(objectIdSchema).max(100).optional(),
  isHomeServiceAvailable: z.boolean().optional(),
  displayOrder: z.number().int().min(0).max(100000).optional(),
}
const serviceCreateSchema = z.object({
  ...serviceFields,
  status: lifecycleSchema.default('draft'),
}).strict()
const serviceUpdateSchema = z.object(serviceFields).partial().strict().refine(value => Object.keys(value).length > 0)
const listQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(25),
  search: z.string().trim().max(100).optional(),
  status: lifecycleSchema.optional(),
  categoryId: objectIdSchema.optional(),
  serviceAreaId: objectIdSchema.optional(),
  sort: z.enum(['name', 'displayOrder', 'createdAt', 'updatedAt']).default('displayOrder'),
  order: z.enum(['asc', 'desc']).default('asc'),
})

function slugify(value) {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 56) || 'item'
}

function isPersistentPublicImage(media) {
  return typeof media.storageProvider === 'string'
    && !['local', 'memory', 'browser'].includes(media.storageProvider.toLowerCase())
    && typeof media.storageKey === 'string'
    && !/^(?:blob:|data:|file:|\/|[a-z]:)/i.test(media.storageKey)
    && typeof media.publicUrl === 'string'
    && /^https:\/\//i.test(media.publicUrl)
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function priceRupeesToPaise(value) {
  if (typeof value !== 'string' || !/^(?:0|[1-9]\d{0,8})(?:\.\d{1,2})?$/.test(value)) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Price must be rupees with at most two decimal places.')
  }
  const [whole, fraction = ''] = value.split('.')
  const paise = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2))
  if (paise > BigInt(Number.MAX_SAFE_INTEGER)) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Price exceeds the supported range.')
  }
  return paise
}

function paiseToString(value) {
  return value == null ? null : value.toString()
}

function serializeService(service) {
  const value = { ...service, pricePaise: paiseToString(service.pricePaise), compareAtPricePaise: paiseToString(service.compareAtPricePaise) }
  return value
}

function publicCategory(category, media) {
  return {
    id: category._id.toString(),
    name: category.name,
    slug: category.slug,
    description: category.description || '',
    displayOrder: category.displayOrder ?? 0,
    image: media ? {
      url: media.publicUrl,
      mimeType: media.mimeType,
      width: media.width,
      height: media.height,
      altText: media.altText || category.name,
    } : null,
  }
}

function publicService(service, category, mediaById) {
  return {
    id: service._id.toString(),
    name: service.name,
    slug: service.slug,
    category: { id: category._id.toString(), name: category.name, slug: category.slug },
    shortDescription: service.shortDescription || '',
    description: service.fullDescription || '',
    benefits: service.benefits || [],
    durationMinutes: service.durationMinutes,
    pricePaise: paiseToString(service.pricePaise),
    compareAtPricePaise: paiseToString(service.compareAtPricePaise),
    images: (service.imageMediaIds || []).map(id => mediaById.get(id.toString())).filter(Boolean).map(media => ({
      url: media.publicUrl, mimeType: media.mimeType, width: media.width, height: media.height, altText: media.altText || service.name,
    })),
    thumbnail: mediaById.get(service.thumbnailMediaId?.toString())?.publicUrl || null,
    isHomeServiceAvailable: Boolean(service.isHomeServiceAvailable),
    displayOrder: service.displayOrder ?? 0,
  }
}

function apiSuccess(req, res, data, status = 200) {
  res.status(status).json({ success: true, data, requestId: req.id })
}

function parseListQuery(query) {
  const parsed = listQuerySchema.safeParse(query)
  if (!parsed.success) throw new HttpError(400, 'VALIDATION_ERROR', 'List query is invalid.')
  return parsed.data
}

function idOrThrow(id) {
  if (!objectIdPattern.test(id)) throw new HttpError(400, 'VALIDATION_ERROR', 'Resource id is invalid.')
  return id
}

function duplicateError(error) {
  return error?.code === 11000
    ? new HttpError(409, 'DUPLICATE_RESOURCE', 'A category or service with the same unique code or slug already exists.')
    : error
}

async function nextUniqueCode(Model, field, prefix, slug, session) {
  const base = `${prefix}-${slug}`.toUpperCase().replace(/[^A-Z0-9-]/g, '').slice(0, 64)
  let candidate = base
  let suffix = 2
  while (await Model.exists({ [field]: candidate }).session(session)) {
    candidate = `${base.slice(0, 60)}-${suffix++}`
  }
  return candidate
}

async function nextUniqueSlug(Model, slug, session) {
  let candidate = slug
  let suffix = 2
  while (await Model.exists({ slug: candidate }).session(session)) {
    const suffixText = `-${suffix++}`
    candidate = `${slug.slice(0, 64 - suffixText.length)}${suffixText}`
  }
  return candidate
}

async function assertUniqueName(Model, name, exceptId, extraFilter = {}) {
  const filter = { ...extraFilter, name: new RegExp(`^${escapeRegex(name)}$`, 'i') }
  if (exceptId) filter._id = { $ne: exceptId }
  if (await Model.exists(filter)) throw new HttpError(409, 'DUPLICATE_RESOURCE', 'A resource with this name already exists.')
}

async function assertPublicMedia(models, mediaIds) {
  const ids = [...new Set(mediaIds.filter(Boolean).map(String))]
  if (!ids.length) return []
  if (ids.some(id => !objectIdPattern.test(id))) throw new HttpError(400, 'VALIDATION_ERROR', 'A media reference is invalid.')
  const media = await models.MediaAsset.find({
    _id: { $in: ids },
    isActive: { $ne: false },
    visibility: 'public',
    mimeType: /^image\//i,
  }).select('_id storageProvider storageKey publicUrl mimeType width height altText').lean()
  const valid = media.filter(isPersistentPublicImage)
  if (valid.length !== ids.length) {
    throw new HttpError(400, 'INVALID_MEDIA_REFERENCE', 'Select persistent public image assets uploaded through an approved storage provider.')
  }
  return valid
}

async function assertServiceAreas(ServiceArea, ids = []) {
  const uniqueIds = [...new Set(ids)]
  if (!uniqueIds.length) return
  const count = await ServiceArea.countDocuments({ _id: { $in: uniqueIds }, isActive: { $ne: false }, isServiceable: true })
  if (count !== uniqueIds.length) throw new HttpError(400, 'INVALID_SERVICE_AREA', 'One or more service areas are missing or inactive.')
}

async function commitWithAudit(models, req, actor, action, entityType, mutate) {
  const session = await mongoose.startSession()
  let result
  try {
    await session.withTransaction(async () => {
      result = await mutate(session)
      const audit = new models.AuditLog({
        actorUserId: actor.user._id,
        actorRole: actor.role.roleCode,
        action,
        entityType,
        entityId: result._id,
        changes: { fields: Object.keys(req.body || {}) },
        requestId: req.id,
        ipAddress: req.ip,
        userAgent: req.get('user-agent') || '',
        result: 'success',
        createdAt: new Date(),
        isActive: true,
      })
      await audit.save({ session })
    })
    return result
  } catch (error) {
    throw duplicateError(error)
  } finally {
    await session.endSession()
  }
}

function createCatalogRouters({ models, auth, sessionSecret = '', storageConfigured = false }) {
  const adminCategories = express.Router()
  const adminServices = express.Router()
  const publicCatalog = express.Router()
  const permission = auth.requireAuthenticated
  const protectStateChanges = (req, res, next) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next()
    requireSameOrigin(req, res, error => {
      if (error) return next(error)
      auth.requireCsrf(req, res, next)
    })
  }

  adminCategories.use(permission, protectStateChanges)
  adminServices.use(permission, protectStateChanges)

  adminCategories.get('/', auth.requirePermission('catalog.categories.read'), async (req, res, next) => {
    try {
      const query = parseListQuery(req.query)
      const filter = {}
      if (query.status) filter.status = query.status
      if (query.search) {
        const pattern = new RegExp(escapeRegex(query.search), 'i')
        filter.$or = [{ name: pattern }, { categoryCode: pattern }, { slug: pattern }, { description: pattern }]
      }
      const sort = { [query.sort]: query.order === 'asc' ? 1 : -1, _id: 1 }
      const [items, total] = await Promise.all([
        models.ServiceCategory.find(filter).sort(sort).skip((query.page - 1) * query.limit).limit(query.limit).lean(),
        models.ServiceCategory.countDocuments(filter),
      ])
      apiSuccess(req, res, { items, pagination: { page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) } })
    } catch (error) { next(error) }
  })

  adminCategories.get('/:categoryId', auth.requirePermission('catalog.categories.read'), async (req, res, next) => {
    try {
      const category = await models.ServiceCategory.findById(idOrThrow(req.params.categoryId)).lean()
      if (!category) throw new HttpError(404, 'NOT_FOUND', 'Category was not found.')
      apiSuccess(req, res, category)
    } catch (error) { next(error) }
  })

  adminCategories.post('/', auth.requirePermission('catalog.categories.create'), async (req, res, next) => {
    const parsed = categoryCreateSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Category fields are invalid.'))
    try {
      const input = parsed.data
      await assertUniqueName(models.ServiceCategory, input.name)
      const category = await commitWithAudit(models, req, req.auth, 'catalog.category.create', 'service_category', async session => {
        if (input.thumbnailMediaId) await assertPublicMedia(models, [input.thumbnailMediaId])
        const slug = await nextUniqueSlug(models.ServiceCategory, slugify(input.name), session)
        const categoryCode = await nextUniqueCode(models.ServiceCategory, 'categoryCode', 'CAT', slug, session)
        const doc = new models.ServiceCategory({
          categoryCode,
          slug,
          name: input.name,
          description: input.description || '',
          thumbnailMediaId: input.thumbnailMediaId || undefined,
          displayOrder: input.displayOrder ?? 0,
          status: input.status,
          publishedAt: input.status === 'published' ? new Date() : undefined,
          isActive: input.status !== 'archived',
          schemaVersion: 1,
          createdAt: new Date(),
          updatedAt: new Date(),
          createdBy: req.auth.user._id,
          updatedBy: req.auth.user._id,
        })
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, category.toObject(), 201)
    } catch (error) { next(duplicateError(error)) }
  })

  adminCategories.patch('/:categoryId/status', auth.requirePermission('catalog.categories.publish'), async (req, res, next) => {
    const parsed = statusSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Category status is invalid.'))
    try {
      const id = idOrThrow(req.params.categoryId)
      const category = await commitWithAudit(models, req, req.auth, 'catalog.category.status', 'service_category', async session => {
        const doc = await models.ServiceCategory.findById(id).session(session)
        if (!doc) throw new HttpError(404, 'NOT_FOUND', 'Category was not found.')
        if (parsed.data.status === 'published' && doc.thumbnailMediaId) {
          await assertPublicMedia(models, [doc.thumbnailMediaId.toString()])
        }
        doc.status = parsed.data.status
        doc.isActive = parsed.data.status !== 'archived'
        doc.publishedAt = parsed.data.status === 'published' ? (doc.publishedAt || new Date()) : null
        doc.updatedAt = new Date()
        doc.updatedBy = req.auth.user._id
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, category.toObject())
    } catch (error) { next(error) }
  })

  adminCategories.patch('/:categoryId', auth.requirePermission('catalog.categories.update'), async (req, res, next) => {
    const parsed = categoryUpdateSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Category fields are invalid.'))
    try {
      const id = idOrThrow(req.params.categoryId)
      if (parsed.data.name) await assertUniqueName(models.ServiceCategory, parsed.data.name, id)
      const category = await commitWithAudit(models, req, req.auth, 'catalog.category.update', 'service_category', async session => {
        const doc = await models.ServiceCategory.findById(id).session(session)
        if (!doc) throw new HttpError(404, 'NOT_FOUND', 'Category was not found.')
        if (parsed.data.thumbnailMediaId) await assertPublicMedia(models, [parsed.data.thumbnailMediaId])
        Object.assign(doc, parsed.data)
        doc.updatedAt = new Date()
        doc.updatedBy = req.auth.user._id
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, category.toObject())
    } catch (error) { next(error) }
  })

  adminServices.get('/', auth.requirePermission('catalog.services.read'), async (req, res, next) => {
    try {
      const query = parseListQuery(req.query)
      const filter = {}
      if (query.status) filter.status = query.status
      if (query.categoryId) filter.categoryId = query.categoryId
      if (query.serviceAreaId) filter.serviceAreaIds = query.serviceAreaId
      if (query.search) {
        const pattern = new RegExp(escapeRegex(query.search), 'i')
        filter.$or = [{ name: pattern }, { serviceCode: pattern }, { slug: pattern }, { shortDescription: pattern }, { fullDescription: pattern }]
      }
      const sort = { [query.sort]: query.order === 'asc' ? 1 : -1, _id: 1 }
      const [items, total] = await Promise.all([
        models.Service.find(filter).sort(sort).skip((query.page - 1) * query.limit).limit(query.limit).lean(),
        models.Service.countDocuments(filter),
      ])
      apiSuccess(req, res, { items: items.map(serializeService), pagination: { page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) } })
    } catch (error) { next(error) }
  })

  adminServices.get('/:serviceId', auth.requirePermission('catalog.services.read'), async (req, res, next) => {
    try {
      const service = await models.Service.findById(idOrThrow(req.params.serviceId)).lean()
      if (!service) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
      apiSuccess(req, res, serializeService(service))
    } catch (error) { next(error) }
  })

  adminServices.post('/', auth.requirePermission('catalog.services.create'), async (req, res, next) => {
    const parsed = serviceCreateSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Service fields are invalid.'))
    try {
      const input = parsed.data
      const category = await models.ServiceCategory.findOne({ _id: input.categoryId, status: { $ne: 'archived' }, isActive: { $ne: false } }).lean()
      if (!category) throw new HttpError(400, 'INVALID_CATEGORY', 'Select an existing non-archived category.')
      if (input.status === 'published' && category.status !== 'published') {
        throw new HttpError(400, 'INVALID_CATEGORY', 'Publish the service category before publishing this service.')
      }
      await assertUniqueName(models.Service, input.name, null, { categoryId: input.categoryId })
      const mediaIds = [...(input.imageMediaIds || []), input.thumbnailMediaId].filter(Boolean)
      if (input.status === 'published') {
        if (!input.shortDescription || !input.fullDescription || !input.thumbnailMediaId || !input.imageMediaIds?.length) {
          throw new HttpError(400, 'SERVICE_INCOMPLETE', 'A published service requires short and full descriptions, a thumbnail, and at least one image.')
        }
        if (!storageConfigured) throw new HttpError(503, 'STORAGE_NOT_CONFIGURED', 'Persistent image storage is not configured; services cannot be published.')
      }
      await assertPublicMedia(models, mediaIds)
      await assertServiceAreas(models.ServiceArea, input.serviceAreaIds)
      const pricePaise = priceRupeesToPaise(input.priceRupees)
      const service = await commitWithAudit(models, req, req.auth, 'catalog.service.create', 'service', async session => {
        const slug = await nextUniqueSlug(models.Service, slugify(input.name), session)
        const serviceCode = await nextUniqueCode(models.Service, 'serviceCode', 'SVC', slug, session)
        const doc = new models.Service({
          serviceCode,
          categoryId: new mongoose.Types.ObjectId(input.categoryId),
          name: input.name,
          slug,
          shortDescription: input.shortDescription || '',
          fullDescription: input.fullDescription || '',
          durationMinutes: input.durationMinutes,
          pricePaise,
          imageMediaIds: input.imageMediaIds || [],
          thumbnailMediaId: input.thumbnailMediaId || undefined,
          serviceAreaIds: input.serviceAreaIds || [],
          isHomeServiceAvailable: input.isHomeServiceAvailable ?? true,
          displayOrder: input.displayOrder ?? 0,
          status: input.status,
          publishedAt: input.status === 'published' ? new Date() : undefined,
          isActive: input.status !== 'archived',
          schemaVersion: 1,
          createdAt: new Date(),
          updatedAt: new Date(),
          createdBy: req.auth.user._id,
          updatedBy: req.auth.user._id,
        })
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, serializeService(service.toObject()), 201)
    } catch (error) { next(duplicateError(error)) }
  })

  adminServices.patch('/:serviceId', auth.requirePermission('catalog.services.update'), async (req, res, next) => {
    const parsed = serviceUpdateSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Service fields are invalid.'))
    try {
      const id = idOrThrow(req.params.serviceId)
      const input = parsed.data
      const existing = await models.Service.findById(id).lean()
      if (!existing) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
      const categoryId = input.categoryId || existing.categoryId.toString()
      const category = await models.ServiceCategory.findOne({ _id: categoryId, status: { $ne: 'archived' }, isActive: { $ne: false } }).lean()
      if (!category) throw new HttpError(400, 'INVALID_CATEGORY', 'Select an existing non-archived category.')
      if (existing.status === 'published' && category.status !== 'published') {
        throw new HttpError(400, 'INVALID_CATEGORY', 'A published service must belong to a published category.')
      }
      if (input.name) await assertUniqueName(models.Service, input.name, id, { categoryId })
      const effective = { ...existing, ...input }
      const mediaIds = input.imageMediaIds || existing.imageMediaIds || []
      const thumbnailId = input.thumbnailMediaId === undefined ? existing.thumbnailMediaId?.toString() : input.thumbnailMediaId
      await assertPublicMedia(models, [...mediaIds, thumbnailId].filter(Boolean))
      await assertServiceAreas(models.ServiceArea, input.serviceAreaIds || existing.serviceAreaIds?.map(String))
      const service = await commitWithAudit(models, req, req.auth, 'catalog.service.update', 'service', async session => {
        const doc = await models.Service.findById(id).session(session)
        if (!doc) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
        if (input.priceRupees !== undefined) doc.pricePaise = priceRupeesToPaise(input.priceRupees)
        for (const [key, value] of Object.entries(input)) {
          if (key !== 'priceRupees') doc[key] = value
        }
        if (input.categoryId) doc.categoryId = new mongoose.Types.ObjectId(input.categoryId)
        if (doc.status === 'published' && (!effective.shortDescription || !effective.fullDescription || !thumbnailId || !mediaIds.length)) {
          throw new HttpError(400, 'SERVICE_INCOMPLETE', 'Published services must retain descriptions and persistent image references.')
        }
        doc.updatedAt = new Date()
        doc.updatedBy = req.auth.user._id
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, serializeService(service.toObject()))
    } catch (error) { next(duplicateError(error)) }
  })

  adminServices.patch('/:serviceId/status', auth.requirePermission('catalog.services.publish'), async (req, res, next) => {
    const parsed = statusSchema.safeParse(req.body)
    if (!parsed.success) return next(new HttpError(400, 'VALIDATION_ERROR', 'Service status is invalid.'))
    try {
      const id = idOrThrow(req.params.serviceId)
      const service = await commitWithAudit(models, req, req.auth, 'catalog.service.status', 'service', async session => {
        const doc = await models.Service.findById(id).session(session)
        if (!doc) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
        if (parsed.data.status === 'published') {
          if (!doc.shortDescription || !doc.fullDescription || !doc.thumbnailMediaId || !doc.imageMediaIds?.length) {
            throw new HttpError(400, 'SERVICE_INCOMPLETE', 'A published service requires short and full descriptions, a thumbnail, and at least one image.')
          }
          if (!storageConfigured) throw new HttpError(503, 'STORAGE_NOT_CONFIGURED', 'Persistent image storage is not configured; services cannot be published.')
          await assertPublicMedia(models, [...doc.imageMediaIds, doc.thumbnailMediaId])
          await assertServiceAreas(models.ServiceArea, doc.serviceAreaIds?.map(String))
          const category = await models.ServiceCategory.findOne({ _id: doc.categoryId, status: 'published', isActive: { $ne: false } }).session(session).lean()
          if (!category) throw new HttpError(400, 'INVALID_CATEGORY', 'Publish the service category before publishing this service.')
        }
        doc.status = parsed.data.status
        doc.isActive = parsed.data.status !== 'archived'
        doc.publishedAt = parsed.data.status === 'published' ? (doc.publishedAt || new Date()) : null
        doc.updatedAt = new Date()
        doc.updatedBy = req.auth.user._id
        await doc.save({ session })
        return doc
      })
      apiSuccess(req, res, serializeService(service.toObject()))
    } catch (error) { next(error) }
  })

  publicCatalog.get('/categories', async (req, res, next) => {
    try {
      const query = parseListQuery(req.query)
      const filter = { status: { $in: ['published', 'PUBLISHED', 'Published'] }, isActive: { $ne: false } }
      if (query.search) filter.name = new RegExp(escapeRegex(query.search), 'i')
      const [items, total] = await Promise.all([
        models.ServiceCategory.find(filter).sort({ displayOrder: 1, _id: 1 }).skip((query.page - 1) * query.limit).limit(query.limit).lean(),
        models.ServiceCategory.countDocuments(filter),
      ])
      const mediaIds = items.map(item => item.thumbnailMediaId).filter(Boolean)
      const mediaItems = await models.MediaAsset.find({
        _id: { $in: mediaIds },
        isActive: { $ne: false },
        visibility: 'public',
        mimeType: /^image\//i,
      }).select('_id storageProvider storageKey publicUrl mimeType width height altText').lean()
      const safeMedia = mediaItems.filter(isPersistentPublicImage)
      const byId = new Map(safeMedia.map(media => [media._id.toString(), media]))
      apiSuccess(req, res, { items: items.map(item => publicCategory(item, byId.get(item.thumbnailMediaId?.toString()))), pagination: { page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) } })
    } catch (error) { next(error) }
  })

  publicCatalog.get('/services', async (req, res, next) => {
    try {
      const query = parseListQuery(req.query)
      if (query.serviceAreaId) {
        const serviceArea = await models.ServiceArea.exists({
          _id: query.serviceAreaId,
          isActive: { $ne: false },
          isServiceable: true,
        })
        if (!serviceArea) throw new HttpError(400, 'INVALID_SERVICE_AREA', 'The requested service area is unavailable.')
      }
      const categoryFilter = { status: { $in: ['published', 'PUBLISHED', 'Published'] }, isActive: { $ne: false } }
      if (query.categoryId) categoryFilter._id = query.categoryId
      const categories = await models.ServiceCategory.find(categoryFilter).select('_id name slug').lean()
      const categoryIds = categories.map(category => category._id)
      const filter = { status: { $in: ['published', 'PUBLISHED', 'Published'] }, isActive: { $ne: false }, categoryId: { $in: categoryIds } }
      if (query.categoryId) filter.categoryId = query.categoryId
      if (query.serviceAreaId) {
        filter.$or = [
          { serviceAreaIds: query.serviceAreaId },
          { serviceAreaIds: { $size: 0 } },
          { serviceAreaIds: { $exists: false } },
        ]
      }
      if (query.search) {
        const pattern = new RegExp(escapeRegex(query.search), 'i')
        filter.$and = [...(filter.$and || []), { $or: [{ name: pattern }, { shortDescription: pattern }, { fullDescription: pattern }] }]
      }
      const [items, total] = await Promise.all([
        models.Service.find(filter).sort({ displayOrder: 1, _id: 1 }).skip((query.page - 1) * query.limit).limit(query.limit).lean(),
        models.Service.countDocuments(filter),
      ])
      const categoryById = new Map(categories.map(item => [item._id.toString(), item]))
      const eligible = items.filter(item => categoryById.has(item.categoryId.toString()))
      const mediaIds = eligible.flatMap(item => [...(item.imageMediaIds || []), item.thumbnailMediaId].filter(Boolean))
      const mediaItems = await models.MediaAsset.find({
        _id: { $in: mediaIds },
        isActive: { $ne: false },
        visibility: 'public',
        mimeType: /^image\//i,
      }).select('_id storageProvider storageKey publicUrl mimeType width height altText').lean()
      const safeMedia = mediaItems.filter(isPersistentPublicImage)
      const mediaById = new Map(safeMedia.map(media => [media._id.toString(), media]))
      apiSuccess(req, res, { items: eligible.map(item => publicService(item, categoryById.get(item.categoryId.toString()), mediaById)), pagination: { page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) } })
    } catch (error) { next(error) }
  })

  publicCatalog.get('/services/:serviceId', async (req, res, next) => {
    try {
      const id = idOrThrow(req.params.serviceId)
      const filter = { _id: id, status: { $in: ['published', 'PUBLISHED', 'Published'] }, isActive: { $ne: false } }
      if (req.query.serviceAreaId !== undefined) {
        if (!objectIdPattern.test(req.query.serviceAreaId)) throw new HttpError(400, 'VALIDATION_ERROR', 'The requested service area is invalid.')
        const serviceArea = await models.ServiceArea.exists({
          _id: req.query.serviceAreaId,
          isActive: { $ne: false },
          isServiceable: true,
        })
        if (!serviceArea) throw new HttpError(400, 'INVALID_SERVICE_AREA', 'The requested service area is unavailable.')
        filter.$or = [
          { serviceAreaIds: req.query.serviceAreaId },
          { serviceAreaIds: { $size: 0 } },
          { serviceAreaIds: { $exists: false } },
        ]
      }
      const service = await models.Service.findOne(filter).lean()
      if (!service) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
      const category = await models.ServiceCategory.findOne({ _id: service.categoryId, status: { $in: ['published', 'PUBLISHED', 'Published'] }, isActive: { $ne: false } }).select('_id name slug').lean()
      if (!category) throw new HttpError(404, 'NOT_FOUND', 'Service was not found.')
      const mediaIds = [...(service.imageMediaIds || []), service.thumbnailMediaId].filter(Boolean)
      const media = await models.MediaAsset.find({
        _id: { $in: mediaIds },
        isActive: { $ne: false },
        visibility: 'public',
        mimeType: /^image\//i,
      }).select('_id storageProvider storageKey publicUrl mimeType width height altText').lean()
      const safeMedia = media.filter(isPersistentPublicImage)
      apiSuccess(req, res, publicService(service, category, new Map(safeMedia.map(item => [item._id.toString(), item]))))
    } catch (error) { next(error) }
  })

  return { adminCategories, adminServices, publicCatalog }
}

module.exports = {
  assertPublicMedia,
  createCatalogRouters,
  isPersistentPublicImage,
  priceRupeesToPaise,
  publicCategory,
  publicService,
  serializeService,
  serviceUpdateSchema,
  slugify,
}
