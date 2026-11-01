import { jump } from './AdminUI'
export default function AdminAccessPage() {
  return <main className="final-access">
    <section className="final-access-story" aria-label="Hi Beauty Admin workspace">
      <a href="#overview"><img src="/hi-beauty-logo-transparent.png" alt="Hi Beauty" className="ui-access-logo" /></a>
      <div>
        <h1>Beautiful service.<br />Seamless operations.</h1>
      </div>
      <small>— Hi Beauty Admin</small>
    </section>
    <section className="final-access-form">
      <img src="/hi-beauty-logo-transparent.png" alt="Hi Beauty" className="final-access-logo" />
      <span className="final-eyebrow">ADMIN ACCESS · DESIGN PREVIEW</span>
      <h2>Welcome back</h2>
      <p>Sign-in is unavailable in this local preview. Open the preview below to explore the workspace.</p>
      <label className="final-field">Work email<input type="email" placeholder="admin@example.com" disabled /></label>
      <label className="final-field">Password<input type="password" placeholder="Enter your password" disabled /></label>
      <button className="bp-button bp-primary" disabled>Sign in</button>
      <div className="final-callout">Authentication is not connected. This screen does not accept credentials or protect the local preview. Connect server authentication and role checks before production.</div>
      <button className="bp-button" onClick={() => jump('overview')}>Open local design preview →</button>
      <small>Customer and worker OTP sign-in belongs in their respective apps.</small>
    </section>
  </main>
}
