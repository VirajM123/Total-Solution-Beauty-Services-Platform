export type ExpertStatus = 'Pending review' | 'Active' | 'Rejected' | 'Suspended'
export type ExpertDocument = { name: string; kind: 'identity' | 'certificate'; data?: string }
export type Expert = { id: string; name: string; phone: string; email: string; city: string; speciality: string; experience: number; applied: string; status: ExpertStatus; documents: ExpertDocument[]; reason: string; reviewedAt: string }
export const expertStorageKey = 'hi-beauty-experts-v1'
export const specialities = ['Facial & Skincare', 'Hair Styling', 'Bridal Makeup', 'Nail Care', 'Waxing']
export const expertCities = ['Pune', 'Mumbai', 'Bengaluru', 'Kochi', 'Delhi', 'Ahmedabad']
export const sampleExperts: Expert[] = ['Aarti Mishra', 'Divya Joshi', 'Sana Shaikh', 'Priya Nair', 'Ritu Sharma', 'Megha Patel', 'Neha Verma', 'Pooja Nair', 'Simran Kaur', 'Ritika Singh', 'Anita Roy', 'Kiran Desai', 'Maya Rao', 'Nisha Jain'].map((name, i) => ({ id: `EX${1025 - i}`, name, phone: `+91 ${9876543210 - i * 1237}`, email: `${name.toLowerCase().replace(' ', '.')}@example.com`, city: ({ 'Neha Verma': 'Bengaluru', 'Pooja Nair': 'Mumbai', 'Simran Kaur': 'Delhi', 'Ritika Singh': 'Ahmedabad' } as Record<string, string>)[name] ?? expertCities[i % 6], speciality: ({ 'Neha Verma': 'Facial & Skincare', 'Pooja Nair': 'Hair Styling', 'Simran Kaur': 'Bridal Makeup', 'Ritika Singh': 'Nail Care' } as Record<string, string>)[name] ?? specialities[i % 5], experience: [4, 3, 5, 2][i % 4], applied: `2026-10-${String(20 - Math.floor(i / 2)).padStart(2, '0')}`, status: i < 6 ? 'Pending review' : i < 11 ? 'Active' : i < 13 ? 'Rejected' : 'Suspended', documents: [{ name: 'Identity proof', kind: 'identity' }, { name: 'Beauty certification', kind: 'certificate' }], reason: i >= 11 && i < 13 ? 'Please submit a current beauty certification.' : '', reviewedAt: i >= 6 ? '2026-10-20T09:00:00+05:30' : '' }))
export function loadExperts(): Expert[] {
  try {
    const data: unknown = JSON.parse(localStorage.getItem(expertStorageKey) ?? 'null')
    if (Array.isArray(data) && data.every(e => e && ['id', 'name', 'phone', 'email', 'city', 'speciality', 'applied', 'reason', 'reviewedAt'].every(key => typeof e[key] === 'string') && Number.isFinite(e.experience) && ['Pending review', 'Active', 'Rejected', 'Suspended'].includes(e.status) && Array.isArray(e.documents) && e.documents.every((d: ExpertDocument) => ['identity', 'certificate'].includes(d.kind) && typeof d.name === 'string' && (!d.data || /^data:(image\/(png|jpeg)|application\/pdf);base64,/.test(d.data))))) return data as Expert[]
  } catch { /* Use sample applications when browser storage cannot be read. */ }
  return sampleExperts
}
export function decideApplication(expert: Expert, decision: 'approve' | 'reject', reviewed: boolean, reason = ''): Expert {
  if (expert.status !== 'Pending review') throw new Error('Only pending applications can be reviewed.')
  if (decision === 'approve' && (!reviewed || !['identity', 'certificate'].every(kind => expert.documents.some(d => d.kind === kind)))) throw new Error('Review both required documents before approving.')
  if (decision === 'reject' && !reason.trim()) throw new Error('Enter a rejection reason.')
  return { ...expert, status: decision === 'approve' ? 'Active' : 'Rejected', reason: decision === 'reject' ? reason.trim() : '', reviewedAt: new Date().toISOString() }
}
