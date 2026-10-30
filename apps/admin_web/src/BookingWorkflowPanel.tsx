import { useEffect, useState } from 'react'
import { api } from './api/client'
import { openPrivateEvidence } from './api/privateEvidence'

type WorkflowEvidence = {
  _id: string
  fileName: string
  mimeType: string
  fileSizeBytes: number
  createdAt: string
  workerId: string
}

type BookingWorkflow = {
  assigningAdminUserId?: string
  assignedAt?: string
  assignmentReason?: string
  serviceFinishedAt?: string
  paymentStatus?: string
  paymentMethod?: string
  totalPaise?: number | string
  serviceStartedAt?: string
  serviceEndsAt?: string
  assignments: Array<{
    workerId: string
    status: string
    reason?: string
    assignedAt?: string
    assignedBy?: string
    changedAt?: string
    changedBy?: string
  }>
  evidence: WorkflowEvidence[]
  events: Array<{
    type: string
    createdAt: string
    decision?: string
    minutes?: number
    actorUserId?: string
  }>
  durationExtension?: {
    status: string
    minutes?: number
    requestedAt?: string
    expiresAt?: string
    decidedAt?: string
    decision?: string
    adminOtpVerifiedAt?: string
  } | null
  controlOtps?: Array<{
    _id: string
    purpose: string
    status: string
    createdAt: string
    expiresAt: string
  }>
}

const localDateTime = (value?: string) => value ? new Date(value).toLocaleString() : 'Not recorded'

