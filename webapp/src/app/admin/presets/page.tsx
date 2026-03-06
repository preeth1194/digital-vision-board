import { redirect } from 'next/navigation'
import type { Metadata } from 'next'
import AdminActions from './AdminActions'
import type { ActionTemplate } from '@/types'
import { backendServerFetch } from '@/lib/backend/server'

export const metadata: Metadata = {
  title: 'Admin — Preset Queue',
}

const CATEGORY_LABELS: Record<string, string> = {
  skincare: 'Skincare',
  workout: 'Workout',
  meal_prep: 'Meal Prep',
  recipe: 'Recipe',
}

type MeResponse = { ok: boolean; isAdmin?: boolean }
type TemplatesResponse = { templates: ActionTemplate[] }

export default async function AdminPresetsPage() {
  const me = await backendServerFetch<MeResponse>('/auth/me', {}, { redirectOnUnauthorized: true })
  if (!me.isAdmin) {
    redirect('/')
  }

  const pending = await backendServerFetch<TemplatesResponse>('/action-templates/pending')
  const reviewed = await backendServerFetch<TemplatesResponse>('/action-templates/reviewed?limit=20')

  const pendingSubmissions = pending.templates ?? []
  const reviewedSubmissions = reviewed.templates ?? []

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-12">
      <div className="flex items-center gap-3 mb-8">
        <div className="w-9 h-9 bg-forest-deep rounded-xl flex items-center justify-center">
          <svg className="w-5 h-5 text-sprout" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
          </svg>
        </div>
        <div>
          <h1 className="text-2xl font-extrabold text-forest-deep">Admin — Preset Queue</h1>
          <p className="text-forest-deep/50 text-sm">{pendingSubmissions.length} pending review</p>
        </div>
      </div>

      <section className="mb-12">
        <h2 className="text-lg font-bold text-forest-deep mb-4 flex items-center gap-2">
          <span className="w-2 h-2 bg-amber-400 rounded-full inline-block" />
          Pending Review
        </h2>

        {pendingSubmissions.length === 0 ? (
          <div className="bg-white rounded-2xl border border-forest-deep/10 p-8 text-center">
            <p className="text-forest-deep/40 text-sm">All caught up — no pending submissions.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {pendingSubmissions.map((preset) => (
              <div key={preset.id} className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
                <div className="flex items-start gap-4">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-bold text-forest-deep text-lg mb-0.5">{preset.name}</h3>
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-forest-deep/50 mb-3">
                      <span>{CATEGORY_LABELS[preset.category] ?? preset.category}</span>
                      <span>·</span>
                      <span>{preset.steps?.length ?? 0} steps</span>
                    </div>

                    {preset.steps?.length > 0 && (
                      <div className="mb-4">
                        <p className="text-xs font-semibold text-forest-deep/40 mb-2 uppercase tracking-wide">Steps</p>
                        <ol className="space-y-1">
                          {preset.steps.slice(0, 5).map((step, i) => (
                            <li key={step.id} className="text-sm text-forest-deep/70 flex items-center gap-2">
                              <span className="w-5 h-5 bg-mist rounded-full text-xs font-bold flex items-center justify-center text-forest-deep/50 flex-shrink-0">
                                {i + 1}
                              </span>
                              {step.title}
                            </li>
                          ))}
                          {preset.steps.length > 5 && (
                            <li className="text-xs text-forest-deep/40 pl-7">
                              +{preset.steps.length - 5} more steps
                            </li>
                          )}
                        </ol>
                      </div>
                    )}

                    <AdminActions presetId={preset.id} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {reviewedSubmissions.length > 0 && (
        <section>
          <h2 className="text-lg font-bold text-forest-deep mb-4 flex items-center gap-2">
            <span className="w-2 h-2 bg-sprout rounded-full inline-block" />
            Recently Reviewed
          </h2>
          <div className="space-y-2">
            {reviewedSubmissions.map((preset) => (
              <div
                key={preset.id}
                className="bg-white rounded-xl border border-forest-deep/10 px-5 py-4 flex items-center justify-between gap-4"
              >
                <div className="min-w-0">
                  <span className="font-semibold text-forest-deep text-sm">{preset.name}</span>
                  <span className="text-forest-deep/40 text-xs ml-2">
                    {CATEGORY_LABELS[preset.category] ?? preset.category}
                  </span>
                </div>
                <span
                  className={`text-xs font-bold px-2.5 py-0.5 rounded-full flex-shrink-0 ${
                    preset.status === 'approved'
                      ? 'bg-sprout/15 text-sprout-dark'
                      : 'bg-red-100 text-red-700'
                  }`}
                >
                  {preset.status === 'approved' ? 'Approved' : 'Rejected'}
                </span>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
