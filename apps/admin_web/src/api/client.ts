export const backendEnabled = import.meta.env.VITE_ADMIN_API_ENABLED === 'true'
const base = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5001/api/v1').replace(/\/$/, '')
export type AdminIdentity = { id: string; name: string; email: string; role: string; permissions: string[] }
export type Session = { admin: AdminIdentity; csrfToken: string }
export type ApiRecord = Record<string, unknown>
export type Page<T> = { items: T[]; pagination: { page: number; limit: number; total: number; pages: number } }
export type AdminCreationRole = { _id: string; roleCode: string; roleName: string; permissions: string[] }
let csrf = ''
export async function api<T>(path: string, options: { method?: string; body?: unknown; key?: string; signal?: AbortSignal } = {}): Promise<T> {
  const method = options.method || 'GET'
  const headers: Record<string, string> = {}
  if (options.body !== undefined) headers['Content-Type'] = 'application/json'
  if (!['GET', 'HEAD'].includes(method)) {
    if (csrf) headers['X-CSRF-Token'] = csrf
    headers['X-Idempotency-Key'] = options.key || crypto.randomUUID()
  }
  let response: Response
  try {
    response = await fetch(base + path, { method, credentials: 'include', headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body), signal: options.signal || AbortSignal.timeout(15000) })
  } catch (problem) {
    if (problem instanceof TypeError) {
      throw new Error(`${problem.message} (${base}). Confirm the backend is running and the API URL is correct.`)
    }
    throw problem
  }
  const result = await response.json().catch(() => null)
  if (!response.ok || result?.success !== true) {
    if (response.status === 401 && (!result?.error?.code || result.error.code === 'UNAUTHENTICATED')) { csrf = ''; if (typeof window !== 'undefined') window.dispatchEvent(new Event('hi-beauty:session-expired')) }
    const details = Array.isArray(result?.error?.details) ? result.error.details.map((d: { field?: string; message: string }) => `${d.field || 'Field'}: ${d.message}`).join('; ') : ''
    throw new Error([result?.error?.message || `Backend request failed (${response.status}).`, details].filter(Boolean).join(' '))
  }
  return result.data as T
}
export async function session() { const value = await api<Session>('/admin/auth/session'); csrf = value.csrfToken; return value }
export async function login(identifier: string, password: string) { const value = await api<Session>('/admin/auth/login', { method: 'POST', body: { email: identifier, password } }); csrf = value.csrfToken; return value }
export async function registerInitialAdmin(input: { fullName: string; email: string; mobileNumber: string; password: string; confirmPassword: string; enrollmentKey: string; authorized: true }) {
  const value = await api<Session>('/admin/auth/register', { method: 'POST', body: input })
  csrf = value.csrfToken
  return value
}
export async function requestAdminAccess(input: { fullName: string; email: string; mobileNumber: string; reason: string }) {
  return api<{ received: boolean; message: string }>('/admin/auth/access-requests', { method: 'POST', body: input })
}
export async function adminCreationRoles() {
  return api<{ items: AdminCreationRole[] }>('/admin/admins/available-roles')
}
export async function createAdminAccount(input: { fullName: string; email: string; mobileNumber: string; roleId: string; password: string; confirmPassword: string; authorized: true }) {
  return api<{ _id: string; fullName: string; email: string; roleCode: string; roleName: string; status: string }>('/admin/admins', { method: 'POST', body: input })
}
export async function logout() { await api('/admin/auth/logout', { method: 'POST', body: {} }); csrf = ''; window.location.reload() }
export async function uploadMedia(file: File, visibility: 'public' | 'private' = 'public'): Promise<{ _id: string; publicUrl?: string }> {
  if (!file.size || file.size > 5 * 1024 * 1024) throw new Error('Choose a file up to 5 MB.')
  const response = await fetch(base + '/admin/media-v2/uploads', {
    method: 'POST', credentials: 'include', signal: AbortSignal.timeout(60000),
    headers: { 'Content-Type': file.type, 'X-CSRF-Token': csrf, 'X-Idempotency-Key': crypto.randomUUID(), 'X-Media-Visibility': visibility, 'X-File-Name': encodeURIComponent(file.name) },
    body: file,
  })
  const result = await response.json().catch(() => null)
  if (!response.ok || result?.success !== true) throw new Error(result?.error?.message || `Upload failed (${response.status}).`)
  if (!result.data?._id || (visibility === 'public' && !result.data.publicUrl)) throw new Error('Upload returned incomplete persistent media metadata.')
  return result.data
}
export async function allRecords(path: string): Promise<ApiRecord[]> {
  const items: ApiRecord[] = []
  for (let page = 1; page <= 100; page++) {
    const result = await api<Page<ApiRecord>>(path + (path.includes('?') ? '&' : '?') + `limit=100&page=${page}`)
    items.push(...result.items)
    if (page >= result.pagination.pages) return items
  }
  throw new Error('This view exceeds 10,000 records. Narrow the server query before loading it.')
}
