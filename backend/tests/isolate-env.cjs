// Tests never inherit the configured live database or feature flags.
process.env.NODE_ENV='test'
process.env.MONGODB_URI=''
process.env.ADMIN_CATALOG_API_ENABLED='false'
process.env.ADMIN_OPERATIONS_API_ENABLED='false'
process.env.SESSION_COOKIE_SECRET=''
