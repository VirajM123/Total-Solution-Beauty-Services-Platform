export type Payment = { id: string; booking: string; customer: string; city: string; service: string; expert: string; method: 'UPI' | 'Card' | 'Cash'; amount: number; status: 'Paid' | 'Pending' | 'Failed' | 'Refunded' | 'Cancelled'; created: string; paidAt: string; reference: string }
export type Payout = { id: string; expert: string; city: string; method: string; amount: number; fee: number; status: 'Pending' | 'Paid' | 'Failed'; created: string; paidAt: string; reference: string }
export type Refund = { id: string; paymentId: string; amount: number; reason: string; status: 'Requested' | 'Approved' | 'Refunded' | 'Rejected'; created: string; completedAt: string; reference: string; reviewNote: string }
export type PaymentStore = { payments: Payment[]; payouts: Payout[]; refunds: Refund[] }
export const paymentStorageKey = 'hi-beauty-payments-v1'
const timestamp = (day: number) => `2026-10-${String(day).padStart(2, '0')}T10:04:00+05:30`
export const initialPaymentStore: PaymentStore = {
  payments: ['Ananya Sharma', 'Rohini Iyer', 'Kavya Menon', 'Sneha Patel', 'Pooja Desai', 'Meera Nair', 'Ishita Roy', 'Riya Shah', 'Aditi Rao', 'Sana Khan', 'Nisha Jain', 'Diya Kapoor'].map((customer, i) => {
    const status: Payment['status'] = i === 2 ? 'Pending' : i === 4 ? 'Failed' : i === 6 ? 'Refunded' : 'Paid'
    const created = timestamp(20 - Math.floor(i / 3))
    return { id: `TXN${10482 - i}`, booking: `#HB${28491 + i}`, customer, city: ['Bengaluru', 'Mumbai', 'Delhi', 'Ahmedabad', 'Pune', 'Kochi', 'Kolkata', 'Surat'][i % 8], service: ['Gold Facial', 'Hair Spa', 'Bridal Makeup', 'Manicure & Pedicure'][i % 4], expert: ['Neha Verma', 'Pooja Nair', 'Simran Kaur', 'Ritika Singh'][i % 4], method: ['UPI', 'Card', 'UPI', 'Cash'][i % 4] as Payment['method'], amount: [219900, 149900, 849900, 129900, 249900, 149900, 219900, 129900][i % 8], status, created, paidAt: status === 'Pending' || status === 'Failed' ? '' : created, reference: status === 'Pending' || status === 'Failed' ? '' : `DEMO-${10482 - i}` }
  }),
  payouts: ['Neha Verma', 'Pooja Nair', 'Simran Kaur', 'Ritika Singh', 'Aarti Mishra', 'Divya Joshi', 'Megha Patel', 'Kiran Desai'].map((expert, i) => ({ id: `PAY${2060 - i}`, expert, city: ['Bengaluru', 'Mumbai', 'Delhi', 'Ahmedabad'][i % 4], method: 'Bank transfer', amount: [880000, 520000, 1120000, 640000][i % 4], fee: 0, status: i < 3 ? 'Pending' : i === 6 ? 'Failed' : 'Paid', created: timestamp(20 - i), paidAt: i < 3 || i === 6 ? '' : timestamp(20 - i), reference: i < 3 || i === 6 ? '' : `DEMO-PAYOUT-${i}` })),
  refunds: [{ id: 'REF3001', paymentId: 'TXN10476', amount: 219900, reason: 'Cancelled appointment.', status: 'Refunded', created: timestamp(18), completedAt: timestamp(18), reference: 'DEMO-REFUND-3001', reviewNote: 'Completed sample refund.' }, { id: 'REF3002', paymentId: 'TXN10475', amount: 49900, reason: 'Service adjustment requested by customer.', status: 'Requested', created: timestamp(19), completedAt: '', reference: '', reviewNote: '' }],
}
export const isMinorAmount = (amount: unknown): amount is number => typeof amount === 'number' && Number.isSafeInteger(amount) && amount >= 0
export function loadPaymentStore(): PaymentStore {
  try {
    const data = JSON.parse(localStorage.getItem(paymentStorageKey) ?? 'null') as PaymentStore | null
    const strings = (record: object, fields: string[]) => fields.every(key => typeof (record as Record<string, unknown>)[key] === 'string')
    if (data && Array.isArray(data.payments) && Array.isArray(data.payouts) && Array.isArray(data.refunds) && data.payments.every(p => p && strings(p, ['id', 'booking', 'customer', 'city', 'service', 'expert', 'created', 'paidAt', 'reference']) && isMinorAmount(p.amount) && ['UPI', 'Card', 'Cash'].includes(p.method) && ['Paid', 'Pending', 'Failed', 'Refunded', 'Cancelled'].includes(p.status)) && data.payouts.every(p => p && strings(p, ['id', 'expert', 'city', 'method', 'created', 'paidAt', 'reference']) && isMinorAmount(p.amount) && isMinorAmount(p.fee) && ['Pending', 'Paid', 'Failed'].includes(p.status)) && data.refunds.every(r => r && strings(r, ['id', 'paymentId', 'reason', 'created', 'completedAt', 'reference', 'reviewNote']) && isMinorAmount(r.amount) && r.amount > 0 && ['Requested', 'Approved', 'Refunded', 'Rejected'].includes(r.status) && data.payments.some(p => p.id === r.paymentId))) return data
  } catch { /* Use sample records when storage is unavailable or invalid. */ }
  return initialPaymentStore
}
export function availableRefund(store: PaymentStore, paymentId: string): number {
  const payment = store.payments.find(p => p.id === paymentId)
  if (!payment || !['Paid', 'Refunded'].includes(payment.status)) return 0
  return Math.max(0, payment.amount - store.refunds.filter(r => r.paymentId === paymentId && r.status !== 'Rejected').reduce((sum, r) => sum + r.amount, 0))
}
export function requestRefund(store: PaymentStore, paymentId: string, amount: number, reason: string): PaymentStore {
  if (!isMinorAmount(amount) || amount <= 0 || amount > availableRefund(store, paymentId)) throw new Error('Enter an amount within the available refundable balance.')
  if (!reason.trim()) throw new Error('Enter a reason for this refund.')
  const refund: Refund = { id: `REF${crypto.randomUUID().slice(0, 8).toUpperCase()}`, paymentId, amount, reason: reason.trim(), status: 'Requested', created: new Date().toISOString(), completedAt: '', reference: '', reviewNote: '' }
  return { ...store, refunds: [refund, ...store.refunds] }
}
export function updateRefund(store: PaymentStore, id: string, action: 'approve' | 'reject' | 'record', note: string, reference: string): PaymentStore {
  const refund = store.refunds.find(r => r.id === id)
  if (!refund) throw new Error('Refund not found.')
  if (action === 'record' ? refund.status !== 'Approved' : refund.status !== 'Requested') throw new Error('This refund has already been reviewed or completed.')
  if (action === 'reject' && !note.trim()) throw new Error('Enter a rejection reason.')
  if (action === 'record' && !reference.trim()) throw new Error('Enter the reference from the completed refund.')
  if (action === 'record' && store.refunds.some(r => r.id !== id && r.reference === reference.trim())) throw new Error('This refund reference is already recorded.')
  const refunds = store.refunds.map(r => r.id === id ? { ...r, status: action === 'approve' ? 'Approved' as const : action === 'reject' ? 'Rejected' as const : 'Refunded' as const, reviewNote: note.trim(), reference: action === 'record' ? reference.trim() : '', completedAt: action === 'record' ? new Date().toISOString() : '' } : r)
  const completed = refunds.filter(r => r.paymentId === refund.paymentId && r.status === 'Refunded').reduce((sum, r) => sum + r.amount, 0)
  return { ...store, refunds, payments: store.payments.map(p => p.id === refund.paymentId && completed >= p.amount ? { ...p, status: 'Refunded' } : p) }
}
