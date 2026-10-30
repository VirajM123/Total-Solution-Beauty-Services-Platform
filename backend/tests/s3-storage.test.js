const assert = require('node:assert/strict')
const test = require('node:test')
const {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
} = require('@aws-sdk/client-s3')
const { createS3StorageAdapter, publicObjectUrl } = require('../src/platform/s3-storage')

test('S3 adapter is disabled only when bucket configuration is entirely absent', () => {
  assert.equal(createS3StorageAdapter(), null)
  assert.throws(() => createS3StorageAdapter({ region: 'ap-south-1' }), /must both be configured/)
  assert.throws(() => createS3StorageAdapter({ bucket: 'beauty-media' }), /must both be configured/)
})

test('public media URL requires HTTPS and safely encodes path segments', () => {
  assert.equal(
    publicObjectUrl('https://cdn.example.test/images/', 'public/a b/image.webp'),
    'https://cdn.example.test/images/public/a%20b/image.webp',
  )
  assert.throws(() => createS3StorageAdapter({
    region: 'ap-south-1',
    bucket: 'beauty-media',
    publicBaseUrl: 'http://cdn.example.test',
    client: { send: async () => undefined },
  }), /must be an HTTPS base URL/)
})

test('S3 adapter uploads public assets without ACLs, deletes objects and signs private reads', async () => {
  const commands = []
  const client = { send: async command => { commands.push(command); return {} } }
  const signedReads = []
  const storage = createS3StorageAdapter({
    region: 'ap-south-1',
    bucket: 'beauty-media',
    publicBaseUrl: 'https://cdn.example.test',
    client,
    signUrl: async (_client, command, options) => {
      signedReads.push({ command, options })
      return 'https://signed.example.test/private-document'
    },
  })
  const bytes = Buffer.from('image-bytes')

  const publicResult = await storage.put({
    bytes, mimeType: 'image/webp', visibility: 'public', storageKey: 'public/image.webp',
  })
  assert.deepEqual(publicResult, {
    storageKey: 'public/image.webp',
    storageProvider: 's3',
    publicUrl: 'https://cdn.example.test/public/image.webp',
  })
  assert.ok(commands[0] instanceof PutObjectCommand)
  assert.equal(commands[0].input.Bucket, 'beauty-media')
  assert.equal(commands[0].input.Body, bytes)
  assert.equal(commands[0].input.ACL, undefined)

  const privateResult = await storage.put({
    bytes, mimeType: 'application/pdf', visibility: 'private', storageKey: 'private/document.pdf',
  })
  assert.deepEqual(privateResult, {
    storageKey: 'private/document.pdf',
    storageProvider: 's3',
  })
  assert.equal(await storage.signedRead({ storageKey: 'private/document.pdf', expiresInSeconds: 60 }),
    'https://signed.example.test/private-document')
  assert.ok(signedReads[0].command instanceof GetObjectCommand)
  assert.deepEqual(signedReads[0].options, { expiresIn: 60 })

  await storage.remove({ storageKey: 'private/document.pdf' })
  assert.ok(commands.at(-1) instanceof DeleteObjectCommand)
})

test('public media without a public HTTPS base URL is rejected before uploading', async () => {
  let sent = false
  const storage = createS3StorageAdapter({
    region: 'ap-south-1',
    bucket: 'beauty-media',
    client: { send: async () => { sent = true } },
  })
  await assert.rejects(storage.put({
    bytes: Buffer.from('image'),
    mimeType: 'image/png',
    visibility: 'public',
    storageKey: 'public/image.png',
  }), /S3_PUBLIC_BASE_URL is required/)
  assert.equal(sent, false)
})
