// Tests never inherit the configured live database or feature flags.
process.env.NODE_ENV='test'
process.env.MONGODB_URI=''
process.env.ADMIN_CATALOG_API_ENABLED='false'
process.env.ADMIN_OPERATIONS_API_ENABLED='false'
process.env.SESSION_COOKIE_SECRET=''

process.env.OTP_PROVIDER='none'
process.env.MSG91_ENABLED='false'
process.env.MSG91_AUTH_KEY=''
process.env.MSG91_WIDGET_ID=''
process.env.MSG91_WIDGET_TOKEN=''
process.env.FCM_ENABLED='false'
