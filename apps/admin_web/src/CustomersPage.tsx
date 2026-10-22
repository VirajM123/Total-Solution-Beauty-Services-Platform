import { currency, loadBookings, todayIST, saveLocal, exportCsv } from './adminData'
import { loadPaymentStore } from './paymentsData'
import { jump } from './AdminUI'
import { useEffect, useRef, useState } from 'react'
import { Icon } from './Icon'
import './BookingsPage.css'
import './CustomersPage.css'

type Customer = { id: string; name: string; email: string; phone: string; city: string; bookings: number; spent: number; lastBooking: string; joined: string; service: string; status: 'Active' | 'Inactive'; notes: string; addresses?: string[]; restricted?: boolean }
const services = ['Gold Facial', 'Hair Spa', 'Bridal Makeup', 'Manicure & Pedicure']
const names = ['Ananya Sharma', 'Rohini Iyer', 'Kavya Menon', 'Sneha Patel', 'Pooja Desai', 'Meera Nair', 'Ishita Roy', 'Riya Shah', 'Aditi Rao', 'Sana Khan', 'Nisha Jain', 'Diya Kapoor']
const cities = ['Bengaluru', 'Mumbai', 'Delhi', 'Ahmedabad', 'Pune', 'Kochi', 'Kolkata', 'Surat']
const initialCustomers: Customer[] = names.map((name, i) => ({ id: `HBC${1001 + i}`, name, email: `${name.toLowerCase().replace(' ', '.')}@example.com`, phone: `+91 ${9876543210 - i * 1137}`, city: cities[i % cities.length], bookings: [12, 8, 5, 9, 3, 2, 6, 1][i % 8], spent: [24890, 11992, 32495, 14691, 6597, 2998, 13194, 1299][i % 8], lastBooking: i === 5 ? '2026-09-03' : `2026-10-${20 - (i % 6)}`, joined: i > 7 ? '2026-10-12' : '2026-05-08', service: services[i % services.length], status: i === 5 || i === 10 ? 'Inactive' : 'Active', notes: '' }))
const money = (n: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n)
const dateLabel = (date: string) => date ? new Date(`${date}T12:00:00`).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : 'No bookings yet'
const initials = (name: string) => name.trim().split(/\s+/).map(part => part[0]).slice(0, 2).join('')
const storageKey = 'hi-beauty-customers-v1'

