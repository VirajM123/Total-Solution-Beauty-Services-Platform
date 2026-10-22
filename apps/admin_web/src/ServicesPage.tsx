import { loadSettings, saveLocal } from './adminData'
import { useEffect, useRef, useState } from 'react'
import { Icon } from './Icon'
import { catalogStorageKey, loadCatalog, type MainService, type ServiceCatalog, type ServiceImage, type SubService } from './servicesData'
import './BookingsPage.css'
import './ServicesPage.css'

type Draft = { mode: 'main' | 'sub'; id: string | null; parentId: string; name: string; price: string; duration: string; description: string; status: 'Active' | 'Inactive'; available: boolean; image: ServiceImage | null; published: boolean; serviceAreas: string[] }
const subDraft = (service: SubService): Draft => ({ ...service, mode: 'sub', price: String(service.price), duration: String(service.duration), published: service.published !== false, serviceAreas: service.serviceAreas ?? [] })
const money = (amount: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(amount)
export function ServicePhoto({ image, label }: { image: ServiceImage | null; label: string }) {
  if (!image) return <div className="sp-image-placeholder"><Icon name="grid" size={26} /><span>No image</span></div>
  return image.crop ? <svg viewBox={image.crop.join(' ')} preserveAspectRatio="xMidYMid slice" role="img" aria-label={label}><image href={image.src} width="1586" height="992" /></svg> : <img src={image.src} alt={label} />
}
export async function uploadPhoto(file: File): Promise<ServiceImage> {
  if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type) || file.size > 5 * 1024 * 1024) throw new Error('Choose a JPG, PNG or WebP image no larger than 5 MB.')
  const url = URL.createObjectURL(file)
  try {
    const image = new Image(); image.src = url; await image.decode()
    const scale = Math.min(1, 1000 / Math.max(image.width, image.height))
    const canvas = document.createElement('canvas'); canvas.width = Math.max(1, Math.round(image.width * scale)); canvas.height = Math.max(1, Math.round(image.height * scale))
    const context = canvas.getContext('2d'); if (!context) throw new Error('Unable to process the image. Please try another file.')
    context.drawImage(image, 0, 0, canvas.width, canvas.height)
    return { src: canvas.toDataURL('image/webp', .8) }
  } catch { throw new Error('This image could not be opened. Choose a valid JPG, PNG or WebP file.') }
  finally { URL.revokeObjectURL(url) }
}
export default function ServicesPage({ globalQuery }: { globalQuery: string }) {
  const [catalog, setCatalog] = useState(loadCatalog)
  const [parentId, setParentId] = useState(() => loadCatalog().main[0]?.id ?? '')
  const [mainSearch, setMainSearch] = useState('')
  const [subSearch, setSubSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [draft, setDraft] = useState<Draft | null>(null)
  const [dirty, setDirty] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const editor = useRef<HTMLDialogElement>(null)
  useEffect(() => { if (draft) editor.current?.showModal() }, [draft?.id])
  const fileInput = useRef<HTMLInputElement>(null)
  const uploadGeneration = useRef(0)
  const parent = catalog.main.find(service => service.id === parentId)
  const visibleParents = catalog.main.filter(main => main.name.toLowerCase().includes(mainSearch.toLowerCase()) && `${main.name} ${catalog.sub.filter(s => s.parentId === main.id).map(s => s.name).join(' ')}`.toLowerCase().includes(globalQuery.toLowerCase()))
  const children = catalog.sub.filter(service => service.parentId === parentId)
  const visibleChildren = children.filter(service => service.name.toLowerCase().includes(subSearch.toLowerCase()) && `${parent?.name} ${service.name} ${service.description}`.toLowerCase().includes(globalQuery.toLowerCase()) && (!statusFilter || service.status === statusFilter))
  function canLeave() { return !dirty || window.confirm('Discard unsaved service changes?') }
  function showDraft(next: Draft | null) {
    uploadGeneration.current++; setProcessing(false); setDraft(next); setDirty(false); setError(''); if (fileInput.current) fileInput.current.value = ''
  }
  function editSub(service: SubService) { if (!canLeave()) return; showDraft(subDraft(service)); editor.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' }) }
  function editMain(service: MainService) { if (!canLeave()) return; showDraft({ mode: 'main', id: service.id, parentId: '', name: service.name, image: service.image, price: '', duration: '', description: '', status: 'Active', available: true, published: service.published !== false, serviceAreas: [] }); editor.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' }) }
  function add(mode: Draft['mode']) { if (!canLeave()) return; showDraft({ mode, id: null, parentId, name: '', image: null, price: '', duration: '60', description: '', status: 'Active', available: true, published: false, serviceAreas: [] }); editor.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' }) }
  function change(values: Partial<Draft>) { setDraft(previous => previous ? { ...previous, ...values } : previous); setDirty(true); setError('') }
  function chooseParent(id: string) { if (!canLeave()) return; setParentId(id); setSubSearch(''); setStatusFilter(''); showDraft(null) }
  function save(event: React.SubmitEvent<HTMLFormElement>) {
    event.preventDefault(); if (!draft || processing) return
    try {
      if (draft.published && !draft.image) throw new Error('Add a service image before publishing.');
      const name = draft.name.trim(); if (!name) throw new Error('Enter a service name.')
      const id = draft.id ?? crypto.randomUUID()
      let next: ServiceCatalog
      if (draft.mode === 'main') {
        if (catalog.main.some(m => m.id !== id && m.name.toLowerCase() === name.toLowerCase())) throw new Error('A main service with this name already exists.')
        const main: MainService = { id, name, image: draft.image, published: draft.published }
        next = { ...catalog, main: draft.id ? catalog.main.map(m => m.id === id ? main : m) : [...catalog.main, main] }
      } else {
        if (!catalog.main.some(m => m.id === draft.parentId)) throw new Error('Select a main service.')
        if (!draft.price.trim() || !Number.isFinite(Number(draft.price)) || Number(draft.price) < 0) throw new Error('Enter a valid price of zero or more.')
        if (!Number.isInteger(Number(draft.duration)) || Number(draft.duration) <= 0) throw new Error('Enter a positive duration in whole minutes.')
        if (catalog.sub.some(s => s.id !== id && s.parentId === draft.parentId && s.name.toLowerCase() === name.toLowerCase())) throw new Error('This sub-service already exists under the selected main service.')
        const sub: SubService = { id, parentId: draft.parentId, name, image: draft.image, price: Number(draft.price), duration: Number(draft.duration), description: draft.description.trim(), status: draft.status, available: draft.status === 'Active' && draft.available, published: draft.published, serviceAreas: draft.serviceAreas }
        next = { ...catalog, sub: draft.id ? catalog.sub.map(s => s.id === id ? sub : s) : [...catalog.sub, sub] }
      }
      try { saveLocal(catalogStorageKey, next, `${name}: catalog saved`) } catch { throw new Error('Browser storage is full or unavailable. Remove an image or use a smaller one, then save again.') }
      setCatalog(next); setParentId(draft.mode === 'main' ? id : draft.parentId); setMainSearch(''); setSubSearch(''); setStatusFilter(''); setNotice(`${name} ${draft.id ? 'updated' : 'added'} successfully. Saved in this browser.`); setDirty(false); setError(''); setDraft({ ...draft, id, name })
    } catch (problem) { setError(problem instanceof Error ? problem.message : 'Unable to save service.') }
  }
  return <div className="bookings-page services-page">
    <section className="bp-heading"><div><h1>Services</h1><p>Organize main services and their sub-services.</p></div><button className="bp-button bp-primary" onClick={() => add('main')}>+ Add main service</button></section>
    <div className={`sp-workspace${draft ? '' : ' sp-editor-closed'}`}>
<label className="ui-mobile-category">Service category<select aria-label="Service category" value={parentId} onChange={e => chooseParent(e.target.value)}>{visibleParents.map(main => <option key={main.id} value={main.id}>{main.name}</option>)}</select></label><section className="sp-main-panel" aria-label="Main services"><h2>Main services</h2><label className="bp-search"><Icon name="search" size={16} /><input aria-label="Search main services" placeholder="Search main services..." value={mainSearch} onChange={event => setMainSearch(event.target.value)} /></label><div className="sp-main-list">{visibleParents.map(main => <div key={main.id} className={`sp-main-row${main.id === parentId ? ' sp-parent-selected' : ''}`}><button className="sp-parent-button" aria-pressed={main.id === parentId} onClick={() => chooseParent(main.id)}><span className="sp-main-photo"><ServicePhoto image={main.image} label={main.name} /></span><span><strong>{main.name}</strong><small>{catalog.sub.filter(s => s.parentId === main.id).length} sub-services &#183; {main.published === false ? 'Draft' : 'Published'}</small></span></button><button className="sp-main-edit" aria-label={`Edit main service ${main.name}`} onClick={() => editMain(main)}>&#8943;</button></div>)}{!visibleParents.length && <p className="sp-empty">No main services found.</p>}</div><p className="sp-panel-hint">Select a main service to manage its sub-services.</p></section>
      <section className="sp-catalog" aria-label="Sub-services"><div className="sp-breadcrumb">Services <span>/</span> {parent?.name ?? 'Main services'}</div><div className="sp-catalog-heading"><div><h2>{parent?.name ?? 'Create your service menu'}</h2><small>{children.length} sub-services</small></div><div className="sp-catalog-actions">{parent && <><button className="bp-button sp-edit-button" onClick={() => editMain(parent)}>Edit main service</button><button className="bp-button bp-primary" onClick={() => add('sub')}>+ Add sub-service</button></>}</div></div><div className="sp-catalog-filters"><label className="bp-search"><Icon name="search" size={16} /><input aria-label="Search sub-services" placeholder="Search sub-services..." value={subSearch} onChange={e => setSubSearch(e.target.value)} /></label><select aria-label="Filter sub-service status" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}><option value="">All statuses</option><option>Active</option><option>Inactive</option></select></div><div className="sp-service-grid">{visibleChildren.map(service => <article key={service.id} className={`sp-service-card${draft?.mode === 'sub' && draft.id === service.id ? ' sp-sub-selected' : ''}`}><div className="sp-card-photo"><ServicePhoto image={service.image} label={service.name} /></div><div className="sp-card-body"><div className="sp-card-title"><h3>{service.name}</h3><span className={`sp-status sp-${service.published === false ? 'inactive' : service.status.toLowerCase()}`}>{service.published === false ? 'Draft' : service.status}</span></div><div className="sp-card-bottom"><strong>{money(service.price)}</strong><span><Icon name="clock" size={12} />{service.duration} min</span><button className="bp-button sp-edit-button" aria-label={`Edit sub-service ${service.name}`} onClick={() => editSub(service)}>Edit</button></div>{!service.available && <small className="sp-unavailable">Unavailable for booking</small>}</div></article>)}{!visibleChildren.length && <div className="sp-empty"><Icon name="grid" size={28} /><h3>No sub-services found</h3><p>{children.length ? 'Adjust your search or status filter.' : 'Add a sub-service to this main service to get started.'}</p></div>}</div><p className="sp-panel-hint">Showing {visibleChildren.length} of {children.length} sub-services</p></section>
      {draft && <dialog ref={editor} className="sp-editor ui-editor-dialog" aria-label="Service editor" onCancel={e => { e.preventDefault(); if (canLeave()) showDraft(null) }}><form onSubmit={save}><div className="sp-editor-heading"><div><h2>{draft.id ? 'Edit' : 'Add'} {draft.mode === 'main' ? 'main service' : 'sub-service'}</h2><p>{draft.mode === 'main' ? 'A group for related beauty treatments.' : `Listed under ${catalog.main.find(m => m.id === draft.parentId)?.name ?? 'a main service'}`}</p></div><button type="button" aria-label="Close service editor" onClick={() => { if (canLeave()) showDraft(null) }}>&times;</button></div>
        <h3 className="ui-form-section">Service details</h3>{draft.mode === 'sub' && <label className="sp-form-label">Main service<select value={draft.parentId} onChange={e => change({ parentId: e.target.value })} required>{catalog.main.map(main => <option key={main.id} value={main.id}>{main.name}</option>)}</select></label>}
        <div className="sp-image-field"><span className="sp-field-title">{draft.mode === 'main' ? 'Main service image' : 'Sub-service image'}</span><div className="sp-image-preview"><ServicePhoto image={draft.image} label="Service image preview" /></div><div className="sp-image-actions"><label className={`sp-upload-button${processing ? ' sp-uploading' : ''}`}><Icon name="download" size={15} />{processing ? 'Processing…' : draft.image ? 'Change image' : 'Upload image'}<input ref={fileInput} type="file" aria-label="Upload service image" accept="image/jpeg,image/png,image/webp" disabled={processing} onChange={async event => { const file = event.currentTarget.files?.[0]; if (!file) return; const generation = ++uploadGeneration.current; setProcessing(true); setError(''); try { const image = await uploadPhoto(file); if (generation === uploadGeneration.current) change({ image }) } catch (problem) { if (generation === uploadGeneration.current) setError(problem instanceof Error ? problem.message : 'Unable to read image.') } finally { if (generation === uploadGeneration.current) { setProcessing(false); if (fileInput.current) fileInput.current.value = '' } } }} /></label><button type="button" disabled={!draft.image || processing} onClick={() => change({ image: null })}>Remove</button></div><small>JPG, PNG or WebP · Max 5 MB</small></div>
        <label className="sp-form-label">{draft.mode === 'main' ? 'Main service name' : 'Sub-service name'}<input value={draft.name} onChange={e => change({ name: e.target.value })} required maxLength={80} /></label>
        {draft.mode === 'sub' && <><div className="sp-form-pair"><label className="sp-form-label">Price (₹)<input type="number" min="0" max="1000000" step="1" value={draft.price} required onChange={e => change({ price: e.target.value })} /></label><label className="sp-form-label">Duration (min)<input type="number" min="1" max="1440" step="1" value={draft.duration} required onChange={e => change({ duration: e.target.value })} /></label></div><label className="sp-form-label">Description<textarea value={draft.description} onChange={e => change({ description: e.target.value })} maxLength={1000} /></label><label className="sp-form-label">Status<select value={draft.status} onChange={e => change({ status: e.target.value as SubService['status'], available: e.target.value === 'Inactive' ? false : draft.available })}><option>Active</option><option>Inactive</option></select></label><label className="sp-available"><input type="checkbox" checked={draft.available} disabled={draft.status === 'Inactive'} onChange={e => change({ available: e.target.checked })} />Available for booking</label></>}
        <h3 className="ui-form-section">Publication & service areas</h3><label className="sp-available final-publish"><input type="checkbox" checked={draft.published} onChange={e => change({ published: e.target.checked })} />Published to catalog</label>
        {draft.mode === 'sub' && <fieldset className="final-checkset"><legend>Service areas</legend>{loadSettings().cities.map(area => <label key={area}><input type="checkbox" checked={draft.serviceAreas.includes(area)} onChange={e => change({ serviceAreas: e.target.checked ? [...draft.serviceAreas, area] : draft.serviceAreas.filter(a => a !== area) })} />{area}</label>)}<small>Leave empty to use all configured areas.</small></fieldset>}
        {error && <p className="sp-form-error" role="alert">{error}</p>}<div className="sp-form-footer"><button type="button" className="bp-button" onClick={() => { if (canLeave()) showDraft(null) }}>Cancel</button><button className="bp-button bp-primary" disabled={processing}>{processing ? 'Processing image…' : draft.id ? 'Save changes' : draft.mode === 'main' ? 'Add main service' : 'Add sub-service'}</button></div>
      </form></dialog>}
    </div><p className="bp-notice" role="status">{notice}</p>
  </div>
}
