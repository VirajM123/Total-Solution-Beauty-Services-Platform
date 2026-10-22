export type ServiceImage = { src: string; crop?: [number, number, number, number] }
export type MainService = { id: string; name: string; image: ServiceImage | null; published?: boolean }
export type SubService = { id: string; parentId: string; name: string; price: number; duration: number; description: string; status: 'Active' | 'Inactive'; available: boolean; image: ServiceImage | null; published?: boolean; serviceAreas?: string[] }
export type ServiceCatalog = { main: MainService[]; sub: SubService[] }
const photo = (crop: ServiceImage['crop']): ServiceImage => ({ src: '/services/design-photos.png', crop })
export const initialCatalog: ServiceCatalog = {
  main: [
    { id: 'facial', name: 'Facial & Skincare', image: photo([280, 273, 75, 69]) },
    { id: 'hair', name: 'Hair Care', image: photo([280, 368, 75, 72]) },
    { id: 'makeup', name: 'Makeup', image: photo([280, 467, 75, 72]) },
    { id: 'nail', name: 'Nail Care', image: photo([280, 568, 75, 72]) },
    { id: 'waxing', name: 'Waxing', image: photo([280, 669, 75, 72]) },
  ],
  sub: [
    { id: 'gold', parentId: 'facial', name: 'Gold Facial', price: 2199, duration: 60, description: 'A rejuvenating facial for soft, radiant skin.', status: 'Active', available: true, image: photo([605, 342, 234, 129]) },
    { id: 'cleanup', parentId: 'facial', name: 'Express Cleanup', price: 899, duration: 30, description: 'A refreshing cleanse for clean, healthy skin.', status: 'Active', available: true, image: photo([859, 342, 234, 129]) },
    { id: 'hydrating', parentId: 'facial', name: 'Hydrating Facial', price: 1699, duration: 45, description: 'Deep hydration for smooth, nourished skin.', status: 'Active', available: true, image: photo([605, 589, 234, 129]) },
    { id: 'ageing', parentId: 'facial', name: 'Anti-Ageing Facial', price: 2499, duration: 75, description: 'A restorative treatment for refreshed skin.', status: 'Active', available: true, image: photo([859, 589, 234, 129]) },
    ...[['hair', 'Hair Spa', 1499, 45], ['hair', 'Haircut & Styling', 999, 45], ['hair', 'Hair Colour', 2999, 90], ['makeup', 'Bridal Makeup', 8499, 120], ['makeup', 'Party Makeup', 2999, 60], ['nail', 'Classic Manicure', 799, 40], ['nail', 'Pedicure', 999, 45], ['nail', 'Nail Art', 1299, 60], ['waxing', 'Full Body Waxing', 2499, 90], ['waxing', 'Arms Waxing', 699, 30]].map(([parent, name, price, duration], i): SubService => ({ id: `service-${i}`, parentId: String(parent), name: String(name), price: Number(price), duration: Number(duration), description: `Professional ${String(name).toLowerCase()} by our beauty experts.`, status: i === 7 || i === 9 ? 'Inactive' : 'Active', available: i !== 7 && i !== 9, image: photo([280, parent === 'hair' ? 368 : parent === 'makeup' ? 467 : parent === 'nail' ? 568 : 669, 75, 72]) })),
  ],
}
export const catalogStorageKey = 'hi-beauty-services-v1'
export function loadCatalog(): ServiceCatalog {
  try {
    const data = JSON.parse(localStorage.getItem(catalogStorageKey) ?? 'null') as ServiceCatalog | null
    const imageValid = (image: ServiceImage | null) => image === null || (typeof image?.src === 'string' && (image.src === '/services/design-photos.png' || /^data:image\/(png|jpeg|webp);base64,/.test(image.src)) && (!image.crop || image.crop.length === 4 && image.crop.every(Number.isFinite)))
    if (data && Array.isArray(data.main) && Array.isArray(data.sub) && data.main.every(m => typeof m.id === 'string' && typeof m.name === 'string' && imageValid(m.image)) && data.sub.every(s => typeof s.id === 'string' && typeof s.name === 'string' && data.main.some(m => m.id === s.parentId) && Number.isFinite(s.price) && s.price >= 0 && Number.isFinite(s.duration) && s.duration > 0 && typeof s.description === 'string' && typeof s.available === 'boolean' && ['Active', 'Inactive'].includes(s.status) && imageValid(s.image))) return data
  } catch { /* Restore sample catalog if browser storage is unavailable or invalid. */ }
  return initialCatalog
}
