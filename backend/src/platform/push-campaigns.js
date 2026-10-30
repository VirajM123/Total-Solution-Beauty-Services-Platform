const { z } = require('zod')
const { id, fail, handler, reply, protectedRouter, atomic, requireRecord, compareAndSet } = require('./core')
const { digest } = require('./push-notifications')

const collections = { offers: 'offers', packages: 'service_packages', banners: 'promotional_banners' }
const campaignTypes = { offers: 'offer.published', packages: 'package.published', banners: 'banner.published' }

function createPushCampaignRouter({ db, auth, storage, pushEnabled = require('../config/env').FCM_ENABLED }) {
  const router = protectedRouter(auth)
  for (const resource of Object.keys(collections)) router.post(`/${resource}/:id/publish-notify`, auth.requirePermission(resource + '.publish'), handler(async (req, res) => {
    z.object({}).strict().parse(req.body)
    if (!pushEnabled) fail(503, 'PUSH_NOT_CONFIGURED', 'Enable and configure Firebase push before sending announcements.')
    const entityId = id(req.params.id)
    const campaignId = id(digest('catalog-announcement:' + resource + ':' + entityId).slice(0, 24))
    const result = await atomic(db, req, resource + '.publish_notify', 'push_campaigns', async session => {
      const existing = await db.collection('push_campaigns').findOne({ _id: campaignId }, { session })
      if (existing) return existing
      const before = await requireRecord(db, collections[resource], entityId, session)
      if (['archived', 'disabled'].includes(before.status)) fail(409, 'INVALID_TRANSITION', 'Restore this item before publishing an announcement.')
      await require('./resources.routes').validateRelationships(db, resource, { ...before, status: 'published' }, session, storage)
      const now = new Date()
      if (before.endsAt && new Date(before.endsAt) <= now) fail(409, 'CAMPAIGN_EXPIRED', 'Update the expired offer dates before sending an announcement.')
      if (before.status !== 'published' || !before.isActive) {
        await compareAndSet(db, collections[resource], before, { status: 'published', isActive: true }, session)
        await require('./business').notifyAdmins(db, session, 'catalog.' + resource + '.published', before._id, resource + '.read')
      }
      const record = { _id: campaignId, resource, entityId, audiences: resource === 'banners' ? before.audiences : ['customer'],
        status: 'pending', createdAt: now, createdBy: req.auth.user._id,
        startsAt: before.startsAt ? new Date(Math.max(+now, +new Date(before.startsAt))) : now,
        lastUserId: id('000000000000000000000000'), processedCount: 0,
      }
      await db.collection('push_campaigns').insertOne(record, { session })
      return record
    })
    reply(req, res, result)
  }))
  return router
}

async function expandPushCampaigns({ db, now = new Date() }) {
  const campaigns = await db.collection('push_campaigns').find({ status: 'pending', startsAt: { $lte: now } }).sort({ createdAt: 1 }).limit(10).toArray()
  for (const campaign of campaigns) {
    // One transactional page per campaign; concurrent instances retry against the same cursor.
    const session = (db.transactionClient || require('mongoose').connection.getClient()).startSession()
    try {
      await session.withTransaction(async () => {
        const current = await db.collection('push_campaigns').findOne({ _id: campaign._id, status: 'pending' }, { session })
        if (!current) return
        const item = await db.collection(collections[current.resource]).findOne({ _id: current.entityId, status: 'published', isActive: true, isDeleted: { $ne: true } }, { session })
        if (!item || item.endsAt && new Date(item.endsAt) <= now) {
          await compareAndSet(db, 'push_campaigns', current, { status: 'cancelled' }, session)
          return
        }
        // Existing audience and catalog dates remain authoritative, including edits after scheduling.
        if (item.startsAt && new Date(item.startsAt) > now) return
        const audiences = current.resource === 'banners' ? item.audiences : ['customer']
        const users = await db.collection('users').find({ _id: { $gt: current.lastUserId }, userType: { $in: audiences },
          status: 'active', isActive: true, createdAt: { $lte: current.createdAt },
        }, { session }).sort({ _id: 1 }).limit(100).toArray()
        for (const user of users) {
          const profile = await db.collection(user.userType === 'worker' ? 'workers' : 'customers').findOne({ userId: user._id }, { session })
          if (profile?.notificationsEnabled === false || profile?.marketingNotificationsEnabled === false || profile?.isActive === false) continue
          await require('./business').notify(db, session, user._id, campaignTypes[current.resource], current.entityId, String(current._id))
        }
        await compareAndSet(db, 'push_campaigns', current, { lastUserId: users.at(-1)?._id || current.lastUserId,
          processedCount: current.processedCount + users.length, ...(users.length < 100 ? { status: 'completed', completedAt: now } : {}),
        }, session)
      })
    } finally { await session.endSession() }
  }
}

module.exports = { createPushCampaignRouter, expandPushCampaigns, collections, campaignTypes }
