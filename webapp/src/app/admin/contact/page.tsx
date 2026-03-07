import { redirect } from 'next/navigation'
import type { Metadata } from 'next'
import Link from 'next/link'
import { backendServerFetch } from '@/lib/backend/server'

export const metadata: Metadata = {
  title: 'Admin - Contact Inbox',
}

type MeResponse = { ok: boolean; isAdmin?: boolean }
type ContactMessage = {
  id: number
  name: string
  email: string
  message: string
  createdAt: string | null
}
type ContactMessagesResponse = { ok: boolean; messages?: ContactMessage[] }

function formatDate(value: string | null): string {
  if (!value) return 'Unknown date'
  const dt = new Date(value)
  if (Number.isNaN(dt.getTime())) return 'Unknown date'
  return dt.toLocaleString()
}

export default async function AdminContactPage() {
  const me = await backendServerFetch<MeResponse>('/auth/me', {}, { redirectOnUnauthorized: true })
  if (!me.isAdmin) {
    redirect('/')
  }

  const result = await backendServerFetch<ContactMessagesResponse>('/contact/messages?limit=200')
  const messages = result.messages ?? []

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-12">
      <div className="flex items-center gap-3 mb-8">
        <div className="w-9 h-9 bg-forest-deep rounded-xl flex items-center justify-center">
          <svg className="w-5 h-5 text-sprout" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25H4.5a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5H4.5A2.25 2.25 0 002.25 6.75m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.909A2.25 2.25 0 012.25 6.993V6.75"
            />
          </svg>
        </div>
        <div>
          <h1 className="text-2xl font-extrabold text-forest-deep">Admin - Contact Inbox</h1>
          <p className="text-forest-deep/50 text-sm">{messages.length} messages</p>
        </div>
      </div>
      <div className="mb-6">
        <Link
          href="/admin/presets"
          className="inline-flex items-center text-sm text-sprout-dark font-semibold hover:underline"
        >
          Open Preset Queue
        </Link>
      </div>

      {messages.length === 0 ? (
        <div className="bg-white rounded-2xl border border-forest-deep/10 p-8 text-center">
          <p className="text-forest-deep/40 text-sm">No contact messages yet.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {messages.map((msg) => (
            <article key={msg.id} className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-3 mb-2">
                <div>
                  <h2 className="font-bold text-forest-deep text-base">{msg.name}</h2>
                  <a href={`mailto:${msg.email}`} className="text-sm text-sprout-dark hover:underline break-all">
                    {msg.email}
                  </a>
                </div>
                <time className="text-xs text-forest-deep/50 whitespace-nowrap">{formatDate(msg.createdAt)}</time>
              </div>
              <p className="text-sm text-forest-deep/80 leading-relaxed whitespace-pre-wrap">{msg.message}</p>
            </article>
          ))}
        </div>
      )}
    </div>
  )
}
