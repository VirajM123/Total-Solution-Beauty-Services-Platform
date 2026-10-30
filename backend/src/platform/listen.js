// Wait for the socket to bind so asynchronous errors reject startup.
function listen(server, port) {
  return new Promise((resolve, reject) => {
    const onError = error => {
      server.removeListener('listening', onListening)
      if (error.code === 'EADDRINUSE') {
        error.message = `Port ${port} is already in use. Stop the existing backend before restarting, or configure PORT and update the apps' API URLs.`
      }
      reject(error)
    }
    const onListening = () => {
      server.removeListener('error', onError)
      resolve(server)
    }
    server.once('error', onError)
    server.once('listening', onListening)
    server.listen(port)
  })
}
module.exports = { listen }