export default function CustomersPage({ globalQuery, city }: { globalQuery: string; city: string }) {
  const [storedCustomers, setCustomers] = useState<Customer[]>(() => {
    try {
      const data: unknown = JSON.parse(localStorage.getItem(storageKey) ?? 'null')
      if (Array.isArray(data) && data.every(c => c && ['id', 'name', 'email', 'phone', 'city', 'lastBooking', 'joined', 'service', 'notes'].every(key => typeof c[key] === 'string') && ['Active', 'Inactive'].includes(c.status) && Number.isFinite(c.bookings) && Number.isFinite(c.spent))) return data as Customer[]
    } catch { /* Fall back to sample customer records. */ }
    return initialCustomers
  })
  const operations = loadBookings(), finances = loadPaymentStore()
  const customers = storedCustomers.map(customer => {
    const history = operations.filter(b => b.customerId === customer.id || b.customer === customer.name)
    const paid = finances.payments.filter(p => history.some(b => b.id === p.booking) && ['Paid', 'Refunded'].includes(p.status))
    return { ...customer, bookings: history.length, spent: (paid.reduce((sum, p) => sum + p.amount, 0) - finances.refunds.filter(r => r.status === 'Refunded' && paid.some(p => p.id === r.paymentId)).reduce((sum, r) => sum + r.amount, 0)) / 100, lastBooking: history.map(b => b.date).sort().at(-1) ?? '', service: history.at(-1)?.service ?? '' }
  })
  const [tab, setTab] = useState('All customers')
  const [search, setSearch] = useState('')
  const [service, setService] = useState('')
  const [moreFilters, setMoreFilters] = useState(false)
  const [minBookings, setMinBookings] = useState('')
  const [joinedAfter, setJoinedAfter] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(8)
  const [selected, setSelected] = useState<string[]>([])
  const [editing, setEditing] = useState<Customer | null>(null)
  const [profileId, setProfileId] = useState<string | null>(null)
  const [notice, setNotice] = useState('')
  const formDialog = useRef<HTMLDialogElement>(null)
  const profileDialog = useRef<HTMLDialogElement>(null)
  const profile = customers.find(c => c.id === profileId)
  useEffect(() => {
    try { saveLocal(storageKey, storedCustomers) }
    catch { setNotice('Changes are available for this session; browser storage is unavailable.') }
  }, [storedCustomers])
  const counts = { 'All customers': customers.length, Active: customers.filter(c => c.status === 'Active').length, 'New this month': customers.filter(c => c.joined.startsWith(todayIST().slice(0, 7))).length, Inactive: customers.filter(c => c.status === 'Inactive').length }
  const filtered = customers.filter(c => {
    const text = `${c.name} ${c.phone} ${c.phone.replace(/\D/g, '')} ${c.email} ${c.city}`.toLowerCase()
    return text.includes(search.toLowerCase()) && text.includes(globalQuery.toLowerCase()) && (city === 'All cities' || c.city === city) && (!service || c.service === service) && (!minBookings || c.bookings >= Number(minBookings)) && (!joinedAfter || c.joined >= joinedAfter) && (tab === 'All customers' || (tab === 'New this month' ? c.joined.startsWith('2026-10') : c.status === tab))
  })
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, pages)
  const offset = (currentPage - 1) * pageSize
  const visible = filtered.slice(offset, offset + pageSize)
  function openProfile(customer: Customer) { setProfileId(customer.id); profileDialog.current?.showModal() }
  function openForm(customer: Customer | null) { setEditing(customer); profileDialog.current?.close(); formDialog.current?.showModal() }
  function toggleStatus(customer: Customer) {
    const status = customer.status === 'Active' ? 'Inactive' : 'Active'
    setCustomers(previous => previous.map(c => c.id === customer.id ? { ...c, status } : c))
    setNotice(`${customer.name} marked ${status.toLowerCase()}.`)
  }
  function exportCustomers() {
    const rows = [['Customer ID', 'Name', 'Email', 'Phone', 'City', 'Bookings', 'Total spent (INR)', 'Last booking', 'Status'], ...filtered.map(c => [c.id, c.name, c.email, c.phone, c.city, String(c.bookings), String(c.spent), c.lastBooking, c.status])]
    const csv = rows.map(row => row.map(value => `"${value.replace(/^[=+@-]/, "'$&").replaceAll('"', '""')}"`).join(',')).join('\r\n')
    const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' }))
    const link = document.createElement('a'); link.href = url; link.download = 'hi-beauty-customers.csv'; link.click(); URL.revokeObjectURL(url)
    setNotice(`Exported ${filtered.length} customers.`)
  }
  return <div className="bookings-page customers-page">
    <section className="bp-heading"><div><h1>Customers</h1><p>Know your customers. Make every visit personal.</p></div><div className="bp-heading-actions"><button className="bp-button bp-export" onClick={exportCustomers}><Icon name="download" />Export</button><button className="bp-button bp-primary" onClick={() => openForm(null)}><span className="bp-plus">+</span>Add customer</button></div></section>
    <section className="bp-panel" aria-label="Manage customers">
      <div className="bp-panel-top"><div className="bp-tabs" aria-label="Customer status filters">{Object.entries(counts).map(([name, count]) => <button key={name} aria-pressed={tab === name} onClick={() => { setTab(name); setPage(1) }}>{name}<span>{count}</span></button>)}</div></div>
      <div className="bp-filters"><label className="bp-search"><Icon name="search" size={18} /><input aria-label="Search customers" placeholder="Search name, phone or email..." value={search} onChange={e => { setSearch(e.target.value); setPage(1) }} /></label><label className="bp-select"><select aria-label="Filter customers by service" value={service} onChange={e => { setService(e.target.value); setPage(1) }}><option value="">All services</option>{services.map(name => <option key={name}>{name}</option>)}</select></label><button className="bp-button" aria-expanded={moreFilters} onClick={() => setMoreFilters(!moreFilters)}><Icon name="bars" size={16} />More filters{(minBookings || joinedAfter) && <span className="bp-filter-dot" />}</button></div>
      {moreFilters && <div className="bp-extra-filters"><label>Minimum bookings<input type="number" min="0" value={minBookings} onChange={e => { setMinBookings(e.target.value); setPage(1) }} /></label><label>Joined on or after<input type="date" value={joinedAfter} onChange={e => { setJoinedAfter(e.target.value); setPage(1) }} /></label><button className="bp-button" onClick={() => { setMinBookings(''); setJoinedAfter(''); setService(''); setSearch(''); setPage(1) }}>Clear filters</button></div>}
      {selected.length > 0 && <div className="bp-selection">{selected.length} customers selected<button onClick={() => { const rows = customers.filter(c => selected.includes(c.id)); exportCsv('selected-customers', [['Name', 'Email', 'Phone'], ...rows.map(c => [c.name, c.email, c.phone])]) }}>Export selected</button><button onClick={() => setSelected([])}>Clear selection</button></div>}
      <div className="ui-mobile-records" aria-label="Customer cards">{visible.map(c => <article key={c.id}><div className="ui-card-title"><label><input type="checkbox" aria-label={`Select customer card ${c.name}`} checked={selected.includes(c.id)} onChange={e => setSelected(e.target.checked ? [...selected, c.id] : selected.filter(id => id !== c.id))} /> Select</label><span className={`bp-badge cp-${c.status.toLowerCase()}`}>{c.status}</span></div><h3><button className="final-text-button" onClick={() => openProfile(c)}>{c.name}</button></h3><p>{c.email}<br />{c.phone} · {c.city}</p><dl className="ui-card-metrics"><div><dt>Bookings</dt><dd>{c.bookings}</dd></div><div><dt>Total spent</dt><dd>{money(c.spent)}</dd></div></dl><p>Last booking: {dateLabel(c.lastBooking)}</p><button className="bp-button bp-primary" onClick={() => openProfile(c)}>View profile</button></article>)}{!visible.length && <p>No customers found. Adjust your filters.</p>}</div><div className="bp-table-scroll" role="region" aria-label="Customers table, scroll horizontally and vertically" tabIndex={0}><table><thead><tr><th><input type="checkbox" aria-label="Select all customers on this page" checked={visible.length > 0 && visible.every(c => selected.includes(c.id))} onChange={e => setSelected(e.target.checked ? [...new Set([...selected, ...visible.map(c => c.id)])] : selected.filter(id => !visible.some(c => c.id === id)))} /></th>{['Customer / contact', 'City', 'Bookings', 'Total spent', 'Last booking', 'Status', 'Actions'].map(label => <th scope="col" key={label}>{label}</th>)}</tr></thead><tbody>{visible.map(c => <tr key={c.id} className={selected.includes(c.id) ? 'bp-row-selected' : ''}><td><input type="checkbox" aria-label={`Select ${c.name}`} checked={selected.includes(c.id)} onChange={e => setSelected(e.target.checked ? [...selected, c.id] : selected.filter(id => id !== c.id))} /></td><td><div className="bp-person"><span className="bp-avatar">{initials(c.name)}</span><div><button className="bp-id" onClick={() => openProfile(c)}>{c.name}</button><small>{c.email}</small><small>{c.phone}</small></div></div></td><td>{c.city}</td><td className="cp-number">{c.bookings}</td><td className="bp-amount">{money(c.spent)}</td><td>{dateLabel(c.lastBooking)}</td><td><span className={`bp-badge cp-${c.status.toLowerCase()}`}>{c.status}</span></td><td><div className="cp-actions"><button className="cp-profile-button" onClick={() => openProfile(c)}>View profile</button><button className="bp-more" aria-label={`Manage customer ${c.name}`} aria-haspopup="dialog" onClick={() => openProfile(c)}>&#8942;</button></div></td></tr>)}{!visible.length && <tr><td colSpan={8} className="bp-empty"><Icon name="users" size={30} /><strong>No customers found</strong><span>Try another search or adjust your filters.</span></td></tr>}</tbody></table></div>
      <div className="bp-pagination"><span aria-live="polite">Showing {filtered.length ? offset + 1 : 0}&ndash;{Math.min(offset + pageSize, filtered.length)} of {filtered.length} customers</span><label>Rows per page<select aria-label="Customers per page" value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); setPage(1) }}>{[8, 16, 24].map(size => <option key={size}>{size}</option>)}</select></label><nav aria-label="Customer pages"><button disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)}>Previous</button>{Array.from({ length: pages }, (_, i) => i + 1).map(number => <button key={number} aria-label={`Customer page ${number}`} aria-current={currentPage === number ? 'page' : undefined} onClick={() => setPage(number)}>{number}</button>)}<button disabled={currentPage === pages} onClick={() => setPage(currentPage + 1)}>Next</button></nav></div>
    </section>
    <p className="bp-notice" role="status">{notice}</p>
    <dialog ref={formDialog} className="bp-dialog" aria-labelledby="customer-form-title"><form key={editing?.id ?? 'new'} onSubmit={event => {
      event.preventDefault()
      const form = event.currentTarget
      const data = new FormData(form)
      const name = String(data.get('name')).trim(), email = String(data.get('email')).trim(), phone = String(data.get('phone')).trim(), customerCity = String(data.get('city')).trim()
      if (!name || !customerCity || !phone.replace(/\D/g, '')) { setNotice('Enter a customer name, city and valid phone number.'); return }
      const emailInput = form.elements.namedItem('email') as HTMLInputElement
      if (customers.some(c => c.id !== editing?.id && c.email.toLowerCase() === email.toLowerCase())) { emailInput.setCustomValidity('A customer with this email already exists.'); emailInput.reportValidity(); return }
      const customer: Customer = { id: editing?.id ?? `HBC${Math.max(1000, ...customers.map(c => Number(c.id.slice(3)))) + 1}`, name, email, phone, city: customerCity, notes: String(data.get('notes')).trim(), addresses: String(data.get('addresses') ?? '').split('\n').map(a => a.trim()).filter(Boolean), restricted: editing?.restricted ?? false, status: editing?.status ?? 'Active', bookings: editing?.bookings ?? 0, spent: editing?.spent ?? 0, lastBooking: editing?.lastBooking ?? '', joined: editing?.joined ?? todayIST(), service: editing?.service ?? '' }
      setCustomers(previous => editing ? previous.map(c => c.id === editing.id ? customer : c) : [customer, ...previous])
      setNotice(`${name} ${editing ? 'updated' : 'added'} successfully. Changes are saved in this browser.`)
      formDialog.current?.close(); setTab('All customers'); setPage(1)
    }}><div className="bp-dialog-heading"><div><h2 id="customer-form-title">{editing ? 'Edit customer' : 'Add customer'}</h2><p>{editing ? editing.id : 'Make every visit personal.'}</p></div><button type="button" aria-label="Close customer form" onClick={() => formDialog.current?.close()}>&times;</button></div><div className="bp-form-grid"><label>Full name<input name="name" defaultValue={editing?.name ?? ''} required maxLength={80} /></label><label>Email<input name="email" type="email" defaultValue={editing?.email ?? ''} required maxLength={120} onInput={e => e.currentTarget.setCustomValidity('')} /></label><label>Phone<input name="phone" type="tel" pattern="[+0-9 ()-]{10,20}" defaultValue={editing?.phone ?? ''} required title="Enter a phone number with 10 to 20 characters" /></label><label>City<input name="city" defaultValue={editing?.city ?? ''} required maxLength={60} /></label><label className="cp-notes-label">Saved addresses (one per line)<textarea name="addresses" defaultValue={editing?.addresses?.join('\n') ?? ''} maxLength={1000} /></label><label className="cp-notes-label">Customer notes<textarea name="notes" defaultValue={editing?.notes ?? ''} maxLength={1000} placeholder="Preferences or appointment notes" /></label></div><footer><button type="button" className="bp-button" onClick={() => formDialog.current?.close()}>Cancel</button><button className="bp-button bp-primary">{editing ? 'Save changes' : 'Add customer'}</button></footer></form></dialog>
    <dialog ref={profileDialog} className="bp-dialog" aria-labelledby="customer-profile-title">{profile && <><div className="bp-dialog-heading"><div className="bp-person"><span className="bp-avatar">{initials(profile.name)}</span><div><h2 id="customer-profile-title">{profile.name}</h2><p>{profile.id} · Customer profile</p></div></div><button aria-label="Close customer profile" onClick={() => profileDialog.current?.close()}>&times;</button></div><dl className="bp-details">{Object.entries({ Email: profile.email, Phone: profile.phone, City: profile.city, Status: profile.status, 'Account access': profile.restricted ? 'Restricted (preview)' : 'Allowed (preview)', Bookings: String(profile.bookings), 'Total spent': money(profile.spent), 'Last booking': dateLabel(profile.lastBooking), 'Last service': profile.service || 'No service booked', 'Customer since': dateLabel(profile.joined) }).map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>{profile.notes && <div className="cp-notes"><strong>Customer notes</strong><p>{profile.notes}</p></div>}<h3>Service addresses</h3><div className="final-mini-history">{[...new Set([...(profile.addresses ?? []), ...operations.filter(b => b.customerId === profile.id || b.customer === profile.name).map(b => b.address)])].map(address => <p key={address}>{address}</p>)}</div><h3>Booking history</h3><div className="final-mini-history">{operations.filter(b => b.customerId === profile.id || b.customer === profile.name).map(b => <button className="final-history-link" key={b.id} onClick={() => { profileDialog.current?.close(); jump('bookings', 'booking=' + encodeURIComponent(b.id)) }}><b>{b.id} · {b.service}</b><span>{currency(b.price - b.discount + b.fee)} · {b.status}</span><small>{b.date} · {b.address}</small></button>)}</div><div className="bp-booking-actions"><button className="bp-button bp-primary" onClick={() => openForm(profile)}>Edit customer</button><button className="bp-button bp-danger" onClick={() => { setCustomers(previous => previous.map(c => c.id === profile.id ? { ...c, restricted: !profile.restricted } : c)); setNotice('Account restriction saved locally. Backend access control is not connected.') }}>{profile.restricted ? 'Remove restriction' : 'Restrict account'}</button><button className="bp-button" onClick={() => toggleStatus(profile)}>{profile.status === 'Active' ? 'Mark inactive' : 'Reactivate customer'}</button><a className="bp-button" href={`tel:${profile.phone.replace(/[^+0-9]/g, '')}`}>Call customer</a><a className="bp-button" href={`mailto:${profile.email}`}>Email customer</a></div></>}</dialog>
  </div>
}
