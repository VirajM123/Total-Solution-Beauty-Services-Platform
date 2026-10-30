const mongoose = require('mongoose')
const { compareAndSet } = require('./core')
const { notify, paise } = require('./business')

async function offerNextWorker(db, { booking, session, scheduling, preferredWorkerId, now = new Date() }) {
  if (
    booking.status !== 'confirmed' ||
    !['searching', 'rejected'].includes(booking.assignmentStatus) ||
    !Array.isArray(booking.items) ||
    booking.items.length === 0 ||
    !scheduling?.canAssign
  ) {
    return null
  }

  const [history, workers] = await Promise.all([
    db.collection('booking_assignments').find({ bookingId: booking._id }, { session }).toArray(),
    db.collection('workers').find({ status: 'approved', isOnline: true, isActive: true }, { session }).toArray(),
  ])
  const previouslyOffered = new Set(history.map(assignment => String(assignment.workerId)))
  const serviceIds = booking.items.map(item => String(item.serviceId))
  const candidates = workers
    .filter(worker =>
      (!preferredWorkerId || String(worker._id) === String(preferredWorkerId)) &&
      !previouslyOffered.has(String(worker._id)) &&
      serviceIds.every(serviceId => worker.serviceIds?.some(id => String(id) === serviceId)) &&
      worker.serviceAreaIds?.some(id => String(id) === String(booking.serviceAreaId)),
    )
    .sort((a, b) => {
      const aTime = a.lastAssignmentCheckAt ? new Date(a.lastAssignmentCheckAt).getTime() : 0
      const bTime = b.lastAssignmentCheckAt ? new Date(b.lastAssignmentCheckAt).getTime() : 0
      return aTime - bTime || String(a._id).localeCompare(String(b._id))
    })

  for (const candidate of candidates) {
    const user = await db.collection('users').findOne({
      _id: candidate.userId,
      userType: 'worker',
      status: 'active',
      isActive: true,
    }, { session })
    if (!user || !candidate.compensationRule) continue

    const effectiveFrom = new Date(candidate.compensationRule.effectiveFrom)
    if (!Number.isFinite(effectiveFrom.getTime()) || effectiveFrom > booking.startsAt) continue
    let compensationPaise
    try {
      compensationPaise = paise(candidate.compensationRule.amountPaise)
    } catch (error) {
      if (error.code === 'INVALID_MONEY') continue
      throw error
    }

    if (await db.collection('worker_leaves').findOne({
      workerId: candidate._id,
      status: 'approved',
      startsAt: { $lt: booking.endsAt },
      endsAt: { $gt: booking.startsAt },
    }, { session })) continue

    try {
      await compareAndSet(db, 'workers', candidate, { lastAssignmentCheckAt: now }, session)
    } catch (error) {
      if (error.code === 'STALE_RECORD') continue
      throw error
    }

    const overlap = await db.collection('bookings').findOne({
      _id: { $ne: booking._id },
      workerId: candidate._id,
      status: { $nin: ['completed', 'cancelled'] },
      startsAt: { $lt: booking.endsAt },
      endsAt: { $gt: booking.startsAt },
    }, { session })
    if (overlap || !await scheduling.canAssign({ worker: candidate, booking, session })) continue

    const timeoutMinutes = Number(booking.assignmentTimeoutMinutes)
    const expiresAt = new Date(Math.min(+booking.startsAt, +now + timeoutMinutes * 60000))
    if (!Number.isFinite(expiresAt.getTime()) || expiresAt <= now) continue

    const assignment = {
      _id: new mongoose.Types.ObjectId(),
      bookingId: booking._id,
      workerId: candidate._id,
      workerUserId: candidate.userId,
      status: 'offered',
      offeredAt: now,
      expiresAt,
      reason: 'Automatic dispatch to an online, eligible worker.',
      createdAt: now,
      isActive: true,
    }
    await db.collection('booking_assignments').insertOne(assignment, { session })
    const updated = await compareAndSet(db, 'bookings', booking, {
      status: 'assigned',
      assignmentStatus: 'offered',
      assignmentId: assignment._id,
      workerId: candidate._id,
      workerUserId: candidate.userId,
      compensationPaise,
    }, session)
    await db.collection('booking_events').insertOne({
      bookingId: booking._id,
      type: 'assignment_offered',
      workerId: candidate._id,
      actorType: 'system',
      createdAt: now,
    }, { session })
    await notify(db, session, candidate.userId, 'assignment.offered', assignment._id)
    return updated
  }
  return null
}

async function offerPendingBookings(db, { worker, session, scheduling, now = new Date() }) {
  if (!worker.isOnline) return
  const pending = await db.collection('bookings').find({
    status: 'confirmed',
    assignmentStatus: 'searching',
    startsAt: { $gt: now },
  }, { session }).sort({ startsAt: 1 }).limit(100).toArray()
  for (const booking of pending) {
    if (!booking.items.every(item => worker.serviceIds?.some(serviceId => String(serviceId) === String(item.serviceId))) ||
        !worker.serviceAreaIds?.some(areaId => String(areaId) === String(booking.serviceAreaId))) continue
    await offerNextWorker(db, { booking, session, scheduling, preferredWorkerId: worker._id, now })
  }
}

module.exports = { offerNextWorker, offerPendingBookings }
