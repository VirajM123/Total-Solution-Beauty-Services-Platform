export type OfferAudience = 'customer' | 'worker'
export type OfferImage = { src: string; crop?: [number, number, number, number]; artwork?: 'rose' | 'gold' | 'teal' }
export type Offer = { id: string; title: string; image: OfferImage | null; audiences: OfferAudience[]; type: 'percentage' | 'fixed' | 'announcement'; discount: number; code: string; categoryId: string; message: string; start: string; end: string; action: 'details' | 'category' | 'jobs'; order: number; published: boolean }
export const offerStorageKey = 'hi-beauty-offers-v1'
const image = (crop: OfferImage['crop'], artwork: OfferImage['artwork']): OfferImage => ({ src: '/offers/design-banners.png', crop, artwork })
export const initialOffers: Offer[] = [
  { id: 'glow', title: 'Glow Days', image: image([999, 227, 108, 120], 'rose'), audiences: ['customer'], type: 'percentage', discount: 20, code: 'GLOW20', categoryId: 'facial', message: 'Reveal your glow with a refreshing facial.', start: '2026-10-20', end: '2026-10-31', action: 'category', order: 1, published: true },
  { id: 'beauty', title: 'Your Next Self-Care Day', image: image([542, 555, 176, 99], 'gold'), audiences: ['customer', 'worker'], type: 'fixed', discount: 300, code: 'BEAUTY300', categoryId: '', message: 'A little care, a little saving.', start: '2026-10-20', end: '2026-10-31', action: 'details', order: 2, published: true },
  { id: 'weekend', title: 'Grow with Hi Beauty', image: image([575, 779, 140, 97], 'teal'), audiences: ['worker'], type: 'announcement', discount: 0, code: '', categoryId: '', message: 'Complete 5 bookings and earn extra rewards.', start: '2026-10-24', end: '2026-10-25', action: 'jobs', order: 1, published: true },
  { id: 'worker-care', title: 'A Beautiful Workday', image: image([575, 779, 140, 97], 'teal'), audiences: ['worker'], type: 'announcement', discount: 0, code: '', categoryId: '', message: 'Explore new opportunities with Hi Beauty.', start: '2026-10-20', end: '2026-10-31', action: 'jobs', order: 3, published: true },
  { id: 'festive', title: 'Festive Glow', image: image([999, 227, 108, 120], 'rose'), audiences: ['customer'], type: 'percentage', discount: 15, code: 'FESTIVE15', categoryId: '', message: 'A festive treat for your next appointment.', start: '2026-10-26', end: '2026-11-05', action: 'details', order: 4, published: true },
  { id: 'welcome', title: 'Welcome to Hi Beauty', image: image([542, 555, 176, 99], 'gold'), audiences: ['customer', 'worker'], type: 'announcement', discount: 0, code: '', categoryId: '', message: 'Beauty and opportunity, all in one place.', start: '2026-10-20', end: '2026-11-30', action: 'details', order: 5, published: false },
]
const validDate = (value: string) => /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value
export function offerStatus(offer: Offer, now = new Date()): 'Draft' | 'Scheduled' | 'Live' | 'Expired' {
  if (!offer.published || !validDate(offer.start) || !validDate(offer.end) || offer.end < offer.start) return 'Draft'
  if (now.getTime() < Date.parse(`${offer.start}T00:00:00+05:30`)) return 'Scheduled'
  if (now.getTime() > Date.parse(`${offer.end}T23:59:59.999+05:30`)) return 'Expired'
  return 'Live'
}
export function appOffers(offers: Offer[], audience: OfferAudience, now = new Date()): Offer[] { return offers.filter(offer => offer.audiences.includes(audience) && offerStatus(offer, now) === 'Live').sort((a, b) => a.order - b.order || a.id.localeCompare(b.id)) }
export function validateOffer(offer: Offer, _offers: Offer[]): void {
  if (!offer.title.trim()) throw new Error('Enter an offer title.')
  if (!offer.audiences.length || offer.audiences.some(a => !['customer', 'worker'].includes(a))) throw new Error('Select Customer app, Worker app, or both.')
  if (!validDate(offer.start) || !validDate(offer.end) || offer.end < offer.start) throw new Error('Choose valid start and end dates in order.')
  if (!Number.isInteger(offer.order) || offer.order < 1) throw new Error('Display order must be a positive whole number.')
  if (offer.type !== 'announcement' && (!Number.isFinite(offer.discount) || offer.discount <= 0 || (offer.type === 'percentage' && offer.discount > 100))) throw new Error('Enter a valid discount. Percentage discounts cannot exceed 100%.')
  if (offer.type !== 'announcement' && !/^[A-Z0-9_-]{3,24}$/.test(offer.code)) throw new Error('Promo codes need 3–24 letters, numbers, hyphens or underscores.')
  if (offer.action === 'category' && (offer.audiences.length !== 1 || offer.audiences[0] !== 'customer' || !offer.categoryId)) throw new Error('Category banners need a customer-only audience and a service category.')
  if (offer.action === 'jobs' && (offer.audiences.length !== 1 || offer.audiences[0] !== 'worker')) throw new Error('Job banners can only target the Worker app.')
  if (offer.published && !offer.image) throw new Error('Upload a banner image before publishing.')
}
export function loadOffers(): Offer[] {
  try {
    const data: unknown = JSON.parse(localStorage.getItem(offerStorageKey) ?? 'null')
    if (Array.isArray(data) && data.every(o => o && ['id', 'title', 'code', 'categoryId', 'message', 'start', 'end'].every(key => typeof o[key] === 'string') && Array.isArray(o.audiences) && o.audiences.every((a: string) => ['customer', 'worker'].includes(a)) && ['percentage', 'fixed', 'announcement'].includes(o.type) && ['details', 'category', 'jobs'].includes(o.action) && Number.isFinite(o.discount) && Number.isFinite(o.order) && typeof o.published === 'boolean' && (o.image === null || (typeof o.image?.src === 'string' && (o.image.src === '/offers/design-banners.png' || /^data:image\/(png|jpeg|webp);base64,/.test(o.image.src)) && (!o.image.crop || Array.isArray(o.image.crop) && o.image.crop.length === 4 && o.image.crop.every(Number.isFinite)))))) return data as Offer[]
  } catch { /* Restore sample campaigns when browser data is unavailable or invalid. */ }
  return initialOffers
}
