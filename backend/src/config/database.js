const mongoose = require('mongoose')
const env = require('./env')
const logger = require('./logger')

mongoose.set('bufferCommands', false)
mongoose.set('autoCreate', false)
mongoose.set('autoIndex', false)

const connectionOptions = Object.freeze({
  dbName: env.MONGODB_DB_NAME,
  serverSelectionTimeoutMS: env.MONGODB_CONNECT_TIMEOUT_MS,
  autoCreate: false,
  autoIndex: false,
})

async function connectDatabase({
  uri = env.MONGODB_URI,
  connect = mongoose.connect.bind(mongoose),
  connectionLogger = logger,
} = {}) {
  if (!uri) {
    connectionLogger.warn({ database: env.MONGODB_DB_NAME }, 'MongoDB URI is not configured; starting without database access')
    return false
  }

  try {
    await connect(uri, connectionOptions)
    connectionLogger.info({ database: env.MONGODB_DB_NAME }, 'MongoDB connection established')
    return true
  } catch (error) {
    connectionLogger.error({
      errorName: error.name,
      errorCode: error.code,
    }, 'MongoDB connection failed')
    throw new Error('MongoDB connection failed; check server configuration and database availability.')
  }
}

function isDatabaseReady() {
  return mongoose.connection.readyState === 1
}

module.exports = { connectDatabase, connectionOptions, isDatabaseReady }
