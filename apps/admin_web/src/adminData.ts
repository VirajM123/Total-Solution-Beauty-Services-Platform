import { useEffect, useState } from 'react'
import { loadExperts, type Expert } from './expertsData'
import { loadPaymentStore } from './paymentsData'
import { loadCatalog, type ServiceImage } from './servicesData'

export const todayIST = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' })
export const currency = (minor: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(minor / 100)
export const displayDate = (value: string) => value ? new Date(value.length === 10 ? `${value}T12:00:00+05:30` : value).toLocaleDateString('en-GB', { timeZone: 'Asia/Kolkata', day: '2-digit', month: 'short', year: 'numeric' }) : '—'
export function readLocal<T>(key: string, initial: T): T { try { const value = localStorage.getItem(key); return value ? JSON.parse(value) as T : initial } catch { return initial } }
export function saveLocal<T>(key: string, value: T, audit?: string) {
  localStorage.setItem(key, JSON.stringify(value))
  if (audit) { try { const records = readLocal<AuditEntry[]>('hi-beauty-audit-v1', []); localStorage.setItem('hi-beauty-audit-v1', JSON.stringify([{ id: crypto.randomUUID(), at: new Date().toISOString(), actor: 'Priya Sharma', message: audit }, ...records].slice(0, 300))) } catch { /* The primary record has already been saved. */ } }
  window.dispatchEvent(new Event('hi-beauty:data'))
}
export function saveTogether(entries: [string, unknown][], audit: string) {
  const previous = entries.map(([key]) => [key, localStorage.getItem(key)] as const)
  try { for (const [key, value] of entries) localStorage.setItem(key, JSON.stringify(value)) }
  catch (error) { for (const [key, value] of previous) { if (value === null) localStorage.removeItem(key); else localStorage.setItem(key, value) } throw error }
  try { saveLocal('hi-beauty-last-change', new Date().toISOString(), audit) }
  catch { window.dispatchEvent(new Event('hi-beauty:data')) }
}
export function useLocalRecords<T>(key: string, initial: () => T) {
  const [value, setValue] = useState(initial)
  useEffect(() => { const refresh = () => setValue(initial()); window.addEventListener('hi-beauty:data', refresh); window.addEventListener('storage', refresh); return () => { window.removeEventListener('hi-beauty:data', refresh); window.removeEventListener('storage', refresh) } }, [initial])
  function save(next: T, audit?: string) { saveLocal(key, next, audit); setValue(next) }
  return [value, save] as const
}
export function exportCsv(name: string, rows: (string | number)[][]) { const csv = rows.map(row => row.map(value => `"${String(value).replace(/^[=+@-]/, "'$&").replaceAll('"', '""')}"`).join(',')).join('\r\n'); const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' })); const a = document.createElement('a'); a.href = url; a.download = `${name}.csv`; a.click(); URL.revokeObjectURL(url) }
export type AuditEntry = { id: string; at: string; actor: string; message: string }
export type BookingStatus = 'Confirmed' | 'Assigned' | 'On the way' | 'In progress' | 'Completed' | 'Cancelled'
export type AssignmentStatus = 'Searching' | 'Offered' | 'Accepted' | 'Rejected' | 'Reassigned' | 'Cancelled'
export type BookingEvent = { at: string; label: string; note: string }
export type BookingRecord = { id: string; customerId: string; customer: string; city: string; address: string; date: string; time: string; serviceId: string; service: string; duration: number; price: number; discount: number; fee: number; expertId: string; expert: string; compensation?: number; items?: { serviceId: string; name: string; price: number; duration: number }[]; status: BookingStatus; assignment: AssignmentStatus; method: 'Cash' | 'UPI'; cancellationReason: string; events: BookingEvent[] }
export const bookingKey = 'hi-beauty-operations-v2'
export function loadBookings(): BookingRecord[] {
  const stored = readLocal<BookingRecord[] | null>(bookingKey, null)
  if (Array.isArray(stored)) return stored
  const payments = loadPaymentStore().payments
  const catalog = loadCatalog()
  return payments.map((p, i) => {
    const service = catalog.sub.find(s => s.name === p.service) ?? catalog.sub[0]
    const expert = loadExperts().find(e => e.name === p.expert)
    const completed = p.status === 'Paid' || p.status === 'Refunded'
    return { id: p.booking, customerId: `HBC${1001 + i}`, customer: p.customer, city: p.city, address: `${12 + i}, Rose Residency, ${p.city}`, date: completed ? p.created.slice(0, 10) : i === 2 ? '2026-10-20' : '2026-10-21', time: ['10:00', '11:30', '13:00', '15:30'][i % 4], serviceId: service?.id ?? '', service: p.service, duration: service?.duration ?? 60, price: p.amount, discount: 0, fee: 0, expertId: completed ? expert?.id ?? '' : '', expert: completed ? p.expert : '', compensation: expert ? workerRules(expert).compensation : 0, status: completed ? 'Completed' : 'Confirmed', assignment: completed ? 'Accepted' : 'Searching', method: p.method === 'Cash' ? 'Cash' : 'UPI', cancellationReason: '', events: [{ at: p.created, label: 'Booking confirmed', note: 'Price and duration saved at booking time.' }, ...(completed ? [{ at: p.paidAt, label: 'Service completed', note: 'Imported sample booking.' }] : [])] }
  })
}
export const bookingTotal = (b: BookingRecord) => b.price - b.discount + b.fee
export function bookingPayment(b: BookingRecord) { const p = loadPaymentStore().payments.find(p => p.booking === b.id); return p?.status ?? 'Pending' }
export type WorkerRules = { skills: string[]; areas: string[]; online: boolean; compensation: number }
export function workerRules(e: Expert): WorkerRules {
  const saved = readLocal<Record<string, WorkerRules>>('hi-beauty-worker-rules-v1', {})[e.id]
  if (saved) return saved
  const catalog = loadCatalog()
  const match: Record<string, string> = { 'Facial & Skincare': 'facial', 'Hair Styling': 'hair', 'Bridal Makeup': 'makeup', 'Nail Care': 'nail', Waxing: 'waxing' }
  return { skills: catalog.sub.filter(s => s.parentId === match[e.speciality]).map(s => s.id), areas: [e.city], online: e.status === 'Active', compensation: loadSettings().defaultCompensation }
}
export function eligibleWorkers(booking: BookingRecord, bookings: BookingRecord[], experts = loadExperts()): Expert[] {
  const minutes = (value: string) => Number(value.slice(0, 2)) * 60 + Number(value.slice(3))
  const requiredSkills = booking.items?.map(item => item.serviceId) ?? [booking.serviceId]
  return experts.filter(e => { const rules = workerRules(e); return e.status === 'Active' && rules.online && rules.areas.includes(booking.city) && requiredSkills.every(id => rules.skills.includes(id)) && !bookings.some(b => b.id !== booking.id && b.expertId === e.id && !['Completed', 'Cancelled'].includes(b.status) && b.date === booking.date && ['Offered', 'Accepted', 'Reassigned'].includes(b.assignment) && minutes(b.time) < minutes(booking.time) + booking.duration && minutes(booking.time) < minutes(b.time) + b.duration) })
}
export function advanceBooking(b: BookingRecord, action: 'offer' | 'accept' | 'reject' | 'travel' | 'start' | 'complete' | 'cancel', note = '', expert?: Expert): BookingRecord {
  if (['Completed', 'Cancelled'].includes(b.status)) throw new Error('This booking is closed.')
  let changes: Partial<BookingRecord> = {}, label = ''
  if (action === 'offer') { if (!expert || !['Confirmed', 'Assigned'].includes(b.status)) throw new Error('Select an eligible worker before offering this booking.'); changes = { expertId: expert.id, expert: expert.name, compensation: workerRules(expert).compensation, assignment: b.expertId ? 'Reassigned' : 'Offered', status: 'Assigned' }; label = 'Assignment offered' }
  if (action === 'accept') { if (!['Offered', 'Reassigned'].includes(b.assignment)) throw new Error('No assignment is awaiting acceptance.'); changes = { assignment: 'Accepted' }; label = 'Worker acceptance recorded' }
  if (action === 'reject') { if (!['Offered', 'Reassigned'].includes(b.assignment) || !note.trim()) throw new Error('Enter the worker rejection reason.'); changes = { assignment: 'Rejected', status: 'Confirmed', expertId: '', expert: '' }; label = 'Assignment rejected' }
  if (action === 'travel') { if (b.assignment !== 'Accepted' || b.status !== 'Assigned') throw new Error('The worker must accept the assignment first.'); changes = { status: 'On the way' }; label = 'Worker on the way' }
  if (action === 'start') { if (b.status !== 'On the way' || !note.trim()) throw new Error('Record the arrival verification reference before starting.'); changes = { status: 'In progress' }; label = 'Verified service start recorded (demo)' }
  if (action === 'complete') { if (b.status !== 'In progress') throw new Error('Only an in-progress service can be completed.'); changes = { status: 'Completed' }; label = 'Service completed; collection remains independent' }
  if (action === 'cancel') { if (!note.trim()) throw new Error('A cancellation reason is required.'); changes = { status: 'Cancelled', assignment: 'Cancelled', cancellationReason: note.trim() }; label = 'Booking cancelled' }
  return { ...b, ...changes, events: [...b.events, { at: new Date().toISOString(), label, note: note.trim() }] }
}
export type Package = { id: string; name: string; services: string[]; price: number; published: boolean; image: ServiceImage | null; description: string }
export const packageKey = 'hi-beauty-packages-v1'
export const loadPackages = () => readLocal<Package[]>(packageKey, [{ id: 'glow-package', name: 'Glow & Relax', services: ['gold', 'service-0'], price: 329900, published: true, image: null, description: 'Gold Facial and Hair Spa in one appointment.' }])
export type Ticket = { id: string; bookingId: string; subject: string; customer: string; category: string; priority: string; status: 'Open' | 'In review' | 'Resolved'; owner: string; created: string; messages: { at: string; text: string }[] }
export const ticketKey = 'hi-beauty-tickets-v1'
export const loadTickets = () => readLocal<Ticket[]>(ticketKey, [{ id: 'SUP1001', bookingId: '#HB28493', subject: 'Please help assign a beauty expert', customer: 'Kavya Menon', category: 'Assignment', priority: 'High', status: 'Open', owner: 'Unassigned', created: '2026-10-20', messages: [{ at: '2026-10-20T10:00:00+05:30', text: 'Customer asked for an update on worker assignment.' }] }, { id: 'SUP1002', bookingId: '#HB28497', subject: 'Refund receipt clarification', customer: 'Ishita Roy', category: 'Payment', priority: 'Normal', status: 'In review', owner: 'Priya Sharma', created: '2026-10-19', messages: [] }])
export type Settings = { cities: string[]; opens: string; closes: string; slot: number; lead: number; cancelHours: number; rescheduleHours: number; assignmentMinutes: number; otpRequired: boolean; notifications: boolean; defaultCompensation: number }
export const settingsKey = 'hi-beauty-settings-v1'
export const loadSettings = () => readLocal<Settings>(settingsKey, { cities: ['Bengaluru', 'Mumbai', 'Delhi', 'Pune', 'Ahmedabad', 'Kochi', 'Kolkata', 'Surat'], opens: '09:00', closes: '20:00', slot: 30, lead: 120, cancelHours: 4, rescheduleHours: 4, assignmentMinutes: 5, otpRequired: true, notifications: true, defaultCompensation: 50000 })
export type Settlement = { id: string; expert: string; date: string; cashReceived: number; compensationPaid: number; reference: string; note: string }
export const settlementKey = 'hi-beauty-settlements-v1'
export const loadSettlements = () => readLocal<Settlement[]>(settlementKey, [])
