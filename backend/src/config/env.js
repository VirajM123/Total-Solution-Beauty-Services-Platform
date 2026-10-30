require('dotenv').config({ quiet: true })

const { z } = require('zod')

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(5000),
  MONGODB_URI: z.string().trim().optional().transform(value => value || undefined),
  MONGODB_DB_NAME: z.literal('hii_beauty_dev').default('hii_beauty_dev'),
  ADMIN_CATALOG_API_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  ADMIN_OPERATIONS_API_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  LEGACY_WORKER_OFFERS_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  RAZORPAY_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  RAZORPAY_MODE: z.enum(['test', 'live']).default('test'),
  RAZORPAY_KEY_ID: z.string().trim().optional(),
  RAZORPAY_KEY_SECRET: z.string().trim().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().trim().optional(),
  RAZORPAY_CURRENCY: z.literal('INR').default('INR'),
  RAZORPAY_QR_ENABLED: z.enum(['true', 'false']).default('true').transform(value => value === 'true'),
  FCM_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  FIREBASE_PROJECT_ID: z.string().trim().optional(),
  OTP_PROVIDER: z.enum(['none', 'msg91']).default('none'),
  MSG91_ENABLED: z.enum(['true', 'false']).default('false').transform(value => value === 'true'),
  MSG91_AUTH_KEY: z.string().trim().optional().transform(value => value || undefined),
  MSG91_WIDGET_ID: z.string().trim().optional().transform(value => value || undefined),
  MSG91_WIDGET_TOKEN: z.string().trim().optional().transform(value => value || undefined),
  OTP_LENGTH: z.coerce.number().int().min(4).max(8).default(6),
  OTP_EXPIRY_SECONDS: z.coerce.number().int().min(60).max(900).default(900),
  OTP_RESEND_COOLDOWN_SECONDS: z.coerce.number().int().min(15).max(600).default(30),
  OTP_MAX_ATTEMPTS: z.coerce.number().int().min(1).max(10).default(5),
  OTP_PROVIDER_TIMEOUT_MS: z.coerce.number().int().min(1000).max(30000).default(10000),
  SESSION_COOKIE_SECRET: z.preprocess(value => value === '' ? undefined : value, z.string().min(32).optional()),
  ADMIN_SESSION_TTL_HOURS: z.coerce.number().int().min(1).max(24).default(8),
  CORS_ORIGINS: z.string().default('http://localhost:5173,http://127.0.0.1:5173'),
  AWS_REGION: z.string().trim().optional(),
  S3_BUCKET: z.string().trim().optional(),
  S3_PUBLIC_BASE_URL: z.string().trim().optional(),
  DEVELOPMENT_MEDIA_BASE_URL: z.string().trim().optional(),
  JSON_BODY_LIMIT: z.string().default('1mb'),
  MONGODB_CONNECT_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120000).default(10000),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120000).default(10000),
})

const result = schema.safeParse(process.env)

if (!result.success) {
  const details = result.error.issues.map(issue => `${issue.path.join('.')}: ${issue.message}`).join('; ')
  throw new Error(`Invalid backend environment configuration: ${details}`)
}

function msg91ConfigProblems(config) {
  const msg91Problems = []
  if (config.MSG91_ENABLED && config.OTP_PROVIDER !== 'msg91') {
    msg91Problems.push('MSG91_ENABLED requires OTP_PROVIDER=msg91')
  }
  if (config.MSG91_ENABLED && !config.MSG91_WIDGET_ID) {
    msg91Problems.push('MSG91_WIDGET_ID is required when MSG91 is enabled')
  }
  if (config.MSG91_ENABLED && !config.MSG91_AUTH_KEY && !config.MSG91_WIDGET_TOKEN) {
    msg91Problems.push('MSG91_AUTH_KEY or MSG91_WIDGET_TOKEN is required when MSG91 is enabled')
  }
  return msg91Problems
}

const msg91Problems = msg91ConfigProblems(result.data)
if (msg91Problems.length) {
  throw new Error(`Invalid MSG91 configuration: ${msg91Problems.join('; ')}`)
}


module.exports = {
  ...result.data,
  msg91ConfigProblems,
  CORS_ORIGINS: result.data.CORS_ORIGINS.split(',').map(origin => origin.trim()).filter(Boolean),
}
