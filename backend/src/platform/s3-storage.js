const {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} = require('@aws-sdk/client-s3')
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner')

function publicObjectUrl(baseUrl, storageKey) {
  const base = new URL(baseUrl)
  if (base.protocol !== 'https:') {
    throw new Error('S3_PUBLIC_BASE_URL must use HTTPS.')
  }
  const key = storageKey.split('/').map(encodeURIComponent).join('/')
  return `${base.href.replace(/\/$/, '')}/${key}`
}

function createS3StorageAdapter({ region, bucket, publicBaseUrl, client, signUrl = getSignedUrl } = {}) {
  if (!region && !bucket) return null
  if (!region || !bucket) {
    throw new Error('AWS_REGION and S3_BUCKET must both be configured to enable S3 media storage.')
  }

  if (publicBaseUrl) {
    const base = new URL(publicBaseUrl)
    if (base.protocol !== 'https:' || base.search || base.hash) {
      throw new Error('S3_PUBLIC_BASE_URL must be an HTTPS base URL without a query or fragment.')
    }
    publicBaseUrl = base.href.replace(/\/$/, '')
  }

  const s3 = client || new S3Client({ region })

  return {
    async put({ bytes, mimeType, visibility, storageKey }) {
      if (visibility === 'public' && !publicBaseUrl) {
        throw new Error('S3_PUBLIC_BASE_URL is required for public media uploads.')
      }
      if (!['public', 'private'].includes(visibility)) {
        throw new TypeError('Media visibility must be public or private.')
      }
      const url = visibility === 'public' ? publicObjectUrl(publicBaseUrl, storageKey) : undefined

      await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: storageKey,
        Body: bytes,
        ContentType: mimeType,
        ...(visibility === 'public' ? { CacheControl: 'public, max-age=31536000, immutable' } : {}),
      }))

      return {
        storageKey,
        storageProvider: 's3',
        ...(url ? { publicUrl: url } : {}),
      }
    },

    async remove({ storageKey }) {
      await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: storageKey }))
    },

    async signedRead({ storageKey, expiresInSeconds }) {
      return signUrl(
        s3,
        new GetObjectCommand({ Bucket: bucket, Key: storageKey }),
        { expiresIn: expiresInSeconds },
      )
    },
  }
}

module.exports = { createS3StorageAdapter, publicObjectUrl }
