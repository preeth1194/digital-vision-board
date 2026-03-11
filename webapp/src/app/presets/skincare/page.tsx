'use client'

import { useState, useEffect, useCallback } from 'react'

// ─── Types ────────────────────────────────────────────────────────────────────

interface RoutineStep {
  id: string
  task: string
  productUsed: string
  note: string
}

interface WeeklyDayPlan {
  morning: boolean
  evening: boolean
}

interface SkincareData {
  morningEnabled: boolean
  eveningEnabled: boolean
  morningSteps: RoutineStep[]
  eveningSteps: RoutineStep[]
  weeklyPlan: Record<string, WeeklyDayPlan>
  products: string[]
  notes: string
}

// ─── Constants ────────────────────────────────────────────────────────────────

const STORAGE_KEY = 'dv_skincare_planner_web_v1'

const WEEK_DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
const DAY_SHORT: Record<string, string> = {
  monday: 'Mon', tuesday: 'Tue', wednesday: 'Wed', thursday: 'Thu',
  friday: 'Fri', saturday: 'Sat', sunday: 'Sun',
}

function defaultWeeklyPlan(): Record<string, WeeklyDayPlan> {
  return Object.fromEntries(WEEK_DAYS.map(d => [d, { morning: true, evening: true }]))
}

const DEFAULT_DATA: SkincareData = {
  morningEnabled: true,
  eveningEnabled: true,
  morningSteps: [
    { id: 'am_1', task: 'Cleanser', productUsed: '', note: '' },
    { id: 'am_2', task: 'Toner', productUsed: '', note: '' },
    { id: 'am_3', task: 'Serum', productUsed: '', note: '' },
    { id: 'am_4', task: 'Moisturizer', productUsed: '', note: '' },
    { id: 'am_5', task: 'Sunscreen (SPF 30+)', productUsed: '', note: '' },
  ],
  eveningSteps: [
    { id: 'pm_1', task: 'Exfoliation', productUsed: '', note: '1-2x a week' },
    { id: 'pm_2', task: 'Cleansing', productUsed: '', note: 'Sheet mask / Overnight gel' },
    { id: 'pm_3', task: 'Hydrating Mask', productUsed: '', note: '' },
    { id: 'pm_4', task: 'Clay Mask / Detox', productUsed: '', note: 'Great for oily skin' },
  ],
  weeklyPlan: defaultWeeklyPlan(),
  products: ['Cleanser', 'Sunscreen', 'Treatment', 'Mask'],
  notes: 'Drink more water\nChange pillowcase weekly\nDo not skip sunscreen\nAvoid touching your face',
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

let idCounter = 0
function makeId() {
  idCounter++
  return `step_${Date.now()}_${idCounter}`
}

function makeStep(): RoutineStep {
  return { id: makeId(), task: '', productUsed: '', note: '' }
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function RoutineEditor({
  label,
  steps,
  onUpdate,
}: {
  label: string
  steps: RoutineStep[]
  onUpdate: (steps: RoutineStep[]) => void
}) {
  const addStep = () => onUpdate([...steps, makeStep()])
  const removeStep = (id: string) => onUpdate(steps.filter(s => s.id !== id))
  const patchStep = (id: string, patch: Partial<RoutineStep>) =>
    onUpdate(steps.map(s => (s.id === id ? { ...s, ...patch } : s)))

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-forest-deep/70 uppercase tracking-wide">{label}</h3>
        <button
          type="button"
          onClick={addStep}
          className="flex items-center gap-1 text-xs font-semibold text-sprout-dark hover:text-forest-deep transition-colors"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Add Step
        </button>
      </div>

      {steps.length === 0 && (
        <p className="text-xs text-forest-deep/40 italic py-3 text-center">No steps yet — add one above.</p>
      )}

      <div className="space-y-2">
        {steps.map((step, index) => (
          <div key={step.id} className="bg-mist rounded-xl border border-forest-deep/8 p-3">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-xs font-bold text-forest-deep/30 w-5 text-center select-none">{index + 1}</span>
              {steps.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeStep(step.id)}
                  className="ml-auto text-red-400 hover:text-red-600 transition-colors"
                  aria-label="Remove step"
                >
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              )}
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <div>
                <label className="block text-xs font-medium text-forest-deep/50 mb-1">Step</label>
                <input
                  type="text"
                  value={step.task}
                  onChange={e => patchStep(step.id, { task: e.target.value })}
                  placeholder="e.g. Cleanser"
                  className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-forest-deep/50 mb-1">Product Used</label>
                <input
                  type="text"
                  value={step.productUsed}
                  onChange={e => patchStep(step.id, { productUsed: e.target.value })}
                  placeholder="e.g. CeraVe Hydrating"
                  className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white"
                />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-xs font-medium text-forest-deep/50 mb-1">Note (optional)</label>
                <input
                  type="text"
                  value={step.note}
                  onChange={e => patchStep(step.id, { note: e.target.value })}
                  placeholder="e.g. Apply on damp skin"
                  className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white"
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function SkincarePlannerPage() {
  const [data, setData] = useState<SkincareData>(DEFAULT_DATA)
  const [newProduct, setNewProduct] = useState('')
  const [saved, setSaved] = useState(false)
  const [loaded, setLoaded] = useState(false)

  // Load from localStorage on mount
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<SkincareData>
        setData({
          morningEnabled: parsed.morningEnabled ?? true,
          eveningEnabled: parsed.eveningEnabled ?? true,
          morningSteps: parsed.morningSteps ?? DEFAULT_DATA.morningSteps,
          eveningSteps: parsed.eveningSteps ?? DEFAULT_DATA.eveningSteps,
          weeklyPlan: parsed.weeklyPlan ?? defaultWeeklyPlan(),
          products: parsed.products ?? DEFAULT_DATA.products,
          notes: parsed.notes ?? DEFAULT_DATA.notes,
        })
      }
    } catch {
      // ignore
    }
    setLoaded(true)
  }, [])

  const save = useCallback(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    } catch {
      // ignore
    }
  }, [data])

  const patch = (update: Partial<SkincareData>) => setData(prev => ({ ...prev, ...update }))

  const addProduct = () => {
    const trimmed = newProduct.trim()
    if (!trimmed) return
    patch({ products: [...data.products, trimmed] })
    setNewProduct('')
  }

  const removeProduct = (index: number) =>
    patch({ products: data.products.filter((_, i) => i !== index) })

  const toggleDay = (day: string, slot: 'morning' | 'evening') => {
    const current = data.weeklyPlan[day] ?? { morning: true, evening: true }
    patch({
      weeklyPlan: {
        ...data.weeklyPlan,
        [day]: { ...current, [slot]: !current[slot] },
      },
    })
  }

  // Ensure at least one routine remains enabled
  const toggleMorning = () => {
    if (data.morningEnabled && !data.eveningEnabled) return
    patch({ morningEnabled: !data.morningEnabled })
  }
  const toggleEvening = () => {
    if (data.eveningEnabled && !data.morningEnabled) return
    patch({ eveningEnabled: !data.eveningEnabled })
  }

  if (!loaded) return null

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-10 space-y-8">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold text-forest-deep mb-1">Skincare Planner</h1>
          <p className="text-forest-deep/50 text-sm">
            Define your morning &amp; evening routines and assign them to each day of the week.
          </p>
        </div>
        <button
          onClick={save}
          className="flex items-center gap-2 bg-forest-deep text-white font-semibold px-4 py-2.5 rounded-xl hover:bg-sprout-dark transition-all text-sm shadow shrink-0"
        >
          {saved ? (
            <>
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
              Saved
            </>
          ) : (
            <>
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />
              </svg>
              Save
            </>
          )}
        </button>
      </div>

      {/* Routine toggles */}
      <div className="flex gap-3">
        <button
          type="button"
          onClick={toggleMorning}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl font-semibold text-sm transition-all border ${
            data.morningEnabled
              ? 'bg-amber-50 border-amber-200 text-amber-700'
              : 'bg-white border-forest-deep/15 text-forest-deep/40'
          }`}
        >
          <span className="text-base">☀️</span>
          Morning
          {data.morningEnabled && (
            <span className="w-1.5 h-1.5 rounded-full bg-amber-400 ml-0.5" />
          )}
        </button>
        <button
          type="button"
          onClick={toggleEvening}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl font-semibold text-sm transition-all border ${
            data.eveningEnabled
              ? 'bg-indigo-50 border-indigo-200 text-indigo-700'
              : 'bg-white border-forest-deep/15 text-forest-deep/40'
          }`}
        >
          <span className="text-base">🌙</span>
          Evening
          {data.eveningEnabled && (
            <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 ml-0.5" />
          )}
        </button>
      </div>

      {/* Morning routine */}
      {data.morningEnabled && (
        <section className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
          <div className="flex items-center gap-2 mb-4">
            <span className="text-lg">☀️</span>
            <h2 className="text-base font-bold text-forest-deep">Morning Routine</h2>
            <span className="ml-auto text-xs text-forest-deep/40">{data.morningSteps.length} step{data.morningSteps.length !== 1 ? 's' : ''}</span>
          </div>
          <RoutineEditor
            label="Steps"
            steps={data.morningSteps}
            onUpdate={steps => patch({ morningSteps: steps })}
          />
        </section>
      )}

      {/* Evening routine */}
      {data.eveningEnabled && (
        <section className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
          <div className="flex items-center gap-2 mb-4">
            <span className="text-lg">🌙</span>
            <h2 className="text-base font-bold text-forest-deep">Evening Routine</h2>
            <span className="ml-auto text-xs text-forest-deep/40">{data.eveningSteps.length} step{data.eveningSteps.length !== 1 ? 's' : ''}</span>
          </div>
          <RoutineEditor
            label="Steps"
            steps={data.eveningSteps}
            onUpdate={steps => patch({ eveningSteps: steps })}
          />
        </section>
      )}

      {/* Weekly plan */}
      <section className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
        <h2 className="text-base font-bold text-forest-deep mb-1">Weekly Plan</h2>
        <p className="text-xs text-forest-deep/40 mb-4">
          Toggle which routines you do on each day.
        </p>
        <div className="overflow-x-auto -mx-1">
          <table className="w-full min-w-[380px] text-sm border-separate border-spacing-y-1">
            <thead>
              <tr>
                <th className="text-left text-xs font-semibold text-forest-deep/50 pb-2 pl-1 w-24">Day</th>
                {data.morningEnabled && (
                  <th className="text-center text-xs font-semibold text-amber-600 pb-2">☀️ AM</th>
                )}
                {data.eveningEnabled && (
                  <th className="text-center text-xs font-semibold text-indigo-600 pb-2">🌙 PM</th>
                )}
              </tr>
            </thead>
            <tbody>
              {WEEK_DAYS.map(day => {
                const plan = data.weeklyPlan[day] ?? { morning: true, evening: true }
                return (
                  <tr key={day} className="bg-mist rounded-xl">
                    <td className="pl-3 py-2.5 font-medium text-forest-deep rounded-l-xl text-sm">
                      {DAY_SHORT[day]}
                    </td>
                    {data.morningEnabled && (
                      <td className="text-center py-2.5">
                        <button
                          type="button"
                          onClick={() => toggleDay(day, 'morning')}
                          className={`w-8 h-5 rounded-full transition-colors relative ${
                            plan.morning ? 'bg-amber-400' : 'bg-forest-deep/15'
                          }`}
                          aria-label={`Toggle morning for ${day}`}
                        >
                          <span
                            className={`absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform ${
                              plan.morning ? 'translate-x-3' : 'translate-x-0.5'
                            }`}
                          />
                        </button>
                      </td>
                    )}
                    {data.eveningEnabled && (
                      <td className="text-center py-2.5 rounded-r-xl">
                        <button
                          type="button"
                          onClick={() => toggleDay(day, 'evening')}
                          className={`w-8 h-5 rounded-full transition-colors relative ${
                            plan.evening ? 'bg-indigo-400' : 'bg-forest-deep/15'
                          }`}
                          aria-label={`Toggle evening for ${day}`}
                        >
                          <span
                            className={`absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform ${
                              plan.evening ? 'translate-x-3' : 'translate-x-0.5'
                            }`}
                          />
                        </button>
                      </td>
                    )}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* Products to buy */}
      <section className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
        <h2 className="text-base font-bold text-forest-deep mb-1">Products to Buy</h2>
        <p className="text-xs text-forest-deep/40 mb-4">Keep a shopping list of products you need.</p>

        <div className="flex gap-2 mb-3">
          <input
            type="text"
            value={newProduct}
            onChange={e => setNewProduct(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addProduct() } }}
            placeholder="e.g. Vitamin C serum"
            className="flex-1 border border-forest-deep/15 rounded-xl px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white"
          />
          <button
            type="button"
            onClick={addProduct}
            className="px-4 py-2 bg-forest-deep text-white rounded-xl text-sm font-semibold hover:bg-sprout-dark transition-all"
          >
            Add
          </button>
        </div>

        {data.products.length === 0 ? (
          <p className="text-xs text-forest-deep/40 italic text-center py-3">No products listed yet.</p>
        ) : (
          <ul className="space-y-1.5">
            {data.products.map((product, index) => (
              <li key={index} className="flex items-center gap-2 bg-mist rounded-xl px-3 py-2">
                <span className="w-1.5 h-1.5 rounded-full bg-sprout shrink-0" />
                <span className="flex-1 text-sm text-forest-deep">{product}</span>
                <button
                  type="button"
                  onClick={() => removeProduct(index)}
                  className="text-red-400 hover:text-red-600 transition-colors"
                  aria-label="Remove product"
                >
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* Notes */}
      <section className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm">
        <h2 className="text-base font-bold text-forest-deep mb-1">Notes</h2>
        <p className="text-xs text-forest-deep/40 mb-3">Reminders and tips for your routine.</p>
        <textarea
          value={data.notes}
          onChange={e => patch({ notes: e.target.value })}
          rows={5}
          placeholder="e.g. Drink more water, change pillowcase weekly…"
          className="w-full border border-forest-deep/15 rounded-xl px-4 py-3 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white resize-none"
        />
      </section>

      {/* Save footer */}
      <div className="flex justify-end pb-4">
        <button
          onClick={save}
          className="flex items-center gap-2 bg-forest-deep text-white font-semibold px-6 py-3 rounded-xl hover:bg-sprout-dark transition-all text-sm shadow"
        >
          {saved ? '✓ Saved!' : 'Save Planner'}
        </button>
      </div>
    </div>
  )
}
