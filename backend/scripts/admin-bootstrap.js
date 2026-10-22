// Explicit CLI only. Never imported by normal server startup.
const readline = require('node:readline/promises')
const mongoose = require('mongoose')
const env = require('../src/config/env')
const { connectDatabase } = require('../src/config/database')
const { assertDevelopment, inspect, bootstrap } = require('../src/modules/auth/adminBootstrap')
function hiddenPrompt(label) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) throw new Error('Interactive terminal required.')
  return new Promise((resolve, reject) => {
    let value = ''
    const wasRaw = process.stdin.isRaw
    process.stdout.write(label)
    process.stdin.setRawMode(true)
    process.stdin.setEncoding('utf8')
    process.stdin.resume()
    function finish(error) {
      process.stdin.off('data', onData)
      process.stdin.setRawMode(Boolean(wasRaw))
      process.stdin.pause()
      process.stdout.write('\n')
      if (error) reject(error)
      else resolve(value)
    }
    function onData(chunk) {
      for (const character of chunk) {
        if (character === '\u0003') return finish(new Error('Cancelled.'))
        if (character === '\r' || character === '\n') return finish()
        if (character === '\u007f' || character === '\b') value = value.slice(0, -1)
        else if (character >= ' ' && value.length < 129) value += character
      }
    }
    process.stdin.on('data', onData)
  })
}
async function main() {
  const args = process.argv.slice(2)
  if (args.length !== 1 || !['--inspect', '--create'].includes(args[0])) throw new Error('Invalid mode.')
  assertDevelopment(env, { databaseName: env.MONGODB_DB_NAME })
  await connectDatabase()
  const db = mongoose.connection.db
  assertDevelopment(env, db)
  await db.command({ ping: 1 })
  const state = await inspect(db)
  console.log(JSON.stringify({ database: db.databaseName, ready: true, ...state }, null, 2))
  if (args[0] === '--inspect') return
  if (state.suitableAdminCount) throw new Error('A suitable Admin exists; use the existing account.')
  if (!process.stdin.isTTY || !process.stdout.isTTY) throw new Error('Interactive terminal required.')
  const terminal = readline.createInterface({ input: process.stdin, output: process.stdout })
  let identity
  let approved
  try {
    approved = await terminal.question('After project-owner approval, type CREATE DEVELOPMENT ADMIN: ') === 'CREATE DEVELOPMENT ADMIN'
    if (!approved) throw new Error('Creation was not approved.')
    identity = {
      fullName: await terminal.question('Admin full name: '),
      email: await terminal.question('Admin email: '),
      mobileNumber: await terminal.question('Admin mobile (+countrycode...): '),
    }
  } finally { terminal.close() }
  try {
    identity.password = await hiddenPrompt('Password (16?128 characters, hidden): ')
    const confirmation = await hiddenPrompt('Confirm password (hidden): ')
    if (identity.password !== confirmation) throw new Error('Passwords do not match.')
    await bootstrap({ db, client: mongoose.connection.getClient(), env, identity, approved })
    console.log('Development Admin and audit created atomically. Catalog remains disabled.')
  } finally { identity.password = '' }
}
if (require.main === module) {
  main().catch(() => {
    console.error('Admin operation stopped. Check development configuration, identity conflicts, roles, unique index and transaction support. No credentials are printed.')
    process.exitCode = 1
  }).finally(async () => { await mongoose.disconnect() })
}
module.exports = { hiddenPrompt, main }
