import { useEffect, useState } from 'react'
import { api, backendEnabled, type ApiRecord, type Page } from './api/client'

export default function PublishNotifyPanel({ resource, onPublished }: { resource: 'banners' | 'packages'; onPublished?: () => Promise<void> }) {
  const [items, setItems] = useState<ApiRecord[]>([])
  const [selected, setSelected] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const [failed, setFailed] = useState(false)
  const [page, setPage] = useState(1)
  const [pages, setPages] = useState(1)
  useEffect(() => {
    if (!backendEnabled) return
    let active = true
    const controller = new AbortController()
    const load = () => {
      setLoading(true)
      void api<Page<ApiRecord>>(`/admin/${resource}?limit=100&page=${page}`, { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(12000)]) })
        .then(result => { if (active) { setItems(result.items.filter(item => !['archived', 'disabled'].includes(String(item.status)))); setPages(result.pagination.pages || 1) } })
        .catch(() => { if (active) { setFailed(true); setMessage('Unable to load saved items for notification.') } })
        .finally(() => { if (active) setLoading(false) })
    }
    load()
    window.addEventListener('hi-beauty:data', load)
    return () => { active = false; controller.abort(); window.removeEventListener('hi-beauty:data', load) }
  }, [resource, page])
  if (!backendEnabled) return null
  return <section className="final-callout" aria-label="Publish and notify app users">
    <h3>Publish &amp; notify app users</h3>
    <p>{resource === 'packages' ? 'Announce a saved package to customers.' : 'Announce a saved offer banner to its selected customer/worker audience.'} Scheduled offers wait until their start date. Each item can be announced once; ordinary edits send no alert.</p>
    <form onSubmit={async event => {
      event.preventDefault()
      if (!selected || busy) return
      setBusy(true); setFailed(false); setMessage('')
      try {
        const result = await api<{ status: string }>(`/admin/${resource}/${encodeURIComponent(selected)}/publish-notify`, { method: 'POST', body: {} })
        setMessage(result.status === 'completed' ? 'This item has already been announced.' : result.status === 'cancelled' ? 'This announcement was cancelled. Create a new item to announce it again.' : 'Published. The announcement is queued for eligible app users.')
        if (onPublished) await onPublished().catch(() => setMessage('Published and queued. Refresh the page to update the catalog view.'))
        else window.dispatchEvent(new Event('hi-beauty:data'))
      } catch (problem) { setFailed(true); setMessage(problem instanceof Error ? problem.message : 'Unable to publish and queue notification.') }
      finally { setBusy(false) }
    }}>
      <label className="final-field">Saved {resource === 'packages' ? 'package' : 'offer banner'}
        <select required disabled={busy || loading} value={selected} onChange={event => setSelected(event.target.value)}>
          <option value="">{loading ? 'Loading saved items…' : 'Choose a saved item'}</option>
          {items.map(item => <option key={String(item._id)} value={String(item._id)}>{String(item.name)} · {String(item.status)}</option>)}
        </select>
      </label>
      <button className="bp-button bp-primary" disabled={busy || loading || !selected}>{busy ? 'Queuing announcement…' : 'Publish & notify app users'}</button>
      {pages > 1 && <span> Page {page} of {pages} <button type="button" className="bp-button" disabled={busy || loading || page <= 1} onClick={() => { setSelected(''); setPage(value => value - 1) }}>Previous</button> <button type="button" className="bp-button" disabled={busy || loading || page >= pages} onClick={() => { setSelected(''); setPage(value => value + 1) }}>Next</button></span>}
    </form>
    {message && <p role={failed ? 'alert' : 'status'}>{message}</p>}
  </section>
}
