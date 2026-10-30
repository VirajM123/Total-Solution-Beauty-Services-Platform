import { useEffect, useRef, useState } from 'react'
import { api, backendEnabled, type Page } from './api/client'
import { session } from './api/client'
const refreshCurrentData = async () => { window.dispatchEvent(new Event('hi-beauty:data')) }
import { jump } from './AdminUI'

type Request = { _id: string; bookingNumber?: string; startsAt: string; totalPaise: number | string; addressSnapshot?: { city?: string }; items?: Array<{ name?: string; serviceName?: string }> }
type Worker = { _id: string; fullName?: string; eligible: boolean; reason: string }

export default function AllocationPage({ globalQuery, city }: { globalQuery: string; city: string }) {
  const approvalRequest = useRef({ fingerprint: '', key: '' })
  const [requests, setRequests] = useState<Request[]>([])
  const [selected, setSelected] = useState<Request | null>(null)
  const [workers, setWorkers] = useState<Worker[]>([])
  const [workerId, setWorkerId] = useState('')
  const [reason, setReason] = useState('')
  const [page, setPage] = useState(1)
  const [pages, setPages] = useState(1)
  const [revision, setRevision] = useState(0)
  const [loading, setLoading] = useState(false)
  const [checking, setChecking] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  useEffect(() => {
    if (!backendEnabled) return
    const timer = window.setInterval(() => setRevision(value => value + 1), 20000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    if (!backendEnabled) return
    const controller = new AbortController()
    setLoading(true)
    api<Page<Request>>(`/admin/allocations?page=${page}&limit=25`, { signal: controller.signal })
      .then(result => { setRequests(result.items); setPages(Math.max(1, result.pagination.pages)); setPage(value => Math.min(value, Math.max(1, result.pagination.pages))); setError('') })
      .catch(problem => { if (!controller.signal.aborted) setError(problem instanceof Error ? problem.message : 'Unable to load allocation requests.') })
      .finally(() => { if (!controller.signal.aborted) setLoading(false) })
    return () => controller.abort()
  }, [page, revision])

  useEffect(() => {
    if (!selected) return
    const controller = new AbortController()
    setChecking(true); setWorkers([]); setWorkerId(''); setError('')
    api<{ items: Worker[] }>(`/admin/allocations/${selected._id}/eligible-workers`, { signal: controller.signal })
      .then(result => setWorkers(result.items))
      .catch(problem => { if (!controller.signal.aborted) setError(problem instanceof Error ? problem.message : 'Unable to check workers.') })
      .finally(() => { if (!controller.signal.aborted) setChecking(false) })
    return () => controller.abort()
  }, [selected])

  async function approve(event: React.FormEvent) {
    event.preventDefault()
    if (!selected || saving || !workers.some(worker => worker._id === workerId && worker.eligible)) return
    const body = { workerId, reason: reason.trim() }
    const fingerprint = JSON.stringify([selected._id, body])
    if (approvalRequest.current.fingerprint !== fingerprint) approvalRequest.current = { fingerprint, key: crypto.randomUUID() }
    setSaving(true); setError(''); setNotice('')
    try {
      await session()
      await api(`/admin/bookings/${selected._id}/assign`, { method: 'POST', body, key: approvalRequest.current.key })
      setSelected(null); setReason(''); setRevision(value => value + 1)
      setNotice('Allocation approved. The assigned booking is available to the worker.')
      try { await refreshCurrentData() } catch { setNotice('Allocation approved. Refresh the bookings view to reload its data.') }
    } catch (problem) { setError(problem instanceof Error ? problem.message : 'Unable to approve allocation.') }
    finally { setSaving(false) }
  }

  const visible = requests.filter(request => (city === 'All cities' || request.addressSnapshot?.city === city) && `${request.bookingNumber || request._id} ${request.addressSnapshot?.city || ''}`.toLowerCase().includes(globalQuery.toLowerCase()))
  return <div className="final-module">
    <h1>Allocation</h1><p>Review booking requests, select an eligible worker, and approve the allocation.</p>
    {!backendEnabled && <p role="alert">Connect the admin backend to review and approve live allocation requests.</p>}
    {error && <p role="alert" className="final-error">{error}</p>}
    {notice && <p role="status">{notice}</p>}
    {backendEnabled && <>
      <button className="bp-button" disabled={loading || saving} onClick={() => setRevision(value => value + 1)}>Refresh requests</button>
      {loading ? <p role="status">Loading requests...</p> : <section className="final-panel">
        {!visible.length && <p>No pending requests on this page.</p>}
        {visible.map(request => <article key={request._id} className="final-detail">
          <h3>{request.bookingNumber || request._id}</h3>
          <p>{request.addressSnapshot?.city} · {new Date(request.startsAt).toLocaleString()} · ₹{(Number(request.totalPaise) / 100).toFixed(2)}</p>
          <button className="bp-button" disabled={saving} onClick={() => { setSelected(request); setNotice('') }}>Review allocation</button>{' '}
          <button className="final-text-button" onClick={() => jump('bookings', `booking=${request._id}`)}>Booking details</button>
        </article>)}
        <p>Page {page} of {pages}. Search and city filters apply to this page.</p>
        <button className="bp-button" disabled={page <= 1 || loading || saving} onClick={() => setPage(value => value - 1)}>Previous</button>{' '}
        <button className="bp-button" disabled={page >= pages || loading || saving} onClick={() => setPage(value => value + 1)}>Next</button>
      </section>}
      {selected && <form className="final-panel final-detail" onSubmit={approve}>
        <h2>Approve allocation · {selected.bookingNumber || selected._id}</h2>
        {checking ? <p role="status">Checking eligibility...</p> : <>
          <label>Worker <select required value={workerId} disabled={saving} onChange={event => setWorkerId(event.target.value)}>
            <option value="">Select an eligible worker</option>
            {workers.map(worker => <option key={worker._id} value={worker._id} disabled={!worker.eligible}>{worker.fullName || worker._id}{worker.eligible ? '' : ` — ${worker.reason}`}</option>)}
          </select></label>
          {!workers.some(worker => worker.eligible) && <p>No eligible workers. Check skills, service area, availability, leave, and compensation.</p>}
        </>}
        <label>Allocation reason <textarea required minLength={3} maxLength={1000} value={reason} disabled={saving} onChange={event => setReason(event.target.value)} /></label>
        <p>Approval assigns the worker directly. Eligibility is checked again when you submit.</p>
        <button className="bp-button" disabled={checking || saving || !workerId || reason.trim().length < 3}>{saving ? 'Approving...' : 'Approve & assign worker'}</button>{' '}
        <button type="button" className="bp-button" disabled={saving} onClick={() => setSelected(null)}>Close</button>
      </form>}
    </>}
  </div>
}
