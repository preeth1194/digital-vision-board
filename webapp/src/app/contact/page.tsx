'use client'

import { useState } from 'react'
import { backendClientFetch } from '@/lib/backend/client'

export default function ContactPage() {
  const [form, setForm] = useState({ name: '', email: '', message: '' })
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')
  const [errorMsg, setErrorMsg] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('loading')
    setErrorMsg('')

    try {
      await backendClientFetch(
        '/contact',
        {
          method: 'POST',
          body: JSON.stringify({
            name: form.name,
            email: form.email,
            message: form.message,
          }),
        },
        { auth: false }
      )
      setStatus('success')
      setForm({ name: '', email: '', message: '' })
    } catch (err: unknown) {
      setStatus('error')
      setErrorMsg(err instanceof Error ? err.message : 'Something went wrong. Please try again.')
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-14">
      <h1 className="text-3xl sm:text-4xl font-extrabold text-forest-deep mb-2">Contact Us</h1>
      <p className="text-forest-deep/60 mb-10">
        Have a question, suggestion, or just want to say hi? We&apos;d love to hear from you.
      </p>

      {status === 'success' ? (
        <div className="bg-sprout/10 border border-sprout/30 rounded-2xl p-8 text-center">
          <div className="w-14 h-14 bg-sprout/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-7 h-7 text-sprout-dark" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-xl font-bold text-forest-deep mb-2">Message sent!</h2>
          <p className="text-forest-deep/60">Thanks for reaching out. We&apos;ll get back to you soon.</p>
          <button
            onClick={() => setStatus('idle')}
            className="mt-6 text-sm text-sprout-dark font-medium hover:underline"
          >
            Send another message
          </button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="name">
              Name
            </label>
            <input
              id="name"
              type="text"
              required
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              placeholder="Your name"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-3 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
            />
          </div>

          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              placeholder="you@example.com"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-3 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
            />
          </div>

          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="message">
              Message
            </label>
            <textarea
              id="message"
              required
              rows={5}
              value={form.message}
              onChange={(e) => setForm((f) => ({ ...f, message: e.target.value }))}
              placeholder="How can we help you?"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-3 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white resize-none"
            />
          </div>

          {status === 'error' && (
            <p className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-4 py-3">
              {errorMsg}
            </p>
          )}

          <button
            type="submit"
            disabled={status === 'loading'}
            className="w-full bg-forest-deep text-white font-bold py-3 rounded-xl hover:bg-sprout-dark transition-all disabled:opacity-60 disabled:cursor-not-allowed shadow"
          >
            {status === 'loading' ? 'Sending…' : 'Send Message'}
          </button>
        </form>
      )}
    </div>
  )
}
