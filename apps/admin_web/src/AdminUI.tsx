import type { ReactNode } from 'react'
import { Icon } from './Icon'

export function PageHeading({ title, description, children }: { title: string; description: string; children?: ReactNode }) { return <section className="bp-heading"><div><h1>{title}</h1><p>{description}</p></div><div className="bp-heading-actions">{children}</div></section> }
export function ModuleTabs({ values, value, onChange }: { values: string[]; value: string; onChange: (value: string) => void }) { return <div className="final-module-tabs" aria-label="Section navigation">{values.map(tab => <button key={tab} aria-pressed={value === tab} onClick={() => onChange(tab)}>{tab}</button>)}</div> }
export function StatusPill({ value }: { value: string }) { const success = ['Paid', 'Active', 'Accepted', 'Completed', 'Published', 'Resolved', 'Online'].includes(value), danger = ['Cancelled', 'Rejected', 'Suspended', 'Failed', 'Refunded', 'Restricted'].includes(value); return <span className={`final-pill ${success ? 'success' : danger ? 'danger' : ['Pending', 'Searching', 'Offered', 'Reassigned', 'Open'].includes(value) ? 'warning' : 'neutral'}`}><i />{value}</span> }
export function EmptyState({ title = 'No records found', children }: { title?: string; children?: ReactNode }) { return <div className="final-empty"><Icon name="search" size={28} /><strong>{title}</strong><span>{children ?? 'Adjust your filters to find what you need.'}</span></div> }
export function ExportButton({ onClick }: { onClick: () => void }) { return <button className="bp-button bp-export" onClick={onClick}><Icon name="download" size={16} />Export</button> }
export function jump(route: string, params = '') { window.location.hash = route + (params ? '?' + params : '') }
