import { api } from './client'

export async function openPrivateEvidence(bookingId: string, evidenceId: string) {
  // Reserve the tab during the click, before awaiting the authorized signed URL.
  const tab = window.open('about:blank', '_blank')
  if (!tab) throw new Error('Allow pop-ups to open this private photo link.')
  tab.opener = null
  try {
    const link = await api<{ url: string }>(
      `/admin/bookings/${encodeURIComponent(bookingId)}/product-evidence/${encodeURIComponent(evidenceId)}/private-link`,
    )
    if (tab.closed) return
    tab.location.replace(link.url)
  } catch (problem) {
    tab.close()
    throw problem
  }
}
