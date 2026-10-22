require('dotenv').config({ quiet: true })

const { z } = require('zod')

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(5000),
  MONGODB_URI: z.string().trim().optional().transform(value => value || undefined),
  MONGODB_DB_NAME: z.literal('hii_beauty_dev').default('hii_beauty_dev'),
  ADMIN_CATALOG_API_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  ADMIN_OPERATIONS_API_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  SESSION_COOKIE_SECRET: z.preprocess(value => value === '' ? undefined : value, z.string().min(32).optional()),
  ADMIN_SESSION_TTL_HOURS: z.coerce.number().int().min(1).max(24).default(8),
  CORS_ORIGINS: z.string().default('http://localhost:5173,http://127.0.0.1:5173'),
  JSON_BODY_LIMIT: z.string().default('1mb'),
  MONGODB_CONNECT_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120000).default(10000),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120000).default(10000),
})

const result = schema.safeParse(process.env)

if (!result.success) {
  const details = result.error.issues.map(issue => `${issue.path.join('.')}: ${issue.message}`).join('; ')
  throw new Error(`Invalid backend environment configuration: ${details}`)
}

module.exports = {
  ...result.data,
  CORS_ORIGINS: result.data.CORS_ORIGINS.split(',').map(origin => origin.trim()).filter(Boolean),
}
