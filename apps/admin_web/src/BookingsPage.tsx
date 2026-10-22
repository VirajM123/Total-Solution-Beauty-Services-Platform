import { useEffect, useRef, useState } from 'react'
import { Icon } from './Icon'
import './BookingsPage.css'

type Booking = { id: string; customer: string; city: string; service: string; expert: string; date: string; time: string; amount: number; payment: string; status: string }
const names = ['Ananya Sharma', 'Rohini Iyer', 'Kavya Menon', 'Sneha Patel', 'Pooja Desai', 'Meera Nair', 'Ishita Roy', 'Riya Shah', 'Aditi Rao', 'Sana Khan', 'Nisha Jain', 'Diya Kapoor']
const serviceNames = ['Gold Facial', 'Hair Spa', 'Bridal Makeup', 'Manicure & Pedicure']
const expertNames = ['Neha Verma', 'Pooja Nair', 'Simran Kaur', 'Ritika Singh']
const initialBookings: Booking[] = names.map((customer, i) => ({ id: `#HB${28491 + i}`, customer, city: ['Bengaluru', 'Mumbai', 'Delhi', 'Ahmedabad', 'Pune', 'Kochi', 'Kolkata', 'Surat'][i % 8], service: serviceNames[i % 4], expert: expertNames[i % 4], date: i < 4 ? '2026-10-20' : i < 8 ? '2026-10-21' : '2026-10-22', time: ['10:00', '11:30', '13:00', '15:30'][i % 4], amount: [2199, 1499, 8499, 1299][i % 4], payment: [2, 4, 6].includes(i) ? 'Unpaid' : 'Paid', status: ['Confirmed', 'Pending', 'Confirmed', 'Completed', 'Pending', 'Completed', 'Cancelled', 'Confirmed'][i % 8] }))
const money = (n: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n)
const dateLabel = (date: string) => new Date(`${date}T12:00:00`).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
const timeLabel = (time: string) => new Date(`2026-10-20T${time}`).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
const initials = (name: string) => name.split(' ').map(part => part[0]).slice(0, 2).join('')

function Badge({ value }: { value: string }) { return <span className={`bp-badge bp-${value.toLowerCase()}`}>{value}</span> }

