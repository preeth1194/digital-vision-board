import Link from 'next/link'
import type { Metadata } from 'next'
import { backendServerFetch } from '@/lib/backend/server'
import type { ActionTemplate } from '@/types'

export const metadata: Metadata = {
  title: 'Presets',
}

const STATUS_STYLES: Record<string, { bg: string; text: string; label: string }> = {
  submitted: { bg: 'bg-amber-100', text: 'text-amber-800', label: 'Pending Review' },
  approved: { bg: 'bg-sprout/15', text: 'text-sprout-dark', label: 'Approved' },
  rejected: { bg: 'bg-red-100', text: 'text-red-700', label: 'Rejected' },
  draft: { bg: 'bg-slate-100', text: 'text-slate-700', label: 'Draft' },
}

const CATEGORY_LABELS: Record<string, string> = {
  skincare: 'Skincare',
  workout: 'Workout',
  meal_prep: 'Meal Prep',
  recipe: 'Recipe',
}

type MineResponse = {
  templates: ActionTemplate[]
}

export default async function PresetsPage() {
  const result = await backendServerFetch<MineResponse>('/action-templates/mine', {}, { redirectOnUnauthorized: true })
  const submissions = result.templates ?? []

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-12">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-extrabold text-forest-deep mb-1">Presets</h1>
          <p className="text-forest-deep/50 text-sm">Your planners and community submissions.</p>
        </div>
        <Link
          href="/presets/upload"
          className="flex items-center gap-2 bg-forest-deep text-white font-semibold px-4 py-2.5 rounded-xl hover:bg-sprout-dark transition-all text-sm shadow"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Submit Preset
        </Link>
      </div>

      {/* Skincare planner shortcut */}
      <Link
        href="/presets/skincare"
        className="flex items-center gap-4 bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm hover:shadow-md hover:border-sprout/40 transition-all mb-8 group"
      >
        <div className="w-12 h-12 rounded-2xl bg-amber-50 border border-amber-100 flex items-center justify-center text-2xl shrink-0">
          ✨
        </div>
        <div className="flex-1 min-w-0">
          <h2 className="font-bold text-forest-deep group-hover:text-sprout-dark transition-colors">Skincare Planner</h2>
          <p className="text-xs text-forest-deep/50 mt-0.5">
            Morning &amp; evening routines, weekly day assignments, and product tracking.
          </p>
        </div>
        <svg className="w-5 h-5 text-forest-deep/30 group-hover:text-sprout-dark transition-colors shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
        </svg>
      </Link>

      {/* Community submissions */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-base font-bold text-forest-deep">My Submissions</h2>
        <span className="text-xs text-forest-deep/40">
          {submissions.length === 0 ? 'None yet' : `${submissions.length} submission${submissions.length === 1 ? '' : 's'}`}
        </span>
      </div>

      {submissions.length === 0 ? (
        <div className="bg-white rounded-2xl border border-forest-deep/10 p-10 text-center">
          <div className="w-14 h-14 bg-mist rounded-2xl flex items-center justify-center mx-auto mb-4">
            <svg className="w-7 h-7 text-forest-deep/30" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z" />
            </svg>
          </div>
          <h3 className="text-base font-bold text-forest-deep mb-2">No submissions yet</h3>
          <p className="text-forest-deep/50 text-sm mb-6">
            Share your favourite habits with the community by submitting a preset.
          </p>
          <Link
            href="/presets/upload"
            className="inline-block bg-forest-deep text-white font-semibold px-6 py-2.5 rounded-xl hover:bg-sprout-dark transition-all text-sm"
          >
            Submit Your First Preset
          </Link>
        </div>
      ) : (
        <div className="space-y-3">
          {submissions.map((preset) => {
            const badge = STATUS_STYLES[preset.status] ?? STATUS_STYLES.submitted
            return (
              <div
                key={preset.id}
                className="bg-white rounded-2xl border border-forest-deep/10 p-5 flex items-start justify-between gap-4 shadow-sm"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <h3 className="font-bold text-forest-deep truncate">{preset.name}</h3>
                    <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full ${badge.bg} ${badge.text}`}>
                      {badge.label}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-forest-deep/50">
                    <span>{CATEGORY_LABELS[preset.category] ?? preset.category}</span>
                    <span>·</span>
                    <span>{preset.steps?.length ?? 0} steps</span>
                    <span>·</span>
                    <span>{preset.updatedAt ? new Date(preset.updatedAt).toLocaleDateString() : 'Recently updated'}</span>
                  </div>
                  {preset.status === 'rejected' && preset.reviewNotes && (
                    <p className="mt-2 text-xs text-red-600 bg-red-50 rounded-lg px-3 py-2">
                      {preset.reviewNotes}
                    </p>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
