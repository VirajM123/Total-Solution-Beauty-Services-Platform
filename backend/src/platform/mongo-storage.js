const { createHmac, timingSafeEqual } = require('node:crypto')
const express = require('express')
const env = require('../config/env')
const { handler, fail } = require('./core')

const validKey = /^(public|private)\/[a-f0-9-]{36}$/
function baseUrl() {
  return (env.DEVELOPMENT_MEDIA_BASE_URL || `http://localhost:${env.PORT}/api/v1`)
    .replace(/\/$/, '') + '/media/files/'
}
function isDevelopmentMedia(media) {
  return env.NODE_ENV === 'development' && media.storageProvider === 'mongodb'
    && validKey.test(media.storageKey)
    && (media.storageKey.startsWith('private/') ? !media.publicUrl
      : media.storageKey.startsWith('public/') && typeof media.publicUrl === 'string'
        && media.publicUrl === baseUrl() + media.storageKey)
}
function createMongoStorageAdapter({ db, secret = env.SESSION_COOKIE_SECRET }) {
  const sign = (key, expires) => createHmac('sha256', secret).update(key + ':' + expires).digest('hex')
  return {
    async put({ bytes, mimeType, visibility, storageKey }) {
      if (!validKey.test(storageKey)) fail(400, 'INVALID_STORAGE_KEY', 'Invalid upload key.')
      await db.collection('media_blobs').insertOne({
        _id: storageKey,
        bytes: Buffer.from(bytes),
        mimeType,
        visibility,
        createdAt: new Date(),
      })
      return {
        storageProvider: 'mongodb',
        storageKey,
        ...(visibility === 'public' ? { publicUrl: baseUrl() + storageKey } : {}),
      }
    },
    async remove({ storageKey }) {
      await db.collection('media_blobs').deleteOne({ _id: storageKey })
    },
    async signedRead({ storageKey, expiresInSeconds }) {
      const expires = Date.now() + expiresInSeconds * 1000
      return `${baseUrl()}${storageKey}?expires=${expires}&signature=${sign(storageKey, expires)}`
    },
    router() {
      const router = express.Router()
      router.get('/media/files/:visibility/:key', handler(async (req, res) => {
        const key = `${req.params.visibility}/${req.params.key}`
        if (!validKey.test(key)) fail(404, 'NOT_FOUND', 'File not found.')
        if (req.params.visibility === 'private') {
          const expires = Number(req.query.expires)
          const provided = String(req.query.signature || '')
          const expected = sign(key, expires)
          if (!Number.isSafeInteger(expires) || expires < Date.now()
            || expires > Date.now() + 65000 || provided.length !== expected.length
            || !timingSafeEqual(Buffer.from(provided), Buffer.from(expected))) {
            fail(403, 'LINK_EXPIRED', 'This photo link has expired.')
          }
        }
        const file = await db.collection('media_blobs').findOne({ _id: key })
        const metadata = await db.collection('media_assets').findOne({
          storageKey: key,
          isActive: true,
          uploadStatus: 'ready',
        })
        if (!file || !metadata) fail(404, 'NOT_FOUND', 'File not found.')
        res.set('Content-Type', file.mimeType)
        res.set('X-Content-Type-Options', 'nosniff')
        res.set('Cross-Origin-Resource-Policy', 'cross-origin')
        res.set('Cache-Control', req.params.visibility === 'private' ? 'private, no-store' : 'public, max-age=3600')
        const bytes = Buffer.isBuffer(file.bytes) ? file.bytes : Buffer.from(file.bytes.value())
        res.send(bytes)
      }))
      return router
    },
  }
}

module.exports = { createMongoStorageAdapter, isDevelopmentMedia }
