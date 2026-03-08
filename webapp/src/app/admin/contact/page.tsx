import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
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
  subject: string
  message: string
  kind: 'contact' | 'issue'
  status: 'open' | 'in_progress' | 'resolved'
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

  async function updateStatusAction(formData: FormData) {
    'use server'

    const id = Number(formData.get('id'))
    const status = String(formData.get('status') ?? '').trim()
    if (!Number.isFinite(id) || id <= 0) return
    if (!['open', 'in_progress', 'resolved'].includes(status)) return

    await backendServerFetch(`/contact/messages/${id}/status`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status }),
    })
    revalidatePath('/admin/contact')
  }

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
                  {msg.subject ? <p className="text-xs text-forest-deep/60 mt-1">Subject: {msg.subject}</p> : null}
                </div>
                <div className="text-right">
                  <time className="text-xs text-forest-deep/50 whitespace-nowrap">{formatDate(msg.createdAt)}</time>
                  <p className="text-xs text-forest-deep/50 mt-1 capitalize">{msg.kind.replace('_', ' ')}</p>
                </div>
              </div>
              <p className="text-sm text-forest-deep/80 leading-relaxed whitespace-pre-wrap">{msg.message}</p>
              {msg.kind === 'issue' ? (
                <form action={updateStatusAction} className="mt-4 flex items-center gap-2">
                  <input type="hidden" name="id" value={msg.id} />
                  <select
                    name="status"
                    defaultValue={msg.status}
                    className="text-sm rounded-lg border border-forest-deep/20 px-3 py-1.5 bg-white text-forest-deep"
                  >
                    <option value="open">Open</option>
                    <option value="in_progress">In Progress</option>
                    <option value="resolved">Resolved</option>
                  </select>
                  <button
                    type="submit"
                    className="text-sm bg-forest-deep text-white font-semibold px-3 py-1.5 rounded-lg hover:bg-forest-deep/90 transition-colors"
                  >
                    Update
                  </button>
                </form>
              ) : null}
            </article>
          ))}
        </div>
      )}
    </div>
  )
}
