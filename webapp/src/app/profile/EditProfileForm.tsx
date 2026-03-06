'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { backendClientFetch } from '@/lib/backend/client'

interface Props {
  initialDisplayName: string
}

export default function EditProfileForm({ initialDisplayName }: Props) {
  const router = useRouter()
  const [displayName, setDisplayName] = useState(initialDisplayName)
  const [status, setStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle')
  const [error, setError] = useState('')

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setStatus('saving')
    setError('')

    try {
      await backendClientFetch('/user/settings', {
        method: 'PUT',
        body: JSON.stringify({ display_name: displayName }),
      })
      setStatus('saved')
      router.refresh()
      setTimeout(() => setStatus('idle'), 2000)
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Update failed')
      setStatus('error')
    }
  }

  return (
    <form onSubmit={handleSave} className="space-y-4">
      <div>
        <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="display_name">
          Display Name
        </label>
        <input
          id="display_name"
          type="text"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          placeholder="Your display name"
          className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout text-sm bg-mist"
        />
      </div>

      {error && <p className="text-red-600 text-sm">{error}</p>}

      <button
        type="submit"
        disabled={status === 'saving'}
        className="bg-forest-deep text-white text-sm font-bold px-5 py-2.5 rounded-xl hover:bg-sprout-dark transition-all disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {status === 'saving' ? 'Saving…' : status === 'saved' ? '✓ Saved!' : 'Save Changes'}
      </button>
    </form>
  )
}