export default function BookingWorkflowPanel({ bookingId }: { bookingId: string }) {
  const [workflow, setWorkflow] = useState<BookingWorkflow | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [recoveryQr, setRecoveryQr] = useState('')
  const [recoveringQr, setRecoveringQr] = useState(false)
  const [recoveryMessage, setRecoveryMessage] = useState('')
  const [openingEvidenceId, setOpeningEvidenceId] = useState('')
  const [issuedOtp, setIssuedOtp] = useState<{ purpose: string; otp: string; expiresAt: string } | null>(null)
  const [issuingPurpose, setIssuingPurpose] = useState('')
  const [checkedAt, setCheckedAt] = useState(() => Date.now())

  useEffect(() => {
    let active = true
    let busy = false
    const controller = new AbortController()
    setLoading(true)
    setWorkflow(null)
    setIssuedOtp(null)
    setError('')
    const refresh = () => {
      setCheckedAt(Date.now())
      if (busy) return
      busy = true
      void api<BookingWorkflow>(`/admin/bookings/${encodeURIComponent(bookingId)}/workflow`, { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(12000)]) })
        .then(result => { if (active) { setWorkflow(result); setError('') } })
        .catch(problem => { if (active) setError(problem instanceof Error ? problem.message : 'Unable to load workflow details.') })
        .finally(() => { busy = false; if (active) setLoading(false) })
    }
    refresh()
    const timer = window.setInterval(refresh, 15000)
    return () => { active = false; controller.abort(); window.clearInterval(timer) }
  }, [bookingId])

  async function recoverPaymentQr() {
    if (recoveringQr) return
    setRecoveringQr(true); setRecoveryMessage(''); setError('')
    try {
      const result = await api<{message: string}>('/admin/bookings/' + encodeURIComponent(bookingId) + '/payment-qr/recover', {method:'POST',body:{providerQrCodeId:recoveryQr.trim()}})
      setRecoveryMessage(result.message)
    } catch (problem) { setError(problem instanceof Error ? problem.message : 'QR recovery failed. The original reservation remains protected.') }
    finally { setRecoveringQr(false) }
  }

  async function openEvidence(evidenceId: string) {
    setOpeningEvidenceId(evidenceId)
    setError('')
    try {
      await openPrivateEvidence(bookingId, evidenceId)
    } catch (problem) {
      setError(problem instanceof Error ? problem.message : 'Unable to open private product evidence.')
    } finally {
      setOpeningEvidenceId('')
    }
  }

  async function issueControlOtp(purpose: 'duration_extension' | 'service_completion') {
    setIssuingPurpose(purpose)
    setError('')
    setIssuedOtp(null)
    try {
      const result = await api<{ purpose: string; otp: string; expiresAt: string }>(
        `/admin/bookings/${encodeURIComponent(bookingId)}/control-otp`,
        { method: 'POST', body: { purpose }, key: crypto.randomUUID() },
      )
      setIssuedOtp(result)
    } catch (problem) {
      setError(problem instanceof Error ? problem.message : 'Unable to issue the booking OTP.')
    } finally {
      setIssuingPurpose('')
    }
  }

  return <section className="final-panel final-detail" style={{ marginBottom: 16 }}>
    <h3>Assignment, evidence & service workflow</h3>
    {loading && <p>Loading server workflow…</p>}
    {error && <p role="alert" className="final-error">{error}</p>}
    {workflow && <>
      {workflow.serviceFinishedAt && <p role="status">{workflow.paymentStatus === 'paid' ? 'Payment received - Awaiting worker completion OTP' : 'Service finished - Awaiting verified payment'} - Final bill INR {(Number(workflow.totalPaise || 0) / 100).toFixed(2)}</p>}
      <dl className="final-details-grid">
        <div><dt>Assigned by admin</dt><dd>{workflow.assigningAdminUserId || 'Not recorded'}</dd></div>
        <div><dt>Assignment time</dt><dd>{localDateTime(workflow.assignedAt)}</dd></div>
        <div><dt>Assignment reason</dt><dd>{workflow.assignmentReason || 'Not recorded'}</dd></div>
        <div><dt>Service started</dt><dd>{localDateTime(workflow.serviceStartedAt)}</dd></div>
        <div><dt>Booked service end</dt><dd>{localDateTime(workflow.serviceEndsAt)}</dd></div>
      </dl>
      {workflow.serviceFinishedAt && workflow.paymentMethod === 'razorpay_qr' && workflow.paymentStatus !== 'paid' && <details>
        <summary>Recover an interrupted payment QR request</summary>
        <p>Find the original QR in the provider dashboard. This lookup verifies its booking and exact amount. It does not record payment or issue a second QR.</p>
        <label>Original Razorpay QR ID <input value={recoveryQr} onChange={event => setRecoveryQr(event.target.value)} placeholder="qr_…" /></label>
        <button type="button" className="bp-button" disabled={recoveringQr || !/^qr_[a-zA-Z0-9]+$/.test(recoveryQr.trim())} onClick={recoverPaymentQr}>{recoveringQr ? 'Checking provider…' : 'Recover original QR'}</button>
        {recoveryMessage && <p role="status">{recoveryMessage}</p>}
      </details>}
      <h4>Assignment history</h4>
      <ol className="final-timeline">
        {workflow.assignments.map((item, index) => <li key={`${item.workerId}-${index}`}>
          <b>{item.status} · worker {item.workerId}</b>
          <small>{localDateTime(item.assignedAt || item.changedAt)} · {item.reason || 'No reason recorded'} · admin {item.assignedBy || item.changedBy || 'unknown'}</small>
        </li>)}
      </ol>
      <h4>Private product evidence</h4>
      {workflow.evidence.length
        ? <ul>{workflow.evidence.map(item => <li key={item._id}>
          {item.fileName} · {item.mimeType} · {(item.fileSizeBytes / 1024).toFixed(0)} KB · {localDateTime(item.createdAt)} · worker {item.workerId}{' '}
          <button className="final-text-button" disabled={openingEvidenceId === item._id} onClick={() => openEvidence(item._id)}>
            {openingEvidenceId === item._id ? 'Opening…' : 'View private photo'}
          </button>
        </li>)}</ul>
        : <p>No product evidence uploaded.</p>}
      <h4>Duration extension</h4>
      {workflow.durationExtension
        ? <p>{workflow.durationExtension.status} · {workflow.durationExtension.minutes ?? 15} minutes · requested {localDateTime(workflow.durationExtension.requestedAt)} · decision {workflow.durationExtension.decision || 'pending'} · deadline {localDateTime(workflow.durationExtension.expiresAt)} · decided {localDateTime(workflow.durationExtension.decidedAt)}</p>
        : <p>No duration extension request.</p>}
      {workflow.durationExtension && ['pending', 'approved'].includes(workflow.durationExtension.status) && !workflow.durationExtension.adminOtpVerifiedAt && !workflow.serviceFinishedAt &&
        <button className="bp-button" disabled={Boolean(issuingPurpose)} onClick={() => issueControlOtp('duration_extension')}>
          {issuingPurpose === 'duration_extension' ? 'Generating OTP…' : 'Generate continuation OTP'}
        </button>}
      {workflow.serviceFinishedAt && workflow.paymentStatus === 'paid' &&
        <button className="bp-button" disabled={Boolean(issuingPurpose)} onClick={() => issueControlOtp('service_completion')}>
          {issuingPurpose === 'service_completion' ? 'Generating OTP…' : 'Generate service-completion OTP'}
        </button>}
      {issuedOtp && new Date(issuedOtp.expiresAt).getTime() > checkedAt && <div role="status" className="final-detail" style={{ marginTop: 12, padding: 14, background: '#fff2f8' }}>
        <strong>{issuedOtp.purpose === 'duration_extension' ? 'Share this continuation OTP with the worker' : 'Share this completion OTP with the worker'}</strong>
        <p style={{ fontSize: 24, letterSpacing: 6, fontWeight: 800, margin: '8px 0' }}>{issuedOtp.otp}</p>
        <small>Expires {localDateTime(issuedOtp.expiresAt)} · single use · never send it to the customer.</small>
      </div>}
      {workflow.controlOtps?.length ? <ul>
        {workflow.controlOtps.map(item => <li key={item._id}>{item.purpose.replaceAll('_', ' ')} · {item.status} · issued {localDateTime(item.createdAt)} · expires {localDateTime(item.expiresAt)}</li>)}
      </ul> : null}
      <h4>Extension decision history</h4>
      <ol className="final-timeline">
        {workflow.events.filter(event => event.type.startsWith('duration_extension_')).map((event, index) => <li key={`${event.type}-${index}`}>
          <b>{event.type.replaceAll('_', ' ')}</b>
          <small>{localDateTime(event.createdAt)} · {event.decision || 'requested'} · {event.minutes ? `${event.minutes} minutes · ` : ''}actor {event.actorUserId || 'system'}</small>
        </li>)}
      </ol>
    </>}
  </section>
}
