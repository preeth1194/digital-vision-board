'use client'

import { useState, useTransition } from 'react'
import { approvePreset, rejectPreset } from './actions'

interface Props {
  presetId: string
}

export default function AdminActions({ presetId }: Props) {
  const [isPending, startTransition] = useTransition()
  const [rejectNotes, setRejectNotes] = useState('')
  const [showRejectForm, setShowRejectForm] = useState(false)
  const [error, setError] = useState('')

  const handleApprove = () => {
    setError('')
    startTransition(async () => {
      try {
        await approvePreset(presetId)
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Approval failed')
      }
    })
  }

  const handleReject = () => {
    setError('')
    startTransition(async () => {
      try {
        await rejectPreset(presetId, rejectNotes || null)
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Rejection failed')
      }
    })
  }

  return (
    <div className="space-y-3">
      {!showRejectForm ? (
        <div className="flex gap-2">
          <button
            onClick={handleApprove}
            disabled={isPending}
            className="flex items-center gap-1.5 bg-sprout text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-sprout-light transition-all disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {isPending ? (
              <span>Processing…</span>
            ) : (
              <>
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Approve
              </>
            )}
          </button>
          <button
            onClick={() => setShowRejectForm(true)}
            disabled={isPending}
            className="flex items-center gap-1.5 border border-red-300 text-red-600 text-sm font-semibold px-4 py-2 rounded-lg hover:bg-red-50 transition-all disabled:opacity-60"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
            Reject
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          <textarea
            value={rejectNotes}
            onChange={(e) => setRejectNotes(e.target.value)}
            placeholder="Reason for rejection (optional, shown to submitter)"
            rows={2}
            className="w-full border border-red-200 rounded-lg px-3 py-2 text-sm text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-red-300 bg-white resize-none"
          />
          <div className="flex gap-2">
            <button
              onClick={handleReject}
              disabled={isPending}
              className="bg-red-600 text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-red-700 transition-all disabled:opacity-60"
            >
              {isPending ? 'Rejecting…' : 'Confirm Reject'}
            </button>
            <button
              onClick={() => { setShowRejectForm(false); setRejectNotes('') }}
              disabled={isPending}
              className="text-sm text-forest-deep/60 px-3 py-2 hover:text-forest-deep transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
      {error && <p className="text-red-600 text-xs">{error}</p>}
    </div>
  )
}