export default function BookingsPage({ globalQuery, city }: { globalQuery: string; city: string }) {
  const [bookings, setBookings] = useState<Booking[]>(() => {
    try {
      const saved: unknown = JSON.parse(localStorage.getItem('hi-beauty-bookings-v1') ?? 'null')
      if (Array.isArray(saved) && saved.length && saved.every(b => b && typeof b === 'object' && ['id', 'customer', 'city', 'service', 'expert', 'date', 'time', 'payment', 'status'].every(key => typeof b[key] === 'string') && Number.isFinite(b.amount))) return saved as Booking[]
    } catch { /* Use sample records when browser storage is unavailable. */ }
    return initialBookings
  })
  const [editing, setEditing] = useState<Booking | null>(null)
  const [confirmCancel, setConfirmCancel] = useState(false)
  useEffect(() => {
    try { localStorage.setItem('hi-beauty-bookings-v1', JSON.stringify(bookings)) }
    catch { setNotice('Changes are available for this session; browser storage is unavailable.') }
  }, [bookings])
  const [tab, setTab] = useState('All bookings')
  const [search, setSearch] = useState('')
  const [service, setService] = useState('')
  const [expert, setExpert] = useState('')
  const [payment, setPayment] = useState('')
  const [start, setStart] = useState('')
  const [end, setEnd] = useState('')
  const [moreFilters, setMoreFilters] = useState(false)
  const [view, setView] = useState('List')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(8)
  const [selected, setSelected] = useState<string[]>([])
  const [detail, setDetail] = useState<Booking | null>(null)
  const [notice, setNotice] = useState('')
  const dialog = useRef<HTMLDialogElement>(null)
  const detailDialog = useRef<HTMLDialogElement>(null)
  const today = '2026-10-20'
  const counts = { 'All bookings': bookings.length, Today: bookings.filter(b => b.date === today).length, Upcoming: bookings.filter(b => b.date >= today && ['Confirmed', 'Pending'].includes(b.status)).length, Completed: bookings.filter(b => b.status === 'Completed').length, Cancelled: bookings.filter(b => b.status === 'Cancelled').length }
  const filtered = bookings.filter(b => {
    const text = `${b.id} ${b.customer} ${b.service} ${b.expert} ${b.city}`.toLowerCase()
    return (city === 'All cities' || b.city === city) && text.includes(search.toLowerCase()) && text.includes(globalQuery.toLowerCase()) && (!service || b.service === service) && (!expert || b.expert === expert) && (!payment || b.payment === payment) && (!start || b.date >= start) && (!end || b.date <= end) && (tab === 'All bookings' || (tab === 'Today' ? b.date === today : tab === 'Upcoming' ? b.date >= today && ['Confirmed', 'Pending'].includes(b.status) : b.status === tab))
  })
  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, pageCount)
  const offset = (currentPage - 1) * pageSize
  const visible = filtered.slice(offset, offset + pageSize)
  const resetPage = () => setPage(1)
  function exportBookings() {
    const rows = [['Booking ID', 'Customer', 'City', 'Service', 'Expert', 'Date', 'Time', 'Amount', 'Payment', 'Status'], ...filtered.map(b => [b.id, b.customer, b.city, b.service, b.expert, b.date, b.time, String(b.amount), b.payment, b.status])]
    const csv = rows.map(row => row.map(value => `"${value.replaceAll('"', '""')}"`).join(',')).join('\r\n')
    const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' }))
    const a = document.createElement('a'); a.href = url; a.download = 'hi-beauty-bookings.csv'; a.click(); URL.revokeObjectURL(url)
    setNotice(`Exported ${filtered.length} bookings.`)
  }
  function showDetails(booking: Booking) { setDetail(booking); setConfirmCancel(false); detailDialog.current?.showModal() }
  function updateBooking(id: string, changes: Partial<Booking>, message: string) {
    setBookings(previous => previous.map(b => b.id === id ? { ...b, ...changes } : b))
    setDetail(previous => previous?.id === id ? { ...previous, ...changes } : previous)
    setNotice(message)
  }
  function editBooking(booking: Booking) {
    setEditing(booking)
    detailDialog.current?.close()
    dialog.current?.showModal()
  }

  return <div className="bookings-page">
    <section className="bp-heading"><div><h1>Bookings</h1><p>Manage appointments, customers and experts.</p></div><div className="bp-heading-actions"><button className="bp-button bp-export" onClick={exportBookings}><Icon name="download" />Export</button><button className="bp-button bp-primary" onClick={() => { setEditing(null); dialog.current?.showModal() }}><span className="bp-plus">+</span>New booking</button></div></section>
    <section className="bp-panel" aria-label="Manage bookings">
      <div className="bp-panel-top"><div className="bp-tabs" aria-label="Booking status filters">{Object.entries(counts).map(([name, count]) => <button key={name} aria-pressed={tab === name} onClick={() => { setTab(name); resetPage() }}>{name}<span>{count}</span></button>)}</div><div className="bp-view-toggle">{(['List', 'Calendar']).map(mode => <button key={mode} aria-pressed={view === mode} onClick={() => setView(mode)}><Icon name={mode === 'List' ? 'menu' : 'calendar'} size={17} />{mode}</button>)}</div></div>
      <div className="bp-filters"><label className="bp-search"><Icon name="search" size={18} /><input aria-label="Search bookings" placeholder="Search by booking ID or customer..." value={search} onChange={e => { setSearch(e.target.value); resetPage() }} /></label><button className="bp-button bp-date-filter" aria-expanded={moreFilters} onClick={() => setMoreFilters(!moreFilters)}><Icon name="calendar" size={16} />{start || end ? `${start ? dateLabel(start) : 'Any date'} ? ${end ? dateLabel(end) : 'Any date'}` : 'All dates'}<Icon name="chevron" size={14} /></button><label className="bp-select"><select aria-label="Filter service" value={service} onChange={e => { setService(e.target.value); resetPage() }}><option value="">All services</option>{serviceNames.map(s => <option key={s}>{s}</option>)}</select></label><label className="bp-select"><select aria-label="Filter expert" value={expert} onChange={e => { setExpert(e.target.value); resetPage() }}><option value="">All experts</option>{expertNames.map(s => <option key={s}>{s}</option>)}</select></label><button className="bp-button" aria-expanded={moreFilters} onClick={() => setMoreFilters(!moreFilters)}><Icon name="bars" size={16} />More filters{(start || end || payment) && <span className="bp-filter-dot" />}</button></div>
      {moreFilters && <div className="bp-extra-filters"><label>From<input type="date" value={start} max={end || undefined} onChange={e => { setStart(e.target.value); resetPage() }} /></label><label>To<input type="date" value={end} min={start || undefined} onChange={e => { setEnd(e.target.value); resetPage() }} /></label><label>Payment<select value={payment} onChange={e => { setPayment(e.target.value); resetPage() }}><option value="">All payments</option><option>Paid</option><option>Unpaid</option></select></label><button className="bp-button" onClick={() => { setStart(''); setEnd(''); setPayment(''); setService(''); setExpert(''); setSearch(''); resetPage() }}>Clear filters</button></div>}
      {selected.length > 0 && <div className="bp-selection">{selected.length} bookings selected<button onClick={() => setSelected([])}>Clear selection</button></div>}
      {view === 'List' ? <><div className="bp-table-scroll" role="region" aria-label="Bookings table, scroll horizontally and vertically" tabIndex={0}><table><thead><tr><th><input type="checkbox" aria-label="Select all bookings on this page" checked={visible.length > 0 && visible.every(b => selected.includes(b.id))} onChange={e => setSelected(e.target.checked ? [...new Set([...selected, ...visible.map(b => b.id)])] : selected.filter(id => !visible.some(b => b.id === id)))} /></th>{['Booking ID', 'Customer', 'Service', 'Expert', 'Date & time', 'Amount', 'Payment', 'Status', 'Actions'].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>{visible.map(b => <tr key={b.id} className={selected.includes(b.id) ? 'bp-row-selected' : ''}><td><input type="checkbox" aria-label={`Select ${b.id}`} checked={selected.includes(b.id)} onChange={e => setSelected(e.target.checked ? [...selected, b.id] : selected.filter(id => id !== b.id))} /></td><td><button className="bp-id" onClick={() => showDetails(b)}>{b.id}</button></td><td><div className="bp-person"><span className="bp-avatar">{initials(b.customer)}</span><div><b>{b.customer}</b><small>{b.city}</small></div></div></td><td>{b.service}</td><td><div className="bp-person"><span className="bp-avatar bp-expert-avatar">{initials(b.expert)}</span><b>{b.expert}</b></div></td><td><div className="bp-date"><b>{dateLabel(b.date)}</b><small>{timeLabel(b.time)}</small></div></td><td className="bp-amount">{money(b.amount)}</td><td><Badge value={b.payment} /></td><td><Badge value={b.status} /></td><td><button className="bp-more" aria-label={`Manage booking ${b.id}`} aria-haspopup="dialog" onClick={() => showDetails(b)}>&#8942;</button></td></tr>)}{visible.length === 0 && <tr><td colSpan={10} className="bp-empty"><Icon name="search" size={30} /><strong>No bookings found</strong><span>Try another search or adjust your filters.</span></td></tr>}</tbody></table></div><div className="bp-pagination"><span aria-live="polite">Showing {filtered.length ? offset + 1 : 0}&ndash;{Math.min(offset + pageSize, filtered.length)} of {filtered.length} bookings</span><label>Rows per page<select aria-label="Rows per page" value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); resetPage() }}>{[8, 16, 24].map(size => <option key={size}>{size}</option>)}</select></label><nav aria-label="Booking pages"><button disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)}>Previous</button>{Array.from({ length: pageCount }, (_, i) => i + 1).map(n => <button key={n} aria-label={`Page ${n}`} aria-current={currentPage === n ? 'page' : undefined} onClick={() => setPage(n)}>{n}</button>)}<button disabled={currentPage === pageCount} onClick={() => setPage(currentPage + 1)}>Next</button></nav></div></> : <div className="bp-calendar">{[...new Set(filtered.map(b => b.date))].sort().map(date => <section key={date}><h2>{dateLabel(date)}</h2>{filtered.filter(b => b.date === date).map(b => <button key={b.id} onClick={() => showDetails(b)}><time>{timeLabel(b.time)}</time><strong>{b.customer}</strong><span>{b.service} · {b.expert}</span><Badge value={b.status} /></button>)}</section>)}{!filtered.length && <p>No appointments match your filters.</p>}</div>}
    </section>
    <p className="bp-notice" role="status">{notice || 'Changes are saved in this browser.'}</p>
    <dialog ref={dialog} className="bp-dialog" aria-labelledby="new-booking-title"><form key={editing?.id ?? 'new'} onSubmit={event => { event.preventDefault(); const data = new FormData(event.currentTarget); const customer = String(data.get('customer')).trim(); const amount = Number(data.get('amount')); if (!customer || !Number.isFinite(amount) || amount < 0) return; const booking: Booking = { id: editing?.id ?? `#HB${Math.max(...bookings.map(b => Number(b.id.slice(3)))) + 1}`, customer, city: String(data.get('city')).trim(), service: String(data.get('service')), expert: String(data.get('expert')), date: String(data.get('date')), time: String(data.get('time')), amount, payment: String(data.get('payment') ?? 'Unpaid'), status: String(data.get('status') ?? 'Pending') }; if (editing) { updateBooking(editing.id, booking, `${booking.id} updated successfully.`) } else { setBookings(previous => [booking, ...previous]); setNotice(`${booking.id} created for ${customer}.`) }; event.currentTarget.reset(); dialog.current?.close(); setTab('All bookings'); resetPage() }}><div className="bp-dialog-heading"><div><h2 id="new-booking-title">{editing ? 'Edit booking' : 'New booking'}</h2><p>{editing ? editing.id + ' ? Update appointment details' : 'A little beauty, booked.'}</p></div><button type="button" aria-label="Close new booking" onClick={() => dialog.current?.close()}>&times;</button></div><div className="bp-form-grid"><label>Customer name<input name="customer" defaultValue={editing?.customer ?? ''} required maxLength={80} placeholder="Full name" /></label><label>City<input name="city" defaultValue={editing?.city ?? ''} required maxLength={60} placeholder="City" /></label><label>Service<select name="service" defaultValue={editing?.service ?? serviceNames[0]}>{serviceNames.map(s => <option key={s}>{s}</option>)}</select></label><label>Beauty expert<select name="expert" defaultValue={editing?.expert ?? expertNames[0]}>{expertNames.map(s => <option key={s}>{s}</option>)}</select></label><label>Date<input type="date" name="date" defaultValue={editing?.date ?? today} required /></label><label>Time<input type="time" name="time" defaultValue={editing?.time ?? '10:00'} required /></label><label>Amount (INR)<input name="amount" defaultValue={editing?.amount ?? ''} type="number" min="0" step="1" required placeholder="2199" /></label>{editing && <><label>Booking status<select name="status" defaultValue={editing.status}>{['Pending', 'Confirmed', 'Completed', 'Cancelled'].map(status => <option key={status}>{status}</option>)}</select></label><label>Payment status<select name="payment" defaultValue={editing.payment}><option>Unpaid</option><option>Paid</option></select></label></>}</div><footer><button type="button" className="bp-button" onClick={() => dialog.current?.close()}>Cancel</button><button className="bp-button bp-primary">{editing ? 'Save changes' : 'Create booking'}</button></footer></form></dialog>
    <dialog ref={detailDialog} className="bp-dialog" aria-labelledby="booking-details-title">{detail && <><div className="bp-dialog-heading"><div><h2 id="booking-details-title">Booking {detail.id}</h2><p>{detail.customer}</p></div><button aria-label="Close booking details" onClick={() => detailDialog.current?.close()}>&times;</button></div><dl className="bp-details">{Object.entries({ Service: detail.service, Expert: detail.expert, City: detail.city, Date: dateLabel(detail.date), Time: timeLabel(detail.time), Amount: money(detail.amount), Payment: detail.payment, Status: detail.status }).map(([key, value]) => <div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl><div className="bp-booking-actions" aria-label="Booking actions"><button className="bp-button bp-primary" onClick={() => editBooking(detail)}>Edit / reschedule</button>{detail.status === 'Pending' && <button className="bp-button" onClick={() => updateBooking(detail.id, { status: 'Confirmed' }, detail.id + ' confirmed.')}>Confirm booking</button>}{['Pending', 'Confirmed'].includes(detail.status) && <button className="bp-button" onClick={() => updateBooking(detail.id, { status: 'Completed' }, detail.id + ' marked completed.')}>Mark completed</button>}{detail.payment === 'Unpaid' && <button className="bp-button" onClick={() => updateBooking(detail.id, { payment: 'Paid' }, detail.id + ' marked as paid.')}>Mark as paid</button>}{!['Cancelled', 'Completed'].includes(detail.status) && <button className="bp-button bp-danger" onClick={() => setConfirmCancel(true)}>Cancel booking</button>}</div>{confirmCancel && <div className="bp-cancel-confirm" role="group" aria-label="Confirm cancellation"><strong>Cancel {detail.id}?</strong><p>This will mark the appointment as cancelled. Payment records will stay unchanged.</p><div><button className="bp-button" onClick={() => setConfirmCancel(false)}>Keep booking</button><button className="bp-button bp-danger" onClick={() => { updateBooking(detail.id, { status: 'Cancelled' }, detail.id + ' cancelled.'); setConfirmCancel(false) }}>Yes, cancel booking</button></div></div>}</>}</dialog>
  </div>
}
