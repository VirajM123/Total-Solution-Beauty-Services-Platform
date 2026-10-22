import assert from 'node:assert/strict'
import test from 'node:test'
import { appOffers, initialOffers, offerStatus, validateOffer } from '../src/offersData.ts'

const now = new Date('2026-10-20T12:00:00+05:30')
test('offer scheduling uses inclusive Indian calendar dates', () => {
  const offer = initialOffers[0]
  assert.equal(offerStatus(offer, new Date('2026-10-19T23:59:59.999+05:30')), 'Scheduled')
  assert.equal(offerStatus(offer, new Date('2026-10-20T00:00:00+05:30')), 'Live')
  assert.equal(offerStatus(offer, new Date('2026-10-31T23:59:59.999+05:30')), 'Live')
  assert.equal(offerStatus(offer, new Date('2026-11-01T00:00:00+05:30')), 'Expired')
  assert.equal(offerStatus({ ...offer, published: false }, now), 'Draft')
})
test('each app sees only its live offers in display order', () => {
  assert.deepEqual(appOffers(initialOffers, 'customer', now).map(o => o.id), ['glow', 'beauty'])
  assert.deepEqual(appOffers(initialOffers, 'worker', now).map(o => o.id), ['beauty', 'worker-care'])
  assert.ok(!appOffers(initialOffers, 'worker', now).some(o => o.id === 'weekend'))
  const reordered = initialOffers.map(o => o.id === 'beauty' ? { ...o, order: 1 } : o.id === 'glow' ? { ...o, order: 3 } : o)
  assert.deepEqual(appOffers(reordered, 'customer', now).map(o => o.id), ['beauty', 'glow'])
})
test('publishing requires images, audience, valid dates, code and discount', () => {
  const offer = initialOffers[0]
  assert.doesNotThrow(() => validateOffer(offer, initialOffers))
  for (const changes of [{ image: null }, { audiences: [] }, { start: '2026-02-31' }, { end: '2026-10-19' }, { discount: 101 }, { discount: 0 }, { code: '' }, { order: 0 }, { order: 1.5 }]) assert.throws(() => validateOffer({ ...offer, ...changes }, initialOffers))
  assert.doesNotThrow(() => validateOffer({ ...offer, published: false, image: null }, initialOffers))
  assert.doesNotThrow(() => validateOffer({ ...offer, id: 'another-banner-for-same-coupon' }, initialOffers))
})
test('app-specific banner destinations cannot target the wrong app', () => {
  assert.throws(() => validateOffer({ ...initialOffers[0], audiences: ['worker'] }, initialOffers))
  assert.throws(() => validateOffer({ ...initialOffers[0], audiences: ['customer', 'worker'] }, initialOffers))
  assert.throws(() => validateOffer({ ...initialOffers[2], audiences: ['customer'] }, initialOffers))
  assert.doesNotThrow(() => validateOffer({ ...initialOffers[0], audiences: ['customer', 'worker'], action: 'details' }, initialOffers))
})
