import AdminAccessPage from './AdminAccessPage'
import CouponRulesPage from './CouponRulesPage'
import { useEffect, useState } from 'react'
import { Icon, type IconName } from './Icon'
import OverviewPage from './OverviewPage'
import OperationsBookingsPage from './OperationsBookingsPage'
import CustomersPage from './CustomersPage'
import BeautyExpertsPage from './BeautyExpertsPage'
import WorkerOperationsPage from './WorkerOperationsPage'
import ServicesPage from './ServicesPage'
import PackagesPage from './PackagesPage'
import PaymentsPage from './PaymentsPage'
import SettlementsPage from './SettlementsPage'
import OffersPage from './OffersPage'
import SupportPage from './SupportPage'
import ReportsPage from './ReportsPage'
import SettingsPage from './SettingsPage'
import { ModuleTabs, jump } from './AdminUI'
import { loadBookings, loadSettings, loadTickets, readLocal, saveLocal } from './adminData'
import { loadExperts } from './expertsData'
import { loadPaymentStore } from './paymentsData'
import './App.css'
import './FinalAdmin.css'
import './UIImprovements.css'

const navigation: { label: string; route: string; icon: IconName }[] = [
  { label: 'Overview', route: 'overview', icon: 'home' },
  { label: 'Bookings', route: 'bookings', icon: 'calendar' },
  { label: 'Customers', route: 'customers', icon: 'users' },
  { label: 'Beauty Experts', route: 'beauty-experts', icon: 'user' },
  { label: 'Services', route: 'services', icon: 'grid' },
  { label: 'Payments', route: 'payments', icon: 'card' },
  { label: 'Offers', route: 'offers', icon: 'tag' },
  { label: 'Support', route: 'support', icon: 'headphones' },
  { label: 'Reports', route: 'reports', icon: 'chart' },
  { label: 'Settings', route: 'settings', icon: 'settings' },
]
function Workspace({ route, query, city }: { route: string; query: string; city: string }) {
  const [section, setSection] = useState(new URLSearchParams(window.location.hash.split('?')[1]).get('view') === 'eligibility' ? 'Skills & service areas' : '')
  if (route === 'overview') return <OverviewPage globalQuery={query} city={city} />
  if (route === 'bookings') return <OperationsBookingsPage globalQuery={query} city={city} />
  if (route === 'customers') return <CustomersPage globalQuery={query} city={city} />
  if (route === 'beauty-experts') return <div className="final-module"><ModuleTabs values={['Directory & approvals', 'Skills & service areas']} value={section || 'Directory & approvals'} onChange={setSection} />{section === 'Skills & service areas' ? <WorkerOperationsPage globalQuery={query} city={city} /> : <BeautyExpertsPage globalQuery={query} city={city} />}</div>
  if (route === 'services') return <div className="final-module"><ModuleTabs values={['Categories & sub-services', 'Packages']} value={section || 'Categories & sub-services'} onChange={setSection} />{section === 'Packages' ? <PackagesPage globalQuery={query} /> : <ServicesPage globalQuery={query} />}</div>
  if (route === 'payments') return <div className="final-module"><ModuleTabs values={['Collections & refunds', 'Worker settlements']} value={section || 'Collections & refunds'} onChange={setSection} />{section === 'Worker settlements' ? <SettlementsPage globalQuery={query} city={city} /> : <PaymentsPage globalQuery={query} city={city} />}</div>
  if (route === 'offers') return <div className="final-module"><ModuleTabs values={['Home banners & previews', 'Coupons & eligibility']} value={section || 'Home banners & previews'} onChange={setSection} />{section === 'Coupons & eligibility' ? <CouponRulesPage globalQuery={query} /> : <OffersPage globalQuery={query} />}</div>
  if (route === 'support') return <SupportPage globalQuery={query} />
  if (route === 'reports') return <ReportsPage globalQuery={query} city={city} />
  return <SettingsPage />
}
export default function App() {
  const [hash, setHash] = useState(window.location.hash), [query, setQuery] = useState(''), [city, setCity] = useState('All cities'), [menuOpen, setMenuOpen] = useState(false), [logoMissing, setLogoMissing] = useState(false), [notificationOpen, setNotificationOpen] = useState(false), [profileOpen, setProfileOpen] = useState(false), [revision, setRevision] = useState(0), [read, setRead] = useState(() => readLocal<string[]>('hi-beauty-read-alerts-v1', []))
  const route = hash.startsWith('#admin-access') ? 'admin-access' : navigation.find(n => n.route === hash.slice(1).split('?')[0])?.route ?? 'overview'
  useEffect(() => { const change = () => { setHash(window.location.hash); setMenuOpen(false); setNotificationOpen(false); setProfileOpen(false); setQuery('') }; const refresh = () => setRevision(value => value + 1); window.addEventListener('hashchange', change); window.addEventListener('hi-beauty:data', refresh); return () => { window.removeEventListener('hashchange', change); window.removeEventListener('hi-beauty:data', refresh) } }, [])
  useEffect(() => { document.title = `Hi Beauty - ${navigation.find(n => n.route === route)?.label ?? 'Admin'}` }, [route])
  const books = loadBookings(), pendingWorkers = loadExperts().filter(e => e.status === 'Pending review').length, unassigned = books.filter(b => !['Completed', 'Cancelled'].includes(b.status) && ['Searching', 'Rejected'].includes(b.assignment)).length, refunds = loadPaymentStore().refunds.filter(r => r.status === 'Requested').length, tickets = loadTickets().filter(t => t.status !== 'Resolved').length
  const alerts = [{ id: `registrations-${pendingWorkers}`, label: `${pendingWorkers} worker registrations need review`, route: 'beauty-experts', count: pendingWorkers, params: '' }, { id: `assignment-${unassigned}`, label: `${unassigned} bookings need assignment`, route: 'bookings', count: unassigned, params: 'view=assignment' }, { id: `refunds-${refunds}`, label: `${refunds} refund requests need review`, route: 'payments', count: refunds, params: '' }, { id: `support-${tickets}`, label: `${tickets} open support cases`, route: 'support', count: tickets, params: '' }].filter(a => a.count > 0)
  const unread = alerts.filter(a => !read.includes(a.id)).length
  if (route === 'admin-access') return <AdminAccessPage />
  return <div className="dashboard final-admin" data-revision={revision}>
    {menuOpen && <button className="final-nav-backdrop" aria-label="Close navigation" onClick={() => setMenuOpen(false)} />}
    <aside className={`sidebar${menuOpen ? ' sidebar-open' : ''}`}><a className="brand" href="#overview">{logoMissing ? <strong className="brand-placeholder">Hi Beauty</strong> : <img className="brand-logo" src="/hi-beauty-logo-transparent.png" alt="Hi Beauty" onError={() => setLogoMissing(true)} />}</a><span className="final-nav-label">BUSINESS WORKSPACE</span><nav className="side-nav" aria-label="Main navigation">{navigation.map(item => <button key={item.route} title={item.label} className={`nav-item${route === item.route ? ' active' : ''}`} aria-current={route === item.route ? 'page' : undefined} onClick={() => { jump(item.route); setMenuOpen(false) }}><Icon name={item.icon} size={19} /><span>{item.label}</span>{item.route === 'beauty-experts' && pendingWorkers > 0 && <small className="final-nav-count">{pendingWorkers}</small>}</button>)}</nav><div className="sidebar-bottom"><span className="online-dot" /><span>Local design preview<small>Shared backend not connected</small></span></div></aside>
    <main className="main"><header className="topbar"><button className="mobile-menu icon-button" aria-label="Toggle navigation" aria-expanded={menuOpen} onClick={() => setMenuOpen(!menuOpen)}><Icon name="menu" /></button>{!['bookings','customers','beauty-experts','services','payments','offers','settings'].includes(route) ? <label className="search-box"><Icon name="search" size={17} /><input aria-label="Search current section" value={query} onChange={event => setQuery(event.target.value)} placeholder="Search this section..." />{query && <button className="clear-search" onClick={() => setQuery('')} aria-label="Clear search">×</button>}</label> : <span className="ui-workspace-title">{navigation.find(n => n.route === route)?.label}</span>}<div className="topbar-actions"><label className="select-control top-city"><Icon name="pin" size={15} /><select value={city} onChange={event => setCity(event.target.value)} aria-label="Select city"><option>All cities</option>{loadSettings().cities.map(c => <option key={c}>{c}</option>)}</select><Icon name="chevron" size={14} /></label><div className="final-popover-anchor"><button className="icon-button notification" aria-label="Notifications" aria-expanded={notificationOpen} onClick={() => { setNotificationOpen(!notificationOpen); setProfileOpen(false) }}><Icon name="bell" size={19} />{unread > 0 && <span className="notification-count">{unread}</span>}</button>{notificationOpen && <section className="final-popover" aria-label="Notifications"><div><h2>Needs your attention</h2><button className="final-text-button" onClick={() => { const next = alerts.map(a => a.id); setRead(next); try { saveLocal('hi-beauty-read-alerts-v1', next) } catch { /* Reading remains available for this session. */ } }}>Mark read</button></div>{alerts.map(a => <button className="final-alert" key={a.id} onClick={() => jump(a.route, a.params)}><span className={read.includes(a.id) ? '' : 'unread'} />{a.label}<b>›</b></button>)}{!alerts.length && <p className="final-hint">No pending actions.</p>}</section>}</div><div className="final-popover-anchor"><button className="profile" aria-label="Administrator account" aria-expanded={profileOpen} onClick={() => { setProfileOpen(!profileOpen); setNotificationOpen(false) }}><span className="avatar">PS</span><span className="profile-copy"><strong>Priya Sharma</strong><small>Administrator</small></span><Icon name="chevron" size={14} /></button>{profileOpen && <section className="final-popover final-account"><h2>Priya Sharma</h2><p>Hi Beauty administrator - Local preview</p><button className="bp-button" onClick={() => jump('settings')}>Business settings</button><button className="bp-button" onClick={() => jump('admin-access')}>Preview sign-in screen</button><p className="final-hint">Live admin authentication is not connected.</p></section>}</div></div></header><div className="app-content"><Workspace key={hash} route={route} query={query} city={city} /></div></main>
  </div>
}

