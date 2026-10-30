const { compareAndSet } = require('../platform/core')
const { createScheduling } = require('../platform/admin-operations')
const { offerNextWorker } = require('../platform/dispatch')

async function expireAssignments({ db, now = new Date(), limit = 100, scheduling = createScheduling({ db }), legacyWorkerOffersEnabled = false }) {
  const expired = await db.collection('booking_assignments').find({ status: 'offered', expiresAt: { $lte: now } }).sort({ expiresAt: 1 }).limit(limit).toArray()
  let count = 0
  for (const candidate of expired) {
    const session = (db.transactionClient || require('mongoose').connection.getClient()).startSession()
    try {
      await session.withTransaction(async () => {
        const assignment = await db.collection('booking_assignments').findOne({ _id: candidate._id, status: 'offered', expiresAt: { $lte: now } }, { session })
        if (!assignment) return
        await compareAndSet(db, 'booking_assignments', assignment, { status: 'expired', expiredAt: now }, session)
        const booking = await db.collection('bookings').findOne({ _id: assignment.bookingId, assignmentId: assignment._id, status: 'assigned', assignmentStatus: 'offered' }, { session })
        if (booking) {
          const updated = await compareAndSet(db, 'bookings', booking, { status: 'confirmed', assignmentStatus: 'searching', assignmentId: null, workerId: null, workerUserId: null }, session)
          await db.collection('booking_events').insertOne({ bookingId: booking._id, type: 'assignment_expired', actorType: 'system', createdAt: now }, { session })
          await db.collection('audit_logs').insertOne({ action: 'assignment.expired', actorRole: 'system', entityType: 'booking_assignments', entityId: assignment._id, createdAt: now, result: 'success' }, { session })
          if (legacyWorkerOffersEnabled) await offerNextWorker(db, { booking: updated, session, scheduling, now })
        }
      })
      count++
    } finally { await session.endSession() }
  }
  return count
}
function startAssignmentTimeoutJob({ db, logger, intervalMs = 30000, legacyWorkerOffersEnabled = false }) {
  let busy = false
  const timer = setInterval(async () => {
    if (busy) return
    busy = true
    try { await expireAssignments({ db, legacyWorkerOffersEnabled }) } catch (error) { logger.error({ errorName: error.name }, 'Assignment expiry sweep failed') } finally { busy = false }
  }, intervalMs)
  timer.unref()
  return () => clearInterval(timer)
}
module.exports = { expireAssignments, startAssignmentTimeoutJob }
