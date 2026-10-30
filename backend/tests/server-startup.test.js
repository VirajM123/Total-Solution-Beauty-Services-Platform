const assert = require('node:assert/strict')
const http = require('node:http')
const test = require('node:test')
const { listen } = require('../src/platform/listen')
const close = server => new Promise(resolve => server.close(resolve))
test('busy port rejects cleanly and permits retry after release', async () => {
  const first = http.createServer(), second = http.createServer()
  const initialListening = second.listenerCount('listening')
  const initialErrors = second.listenerCount('error')
  try {
    assert.equal(await listen(first, 0), first)
    const port = first.address().port
    await assert.rejects(listen(second, port), error => {
      assert.equal(error.code, 'EADDRINUSE')
      assert.match(error.message, /already in use/)
      return true
    })
    assert.equal(second.listening, false)
    assert.equal(second.listenerCount('listening'), initialListening)
    assert.equal(second.listenerCount('error'), initialErrors)
    await close(first)
    await listen(second, port)
    assert.equal(second.listening, true)
  } finally {
    if (first.listening) await close(first)
    if (second.listening) await close(second)
  }
})
