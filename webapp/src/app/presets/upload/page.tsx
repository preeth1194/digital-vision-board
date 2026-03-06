'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { PRESET_CATEGORIES, MATERIAL_ICONS } from '@/lib/constants'
import type { HabitActionStep, PresetCategory } from '@/types'
import { backendClientFetch } from '@/lib/backend/client'

let stepCounter = 0

function makeStep(): HabitActionStep {
  stepCounter++
  return {
    id: `step_${Date.now()}_${stepCounter}`,
    title: '',
    iconCodePoint: 0xe86c,
    order: stepCounter,
  }
}

export default function UploadPresetPage() {
  const router = useRouter()

  const [name, setName] = useState('')
  const [category, setCategory] = useState<PresetCategory>('skincare')
  const [steps, setSteps] = useState<HabitActionStep[]>([makeStep()])
  const [status, setStatus] = useState<'idle' | 'submitting' | 'error'>('idle')
  const [error, setError] = useState('')

  const addStep = () => setSteps((prev) => [...prev, makeStep()])
  const removeStep = (id: string) => setSteps((prev) => prev.filter((s) => s.id !== id))
  const updateStep = (id: string, patch: Partial<HabitActionStep>) => {
    setSteps((prev) => prev.map((s) => (s.id === id ? { ...s, ...patch } : s)))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!steps.length) {
      setError('Add at least one step.')
      return
    }

    setStatus('submitting')
    setError('')

    try {
      const orderedSteps = steps.map((s, i) => ({ ...s, order: i }))
      await backendClientFetch('/action-templates/submit', {
        method: 'POST',
        body: JSON.stringify({
          name,
          category,
          schemaVersion: 1,
          templateVersion: 1,
          steps: orderedSteps,
          metadata: {},
        }),
      })
      router.push('/presets')
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Submission failed')
      setStatus('error')
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-12">
      <h1 className="text-2xl font-extrabold text-forest-deep mb-1">Submit a Preset</h1>
      <p className="text-forest-deep/50 text-sm mb-2">
        Share your habit routine with the community. It will be reviewed before publishing.
      </p>
      <p className="text-forest-deep/40 text-xs mb-8">
        Preview image upload is disabled in web for now; this flow uses backend-only template submission.
      </p>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="preset-name">
            Preset Name <span className="text-red-500">*</span>
          </label>
          <input
            id="preset-name"
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Morning Glow Skincare Routine"
            className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
          />
        </div>

        <div>
          <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="preset-category">
            Category <span className="text-red-500">*</span>
          </label>
          <select
            id="preset-category"
            value={category}
            onChange={(e) => setCategory(e.target.value as PresetCategory)}
            className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
          >
            {PRESET_CATEGORIES.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </select>
        </div>

        <div>
          <div className="flex items-center justify-between mb-3">
            <label className="text-sm font-semibold text-forest-deep">
              Steps <span className="text-red-500">*</span>
            </label>
            <button
              type="button"
              onClick={addStep}
              className="flex items-center gap-1 text-xs font-semibold text-sprout-dark hover:text-forest-deep transition-colors"
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Add Step
            </button>
          </div>

          <div className="space-y-3">
            {steps.map((step, index) => (
              <div key={step.id} className="bg-mist rounded-xl p-4 border border-forest-deep/10">
                <div className="flex items-center gap-2 mb-3">
                  <span className="text-xs font-bold text-forest-deep/40 w-6 text-center">{index + 1}</span>
                  <span className="text-xs font-semibold text-forest-deep/60">Step</span>
                  {steps.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeStep(step.id)}
                      className="ml-auto text-red-400 hover:text-red-600 transition-colors"
                      aria-label="Remove step"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  )}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-forest-deep/60 mb-1">Title</label>
                    <input
                      type="text"
                      required
                      value={step.title}
                      onChange={(e) => updateStep(step.id, { title: e.target.value })}
                      placeholder="e.g. Cleanse face"
                      className="w-full border border-forest-deep/20 rounded-lg px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-forest-deep/60 mb-1">Icon</label>
                    <select
                      value={step.iconCodePoint}
                      onChange={(e) => updateStep(step.id, { iconCodePoint: parseInt(e.target.value, 10) })}
                      className="w-full border border-forest-deep/20 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white"
                    >
                      {MATERIAL_ICONS.map((icon) => (
                        <option key={icon.codePoint} value={icon.codePoint}>
                          {icon.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {error && (
          <p className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-4 py-3">
            {error}
          </p>
        )}

        <div className="flex gap-3">
          <button
            type="button"
            onClick={() => router.back()}
            className="flex-1 border border-forest-deep/20 text-forest-deep font-semibold py-3 rounded-xl hover:bg-forest-deep/5 transition-all text-sm"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={status === 'submitting'}
            className="flex-1 bg-forest-deep text-white font-bold py-3 rounded-xl hover:bg-sprout-dark transition-all disabled:opacity-60 disabled:cursor-not-allowed shadow text-sm"
          >
            {status === 'submitting' ? 'Submitting…' : 'Submit for Review'}
          </button>
        </div>
      </form>
    </div>
  )
}
