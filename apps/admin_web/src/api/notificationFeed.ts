import { useEffect, useState } from 'react'
import { api, backendEnabled, session } from './client'

export type AdminNotification = { _id: string; type: string; entityId: string; title: string; body: string; isRead: boolean; createdAt: string }
type Cursor = { at: string; id: string }
type Feed = { items: AdminNotification[]; cursor: Cursor | null }

export function notificationTarget(item: AdminNotification) {
  if (item.type === 'booking.created') return { route: 'allocation', params: '' }
  if (item.type.startsWith('worker.')) return { route: 'beauty-experts', params: '' }
  if (/payment|cash\./.test(item.type)) return { route: 'payments', params: '' }
  if (item.type.startsWith('support.')) return { route: 'support', params: '' }
  return { route: 'bookings', params: `booking=${encodeURIComponent(item.entityId)}` }
}

export function useNotificationFeed() {
  const [items, setItems] = useState<AdminNotification[]>([])
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  useEffect(() => {
    if (!notice) return
    const timer = window.setTimeout(() => setNotice(''), 8000)
    return () => window.clearTimeout(timer)
  }, [notice])
  useEffect(() => {
    if (!backendEnabled) return
    let active = true, busy = false, initialized = false
    let cursor: Cursor | null = null
    const controller = new AbortController()
    const poll = async () => {
      if (!active || busy || document.visibilityState === 'hidden') return
      busy = true
      try {
        // Also establishes CSRF for the older admin shell when an existing admin cookie is used.
        if (!initialized) await session()
        if (!active) return
        const query = cursor ? `?after=${encodeURIComponent(cursor.at)}&afterId=${cursor.id}` : ''
        const result = await api<Feed>(`/admin/notification-feed${query}`, { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(12000)]) })
        if (!active) return
        if (initialized && result.items.length) {
          const newest = result.items.at(-1)!
          const message = result.items.length === 1 ? `${newest.title}: ${newest.body}` : `${result.items.length} new updates. ${newest.title}: ${newest.body}`
          window.dispatchEvent(new CustomEvent('hi-beauty:toast', { detail: { message, tone: 'success' } }))
          setNotice(message)
          window.dispatchEvent(new Event('hi-beauty:data'))
        }
        setItems(previous => [...new Map([...previous, ...result.items].map(item => [item._id, item])).values()]
          .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || b._id.localeCompare(a._id)).slice(0, 100))
        cursor = result.cursor || cursor
        initialized = true
        setError('')
      } catch { if (active) setError('Live alerts are disconnected. Retrying automatically.') }
      finally { busy = false }
    }
    void poll()
    const timer = window.setInterval(() => { void poll() }, 5000)
    const refresh = () => { void poll() }
    window.addEventListener('online', refresh)
    window.addEventListener('focus', refresh)
    document.addEventListener('visibilitychange', refresh)
    return () => { active = false; controller.abort(); window.clearInterval(timer); window.removeEventListener('online', refresh); window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh) }
  }, [])
  const markRead = async (ids: string[]) => {
    try {
      await Promise.all(ids.map(id => api(`/admin/notification-feed/${id}/read`, { method: 'PATCH', body: {} })))
      setItems(previous => previous.map(item => ids.includes(item._id) ? { ...item, isRead: true } : item))
    } catch { setError('Unable to save read status. Please retry.') }
  }
  return { items, error, notice, markRead }
}
