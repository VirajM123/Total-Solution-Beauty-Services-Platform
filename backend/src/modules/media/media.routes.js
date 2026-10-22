const express = require('express')
const { HttpError } = require('../../middleware/errorHandler')
const { requireSameOrigin } = require('../../middleware/authorize')

function createMediaStorage(adapter) {
  if (adapter && typeof adapter.upload !== 'function') {
    throw new TypeError('Media storage adapter must implement upload().')
  }

  return {
    isConfigured: Boolean(adapter),
    async upload(request) {
      if (!adapter) {
        throw new HttpError(503, 'STORAGE_NOT_CONFIGURED', 'Persistent image storage is not configured.')
      }
      return adapter.upload(request)
    },
  }
}

function createMediaRouter({ auth, storage }) {
  const router = express.Router()

  router.post(
    '/uploads',
    auth.requireAuthenticated,
    auth.requirePermission('catalog.media.upload'),
    requireSameOrigin,
    auth.requireCsrf,
    async (req, res, next) => {
      try {
        const media = await storage.upload(req)
        res.status(201).json({ success: true, data: media, requestId: req.id })
      } catch (error) {
        next(error)
      }
    },
  )

  return router
}

module.exports = { createMediaRouter, createMediaStorage }
