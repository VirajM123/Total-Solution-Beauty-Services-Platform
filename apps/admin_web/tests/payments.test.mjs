import assert from 'node:assert/strict'
import test from 'node:test'
import { initialPaymentStore, availableRefund, requestRefund, updateRefund } from '../src/paymentsData.ts'

test('refunds require a paid payment, integer minor units, and a reason', () => {
  for (const id of ['TXN10480', 'TXN10478', 'missing']) assert.throws(() => requestRefund(initialPaymentStore, id, 100, 'Adjustment'))
  for (const amount of [-1, 0, 1.5, NaN, Infinity]) assert.throws(() => requestRefund(initialPaymentStore, 'TXN10482', amount, 'Adjustment'))
  assert.throws(() => requestRefund(initialPaymentStore, 'TXN10482', 100, '  '))
})

test('pending refunds reserve balance; rejection releases it', () => {
  const store = requestRefund(initialPaymentStore, 'TXN10482', 10001, 'Partial adjustment')
  assert.equal(availableRefund(store, 'TXN10482'), 209899)
  assert.throws(() => requestRefund(store, 'TXN10482', 209900, 'Over limit'))
  assert.throws(() => updateRefund(store, store.refunds[0].id, 'reject', ' ', ''))
  const rejected = updateRefund(store, store.refunds[0].id, 'reject', 'Request not eligible', '')
  assert.equal(availableRefund(rejected, 'TXN10482'), 219900)
})

test('refund completion requires approval and a unique external reference', () => {
  let store = requestRefund(initialPaymentStore, 'TXN10482', 10001, 'Partial adjustment')
  const id = store.refunds[0].id
  assert.throws(() => updateRefund(store, id, 'record', '', 'ref-001'))
  store = updateRefund(store, id, 'approve', 'Reviewed', '')
  assert.throws(() => updateRefund(store, id, 'record', '', ' '))
  store = updateRefund(store, id, 'record', '', 'ref-001')
  assert.equal(store.payments[0].status, 'Paid')
  assert.throws(() => updateRefund(store, id, 'record', '', 'ref-001'))
  store = requestRefund(store, 'TXN10482', 209899, 'Remaining amount')
  const remainingId = store.refunds[0].id
  store = updateRefund(store, remainingId, 'approve', '', '')
  assert.throws(() => updateRefund(store, remainingId, 'record', '', 'ref-001'))
  store = updateRefund(store, remainingId, 'record', '', 'ref-002')
  assert.equal(store.payments[0].status, 'Refunded')
  assert.equal(availableRefund(store, 'TXN10482'), 0)
  assert.equal(store.refunds.filter(r => r.paymentId === 'TXN10482' && r.status === 'Refunded').reduce((sum, r) => sum + r.amount, 0), 219900)
})
