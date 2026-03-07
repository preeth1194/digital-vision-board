'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { backendClientFetch } from '@/lib/backend/client'

// ─── Types ────────────────────────────────────────────────────────────────────

interface WorkoutExercise {
  name: string
  sets: string
  reps: string
  rest: string
  muscle: string
  equipment: string
  note: string
}

interface WorkoutDay {
  label: string
  schedule: string
  focus: string
  exercises: WorkoutExercise[]
}

interface WorkoutTemplate {
  id: string
  name: string
  level: 'Beginner' | 'Intermediate' | 'Advanced'
  levelColor: string
  goal: string
  daysPerWeek: number
  durationWeeks: number
  schedule: string
  split: string
  timePerSession: string
  equipment: string[]
  source: string
  description: string
  workoutDays: WorkoutDay[]
}

interface CustomStep {
  id: string
  exercise: string
  sets: string
  reps: string
  rest: string
  muscle: string
  equipment: string
  day: string
  note: string
}

// ─── Template data from Muscle & Strength ────────────────────────────────────

const TEMPLATES: WorkoutTemplate[] = [
  {
    id: 'ms_beginner_full_body',
    name: 'Start from Scratch',
    level: 'Beginner',
    levelColor: 'bg-emerald-100 text-emerald-700 border-emerald-200',
    goal: 'Build Muscle & Strength Foundation',
    daysPerWeek: 4,
    durationWeeks: 6,
    schedule: 'Mon / Tue / Thu / Fri',
    split: 'Full Body — Workout A + B alternating',
    timePerSession: '45–60 min',
    equipment: ['Barbell', 'Dumbbell', 'Cable Machine', 'Bench'],
    source: 'https://www.muscleandstrength.com/workouts/start-from-scratch-beginner-workout',
    description:
      'Two alternating full-body workouts build a rock-solid foundation using compound lifts. Use a 2-second tempo on every rep. Warm-up sets required on marked exercises.',
    workoutDays: [
      {
        label: 'Workout A',
        schedule: 'Mon & Thu',
        focus: 'Upper Body',
        exercises: [
          { name: 'Barbell Bench Press', sets: '2', reps: '8–10', rest: '90 sec', muscle: 'Chest', equipment: 'Barbell', note: 'Warm-up set required. 2 sec up, 2 sec down.' },
          { name: 'Incline Dumbbell Press', sets: '2', reps: '10', rest: '90 sec', muscle: 'Chest', equipment: 'Dumbbell', note: '' },
          { name: 'Bent-Over Barbell Row', sets: '2', reps: '8–10', rest: '90 sec', muscle: 'Back', equipment: 'Barbell', note: 'Keep back flat and neutral.' },
          { name: 'Lat Pulldown', sets: '2', reps: '10', rest: '90 sec', muscle: 'Back', equipment: 'Cable Machine', note: '' },
          { name: 'Barbell Overhead Press', sets: '2', reps: '8–10', rest: '90 sec', muscle: 'Shoulders', equipment: 'Barbell', note: 'Press in a straight line.' },
          { name: 'Dumbbell Curl', sets: '2', reps: '10', rest: '60 sec', muscle: 'Biceps', equipment: 'Dumbbell', note: '' },
          { name: 'Tricep Rope Pushdown', sets: '2', reps: '10', rest: '60 sec', muscle: 'Triceps', equipment: 'Cable Machine', note: '' },
        ],
      },
      {
        label: 'Workout B',
        schedule: 'Tue & Fri',
        focus: 'Lower Body & Core',
        exercises: [
          { name: 'Barbell Back Squat', sets: '2', reps: '10–12', rest: '90 sec', muscle: 'Legs', equipment: 'Barbell', note: 'Warm-up set required. Sit back, chest up.' },
          { name: 'Romanian Deadlift', sets: '2', reps: '10–12', rest: '90 sec', muscle: 'Hamstrings', equipment: 'Barbell', note: 'Feel the stretch at the bottom.' },
          { name: 'Leg Press', sets: '2', reps: '12', rest: '90 sec', muscle: 'Legs', equipment: 'Machine', note: '' },
          { name: 'Leg Curl', sets: '2', reps: '12', rest: '60 sec', muscle: 'Hamstrings', equipment: 'Machine', note: '' },
          { name: 'Standing Calf Raise', sets: '2', reps: '15', rest: '60 sec', muscle: 'Calves', equipment: 'Machine', note: '' },
          { name: 'Plank', sets: '2', reps: '30 sec', rest: '45 sec', muscle: 'Core', equipment: 'Bodyweight', note: '' },
          { name: 'Crunches', sets: '2', reps: '15–20', rest: '45 sec', muscle: 'Core', equipment: 'Bodyweight', note: '' },
        ],
      },
    ],
  },
  {
    id: 'ms_intermediate_hypertrophy',
    name: '8-Week Mass Building Hypertrophy',
    level: 'Intermediate',
    levelColor: 'bg-blue-100 text-blue-700 border-blue-200',
    goal: 'Build Muscle Mass',
    daysPerWeek: 4,
    durationWeeks: 8,
    schedule: 'Mon / Tue / Thu / Fri',
    split: 'Chest+Delts / Back+Rear Delts / Arms+Abs / Legs',
    timePerSession: '60–75 min',
    equipment: ['Barbell', 'Dumbbell', 'Cables', 'Machines'],
    source: 'https://www.muscleandstrength.com/workouts/8-week-hypertrophy-workout',
    description:
      'A 4-day hypertrophy split for intermediate trainees. Intensity techniques — rest-pause (*), drop sets (+), and slow negatives (^) — push muscles past normal fatigue for maximum growth.',
    workoutDays: [
      {
        label: 'Workout 1',
        schedule: 'Monday',
        focus: 'Chest & Side Delts',
        exercises: [
          { name: 'Incline Barbell Bench Press', sets: '3', reps: '12, 10, 12*', rest: '90 sec', muscle: 'Chest', equipment: 'Barbell', note: '* Rest-Pause: rest 10–15 sec, push more reps' },
          { name: 'Flat Dumbbell Bench Press', sets: '3', reps: '12, 10, 15+', rest: '90 sec', muscle: 'Chest', equipment: 'Dumbbell', note: '+ Drop Set: reduce weight and push to failure' },
          { name: 'Cable Crossover', sets: '3', reps: '12, 12, 12^', rest: '90 sec', muscle: 'Chest', equipment: 'Cables', note: '^ 3–5 second negatives' },
          { name: 'Seated Lateral Raise', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Side Delts', equipment: 'Dumbbell', note: '' },
          { name: 'Cable Lateral Raise', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Side Delts', equipment: 'Cables', note: '' },
        ],
      },
      {
        label: 'Workout 2',
        schedule: 'Tuesday',
        focus: 'Back & Rear Delts',
        exercises: [
          { name: 'Bent-Over Barbell Row', sets: '3', reps: '12, 10, 12*', rest: '90 sec', muscle: 'Back', equipment: 'Barbell', note: '* Rest-Pause' },
          { name: 'Dumbbell Pullover', sets: '3', reps: '12, 10, 15+', rest: '90 sec', muscle: 'Back', equipment: 'Dumbbell', note: '+ Drop Set' },
          { name: 'Wide Grip Lat Pulldown', sets: '3', reps: '12, 12, 12^', rest: '90 sec', muscle: 'Back', equipment: 'Cables', note: '^ 3–5 sec negatives' },
          { name: 'Dumbbell Rear Delt Fly', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Rear Delts', equipment: 'Dumbbell', note: '' },
          { name: 'Cable Face Pull', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Rear Delts', equipment: 'Cables', note: '' },
          { name: 'Dumbbell Shrug', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Traps', equipment: 'Dumbbell', note: '' },
        ],
      },
      {
        label: 'Workout 3',
        schedule: 'Thursday',
        focus: 'Arms & Abs',
        exercises: [
          { name: 'Barbell Curl', sets: '3', reps: '12, 10, 8*', rest: '90 sec', muscle: 'Biceps', equipment: 'Barbell', note: '* Rest-Pause' },
          { name: 'Incline Dumbbell Curl', sets: '3', reps: '12, 12, 12', rest: '60 sec', muscle: 'Biceps', equipment: 'Dumbbell', note: '' },
          { name: 'Hammer Curl', sets: '3', reps: '12, 12, 12+', rest: '60 sec', muscle: 'Biceps', equipment: 'Dumbbell', note: '+ Drop Set' },
          { name: 'Tricep Rope Pushdown', sets: '3', reps: '12, 10, 8*', rest: '90 sec', muscle: 'Triceps', equipment: 'Cables', note: '* Rest-Pause' },
          { name: 'Skull Crusher', sets: '3', reps: '12, 12, 12^', rest: '60 sec', muscle: 'Triceps', equipment: 'Barbell', note: '^ 3–5 sec negatives' },
          { name: 'Cable Crunch', sets: '3', reps: '15, 15, 15', rest: '60 sec', muscle: 'Core', equipment: 'Cables', note: '' },
          { name: 'Hanging Leg Raise', sets: '3', reps: '12, 12, 12', rest: '60 sec', muscle: 'Core', equipment: 'Bodyweight', note: '' },
        ],
      },
      {
        label: 'Workout 4',
        schedule: 'Friday',
        focus: 'Legs',
        exercises: [
          { name: 'Barbell Back Squat', sets: '3', reps: '12, 10, 8*', rest: '120 sec', muscle: 'Quads', equipment: 'Barbell', note: '* Rest-Pause. Explode up, control down.' },
          { name: 'Leg Press', sets: '3', reps: '12, 12, 15+', rest: '90 sec', muscle: 'Quads', equipment: 'Machine', note: '+ Drop Set' },
          { name: 'Romanian Deadlift', sets: '3', reps: '12, 10, 12^', rest: '90 sec', muscle: 'Hamstrings', equipment: 'Barbell', note: '^ 3–5 sec negatives. Feel the hamstring stretch.' },
          { name: 'Leg Curl', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Hamstrings', equipment: 'Machine', note: '' },
          { name: 'Leg Extension', sets: '3', reps: '12, 12, 12', rest: '90 sec', muscle: 'Quads', equipment: 'Machine', note: '' },
          { name: 'Standing Calf Raise', sets: '4', reps: '15, 15, 15, 15', rest: '60 sec', muscle: 'Calves', equipment: 'Machine', note: '' },
        ],
      },
    ],
  },
  {
    id: 'ms_advanced_strength',
    name: 'Big & Strong — 8 Week Advanced Strength',
    level: 'Advanced',
    levelColor: 'bg-red-100 text-red-700 border-red-200',
    goal: 'Build Strength & Power',
    daysPerWeek: 5,
    durationWeeks: 8,
    schedule: 'Mon / Tue / Wed / Thu / Fri',
    split: 'Squat / Bench / Deadlift / OHP / Accessory',
    timePerSession: '60–90 min',
    equipment: ['Barbell', 'Dumbbell', 'Cable Machine', 'Power Rack'],
    source: 'https://www.muscleandstrength.com/workouts/big-and-strong-advanced-program',
    description:
      'For experienced lifters (1+ year). Focuses on power, speed, and explosive movements across the big four lifts. Rest 3–5 min between heavy compound sets. Progressive overload every week.',
    workoutDays: [
      {
        label: 'Day 1',
        schedule: 'Monday',
        focus: 'Squat & Lower Body',
        exercises: [
          { name: 'Barbell Back Squat', sets: '5', reps: '5', rest: '3–4 min', muscle: 'Legs', equipment: 'Barbell', note: 'Work up to a heavy 5-rep set. Explosive drive out of the hole.' },
          { name: 'Front Squat', sets: '3', reps: '5', rest: '2–3 min', muscle: 'Legs', equipment: 'Barbell', note: '' },
          { name: 'Leg Press', sets: '3', reps: '8', rest: '2 min', muscle: 'Legs', equipment: 'Machine', note: '' },
          { name: 'Leg Extension', sets: '3', reps: '10', rest: '90 sec', muscle: 'Quads', equipment: 'Machine', note: '' },
          { name: 'Leg Curl', sets: '3', reps: '10', rest: '90 sec', muscle: 'Hamstrings', equipment: 'Machine', note: '' },
          { name: 'Standing Calf Raise', sets: '4', reps: '12', rest: '60 sec', muscle: 'Calves', equipment: 'Machine', note: '' },
        ],
      },
      {
        label: 'Day 2',
        schedule: 'Tuesday',
        focus: 'Bench & Chest',
        exercises: [
          { name: 'Barbell Bench Press', sets: '5', reps: '5', rest: '3–4 min', muscle: 'Chest', equipment: 'Barbell', note: 'Work up to heavy 5. Drive legs into the floor, stay tight.' },
          { name: 'Incline Barbell Bench Press', sets: '3', reps: '6', rest: '2–3 min', muscle: 'Chest', equipment: 'Barbell', note: '' },
          { name: 'Dumbbell Flye', sets: '3', reps: '10', rest: '90 sec', muscle: 'Chest', equipment: 'Dumbbell', note: '' },
          { name: 'Weighted Dip', sets: '3', reps: '8', rest: '90 sec', muscle: 'Triceps', equipment: 'Bodyweight', note: 'Add weight via dip belt when 10+ reps feel easy.' },
          { name: 'Skull Crusher', sets: '3', reps: '10', rest: '90 sec', muscle: 'Triceps', equipment: 'Barbell', note: '' },
        ],
      },
      {
        label: 'Day 3',
        schedule: 'Wednesday',
        focus: 'Deadlift & Back',
        exercises: [
          { name: 'Conventional Deadlift', sets: '5', reps: '3–5', rest: '4–5 min', muscle: 'Back', equipment: 'Barbell', note: 'Work to a heavy top set. Reset on each rep.' },
          { name: 'Barbell Row', sets: '4', reps: '6', rest: '2–3 min', muscle: 'Back', equipment: 'Barbell', note: '' },
          { name: 'Wide-Grip Pull-Up', sets: '3', reps: 'Max', rest: '2 min', muscle: 'Back', equipment: 'Bodyweight', note: 'Add weight if 10+ reps become easy.' },
          { name: 'T-Bar Row', sets: '3', reps: '8', rest: '2 min', muscle: 'Back', equipment: 'Barbell', note: '' },
          { name: 'Barbell Curl', sets: '3', reps: '8', rest: '90 sec', muscle: 'Biceps', equipment: 'Barbell', note: '' },
          { name: 'Cable Face Pull', sets: '3', reps: '15', rest: '60 sec', muscle: 'Rear Delts', equipment: 'Cables', note: 'Great for shoulder health.' },
        ],
      },
      {
        label: 'Day 4',
        schedule: 'Thursday',
        focus: 'Overhead Press & Shoulders',
        exercises: [
          { name: 'Barbell Overhead Press', sets: '5', reps: '5', rest: '3–4 min', muscle: 'Shoulders', equipment: 'Barbell', note: 'Standing. Press bar in a straight line overhead.' },
          { name: 'Arnold Dumbbell Press', sets: '3', reps: '8', rest: '2 min', muscle: 'Shoulders', equipment: 'Dumbbell', note: '' },
          { name: 'Dumbbell Lateral Raise', sets: '3', reps: '12', rest: '90 sec', muscle: 'Side Delts', equipment: 'Dumbbell', note: '' },
          { name: 'Rear Delt Fly', sets: '3', reps: '12', rest: '90 sec', muscle: 'Rear Delts', equipment: 'Dumbbell', note: '' },
          { name: 'Barbell Shrug', sets: '3', reps: '10', rest: '90 sec', muscle: 'Traps', equipment: 'Barbell', note: '' },
        ],
      },
      {
        label: 'Day 5',
        schedule: 'Friday',
        focus: 'Accessory & Hypertrophy',
        exercises: [
          { name: 'Dumbbell Lunge', sets: '3', reps: '10 each', rest: '90 sec', muscle: 'Legs', equipment: 'Dumbbell', note: 'Alternate legs each rep.' },
          { name: 'Dumbbell Row', sets: '3', reps: '10', rest: '90 sec', muscle: 'Back', equipment: 'Dumbbell', note: '' },
          { name: 'Dumbbell Shoulder Press', sets: '3', reps: '10', rest: '90 sec', muscle: 'Shoulders', equipment: 'Dumbbell', note: '' },
          { name: 'Incline Dumbbell Curl', sets: '3', reps: '12', rest: '60 sec', muscle: 'Biceps', equipment: 'Dumbbell', note: '' },
          { name: 'Tricep Overhead Extension', sets: '3', reps: '12', rest: '60 sec', muscle: 'Triceps', equipment: 'Dumbbell', note: '' },
          { name: 'Hanging Leg Raise', sets: '3', reps: '15', rest: '60 sec', muscle: 'Core', equipment: 'Bodyweight', note: '' },
          { name: 'Cable Crunch', sets: '3', reps: '15', rest: '60 sec', muscle: 'Core', equipment: 'Cables', note: '' },
        ],
      },
    ],
  },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────

const ICON_CP = 0xe86c
let idCounter = 0
function uid() { return `step_${Date.now()}_${++idCounter}` }

function templateToSteps(t: WorkoutTemplate): CustomStep[] {
  return t.workoutDays.flatMap(day =>
    day.exercises.map(ex => ({
      id: uid(),
      exercise: ex.name,
      sets: ex.sets,
      reps: ex.reps,
      rest: ex.rest,
      muscle: ex.muscle,
      equipment: ex.equipment,
      day: `${day.label} — ${day.schedule} (${day.focus})`,
      note: ex.note,
    }))
  )
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function LevelBadge({ template }: { template: WorkoutTemplate }) {
  return (
    <span className={`text-xs font-bold px-2 py-0.5 rounded-full border ${template.levelColor}`}>
      {template.level}
    </span>
  )
}

function PlanPreview({ template, onUse }: { template: WorkoutTemplate; onUse: () => void }) {
  const [openDay, setOpenDay] = useState<string | null>(template.workoutDays[0]?.label ?? null)

  return (
    <div className="bg-white rounded-2xl border border-forest-deep/10 shadow-sm overflow-hidden">
      {/* Header */}
      <div className="bg-forest-deep px-6 py-5 text-white">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-extrabold mb-0.5">{template.name}</h2>
            <p className="text-white/60 text-xs">{template.split}</p>
          </div>
          <LevelBadge template={template} />
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
          {[
            { label: 'Duration', value: `${template.durationWeeks} weeks` },
            { label: 'Days / week', value: `${template.daysPerWeek} days` },
            { label: 'Per session', value: template.timePerSession },
            { label: 'Goal', value: template.goal },
          ].map(({ label, value }) => (
            <div key={label} className="bg-white/10 rounded-xl px-3 py-2">
              <p className="text-white/50 text-xs">{label}</p>
              <p className="text-white font-semibold text-sm">{value}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Description */}
      <div className="px-6 py-4 border-b border-forest-deep/8">
        <p className="text-forest-deep/70 text-sm">{template.description}</p>
        <div className="flex flex-wrap gap-1.5 mt-3">
          {template.equipment.map(eq => (
            <span key={eq} className="text-xs px-2.5 py-1 bg-mist border border-forest-deep/10 rounded-full text-forest-deep/60 font-medium">
              {eq}
            </span>
          ))}
        </div>
      </div>

      {/* Weekly schedule accordion */}
      <div className="px-6 py-4">
        <p className="text-xs font-semibold text-forest-deep/50 uppercase tracking-wide mb-3">
          Weekly Schedule — {template.schedule}
        </p>

        <div className="space-y-2">
          {template.workoutDays.map(day => {
            const isOpen = openDay === day.label
            const totalSets = day.exercises.reduce((acc, ex) => acc + parseInt(ex.sets, 10) || 0, 0)
            return (
              <div key={day.label} className="rounded-xl border border-forest-deep/10 overflow-hidden">
                <button
                  onClick={() => setOpenDay(isOpen ? null : day.label)}
                  className="w-full flex items-center justify-between px-4 py-3 bg-mist hover:bg-forest-deep/5 transition-colors text-left"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-forest-deep/10 flex items-center justify-center shrink-0">
                      <span className="text-xs font-bold text-forest-deep/60">{day.label.slice(0, 2)}</span>
                    </div>
                    <div>
                      <p className="font-semibold text-forest-deep text-sm">{day.label} — {day.focus}</p>
                      <p className="text-xs text-forest-deep/40">{day.schedule} · {day.exercises.length} exercises · {totalSets} total sets</p>
                    </div>
                  </div>
                  <svg
                    className={`w-4 h-4 text-forest-deep/40 transition-transform ${isOpen ? 'rotate-180' : ''}`}
                    fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {isOpen && (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm min-w-[500px]">
                      <thead>
                        <tr className="border-b border-forest-deep/8">
                          <th className="text-left px-4 py-2 text-xs font-semibold text-forest-deep/40 uppercase">Exercise</th>
                          <th className="text-center px-3 py-2 text-xs font-semibold text-forest-deep/40 uppercase">Sets</th>
                          <th className="text-center px-3 py-2 text-xs font-semibold text-forest-deep/40 uppercase">Reps</th>
                          <th className="text-center px-3 py-2 text-xs font-semibold text-forest-deep/40 uppercase">Rest</th>
                          <th className="text-left px-4 py-2 text-xs font-semibold text-forest-deep/40 uppercase">Muscle</th>
                        </tr>
                      </thead>
                      <tbody>
                        {day.exercises.map((ex, i) => (
                          <tr key={i} className={i % 2 === 0 ? 'bg-white' : 'bg-mist/40'}>
                            <td className="px-4 py-2.5">
                              <p className="font-medium text-forest-deep">{ex.name}</p>
                              {ex.note && <p className="text-xs text-forest-deep/40 mt-0.5">{ex.note}</p>}
                            </td>
                            <td className="px-3 py-2.5 text-center font-semibold text-forest-deep">{ex.sets}</td>
                            <td className="px-3 py-2.5 text-center text-forest-deep/80 font-mono text-xs">{ex.reps}</td>
                            <td className="px-3 py-2.5 text-center text-forest-deep/50 text-xs">{ex.rest}</td>
                            <td className="px-4 py-2.5 text-xs text-forest-deep/50">{ex.muscle} · {ex.equipment}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )
          })}
        </div>

        <a
          href={template.source}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1 text-xs text-forest-deep/40 hover:text-sprout-dark transition-colors mt-3"
        >
          <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" />
          </svg>
          Source: muscleandstrength.com
        </a>
      </div>

      <div className="px-6 pb-5 flex gap-3">
        <button
          onClick={onUse}
          className="flex-1 bg-forest-deep text-white font-bold py-3 rounded-xl hover:bg-sprout-dark transition-all shadow text-sm"
        >
          Use This Template
        </button>
      </div>
    </div>
  )
}

// ─── Step editor ──────────────────────────────────────────────────────────────

function StepEditor({
  steps,
  onStepsChange,
}: {
  steps: CustomStep[]
  onStepsChange: (s: CustomStep[]) => void
}) {
  const addStep = () =>
    onStepsChange([...steps, { id: uid(), exercise: '', sets: '3', reps: '10', rest: '60 sec', muscle: '', equipment: '', day: '', note: '' }])

  const removeStep = (id: string) => onStepsChange(steps.filter(s => s.id !== id))
  const patch = (id: string, p: Partial<CustomStep>) =>
    onStepsChange(steps.map(s => (s.id === id ? { ...s, ...p } : s)))

  // Group by day label for display
  const byDay: Record<string, CustomStep[]> = {}
  for (const step of steps) {
    const key = step.day || 'Unassigned'
    if (!byDay[key]) byDay[key] = []
    byDay[key].push(step)
  }

  return (
    <div className="space-y-4">
      {Object.entries(byDay).map(([day, daySteps]) => (
        <div key={day}>
          <p className="text-xs font-semibold text-forest-deep/50 uppercase tracking-wide mb-2 px-1">{day}</p>
          <div className="space-y-2">
            {daySteps.map((step, i) => (
              <div key={step.id} className="bg-mist rounded-xl border border-forest-deep/8 p-3">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-bold text-forest-deep/30">{i + 1}</span>
                  <button type="button" onClick={() => removeStep(step.id)} className="text-red-400 hover:text-red-600 transition-colors">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div className="sm:col-span-2">
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Exercise</label>
                    <input type="text" value={step.exercise} onChange={e => patch(step.id, { exercise: e.target.value })}
                      placeholder="e.g. Barbell Bench Press"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm placeholder-forest-deep/25 focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Sets</label>
                    <input type="text" value={step.sets} onChange={e => patch(step.id, { sets: e.target.value })}
                      placeholder="3"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Reps</label>
                    <input type="text" value={step.reps} onChange={e => patch(step.id, { reps: e.target.value })}
                      placeholder="10–12"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Rest</label>
                    <input type="text" value={step.rest} onChange={e => patch(step.id, { rest: e.target.value })}
                      placeholder="90 sec"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Muscle Group</label>
                    <input type="text" value={step.muscle} onChange={e => patch(step.id, { muscle: e.target.value })}
                      placeholder="Chest"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Equipment</label>
                    <input type="text" value={step.equipment} onChange={e => patch(step.id, { equipment: e.target.value })}
                      placeholder="Barbell"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Workout Day</label>
                    <input type="text" value={step.day} onChange={e => patch(step.id, { day: e.target.value })}
                      placeholder="e.g. Day 1 — Monday"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                  <div className="sm:col-span-2">
                    <label className="block text-xs font-medium text-forest-deep/50 mb-1">Note (optional)</label>
                    <input type="text" value={step.note} onChange={e => patch(step.id, { note: e.target.value })}
                      placeholder="e.g. * Rest-Pause on final set"
                      className="w-full border border-forest-deep/15 rounded-lg px-3 py-2 text-forest-deep text-sm focus:outline-none focus:ring-2 focus:ring-sprout/40 bg-white" />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      <button type="button" onClick={addStep}
        className="w-full border-2 border-dashed border-forest-deep/20 rounded-xl py-3 text-sm font-semibold text-forest-deep/40 hover:border-sprout/50 hover:text-sprout-dark transition-all">
        + Add Exercise
      </button>
    </div>
  )
}

// ─── Main page ────────────────────────────────────────────────────────────────

type View = 'gallery' | 'preview' | 'editor'

export default function WorkoutPresetPage() {
  const router = useRouter()

  const [view, setView] = useState<View>('gallery')
  const [selectedTemplate, setSelectedTemplate] = useState<WorkoutTemplate | null>(null)
  const [presetName, setPresetName] = useState('')
  const [steps, setSteps] = useState<CustomStep[]>([])
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'submitting' | 'done' | 'error'>('idle')
  const [error, setError] = useState('')

  const openPreview = (t: WorkoutTemplate) => {
    setSelectedTemplate(t)
    setView('preview')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const loadIntoEditor = () => {
    if (!selectedTemplate) return
    setPresetName(selectedTemplate.name)
    setSteps(templateToSteps(selectedTemplate))
    setView('editor')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const startFromScratch = () => {
    setSelectedTemplate(null)
    setPresetName('')
    setSteps([{ id: uid(), exercise: '', sets: '3', reps: '10', rest: '60 sec', muscle: '', equipment: '', day: 'Day 1', note: '' }])
    setView('editor')
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!steps.length) { setError('Add at least one exercise.'); return }

    setSubmitStatus('submitting')
    setError('')

    const apiSteps = steps.map((s, i) => ({
      id: s.id,
      title: s.exercise,
      iconCodePoint: ICON_CP,
      order: i,
      stepLabel: `${s.sets} × ${s.reps}`,
      productType: s.muscle,
      productName: s.equipment,
      notes: [s.rest ? `Rest: ${s.rest}` : '', s.note].filter(Boolean).join(' — ') || null,
      plannerDay: s.day || null,
    }))

    try {
      await backendClientFetch('/action-templates/submit', {
        method: 'POST',
        body: JSON.stringify({
          name: presetName || 'My Workout Plan',
          category: 'workout',
          schemaVersion: 2,
          templateVersion: 1,
          steps: apiSteps,
          metadata: {
            basedOn: selectedTemplate?.id ?? null,
            source: selectedTemplate?.source ?? null,
            level: selectedTemplate?.level ?? 'Custom',
            goal: selectedTemplate?.goal ?? '',
          },
        }),
      })
      setSubmitStatus('done')
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Submission failed')
      setSubmitStatus('error')
    }
  }

  // ── Submitted state ──
  if (submitStatus === 'done') {
    return (
      <div className="max-w-xl mx-auto px-4 sm:px-6 py-20 text-center">
        <div className="w-16 h-16 bg-sprout/15 rounded-2xl flex items-center justify-center mx-auto mb-5">
          <svg className="w-8 h-8 text-sprout-dark" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
        </div>
        <h1 className="text-2xl font-extrabold text-forest-deep mb-2">Submitted for Review!</h1>
        <p className="text-forest-deep/50 text-sm mb-8">Your workout preset will be reviewed before being published to the community.</p>
        <div className="flex gap-3 justify-center">
          <button onClick={() => { setSubmitStatus('idle'); setView('gallery') }}
            className="px-5 py-2.5 border border-forest-deep/20 rounded-xl text-sm font-semibold text-forest-deep hover:bg-mist transition-all">
            Back to Templates
          </button>
          <button onClick={() => router.push('/presets')}
            className="px-5 py-2.5 bg-forest-deep text-white rounded-xl text-sm font-semibold hover:bg-sprout-dark transition-all shadow">
            View My Submissions
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-10">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-xs text-forest-deep/40 mb-6">
        <button onClick={() => { setView('gallery'); setSelectedTemplate(null) }} className="hover:text-forest-deep transition-colors">
          Workout Presets
        </button>
        {view === 'preview' && selectedTemplate && (
          <>
            <span>/</span>
            <span className="text-forest-deep/70">{selectedTemplate.name}</span>
          </>
        )}
        {view === 'editor' && (
          <>
            <span>/</span>
            <span className="text-forest-deep/70">Customize</span>
          </>
        )}
      </div>

      {/* ── Gallery ── */}
      {view === 'gallery' && (
        <div className="space-y-8">
          <div>
            <h1 className="text-2xl font-extrabold text-forest-deep mb-1">Workout Presets</h1>
            <p className="text-forest-deep/50 text-sm">
              Choose a program from{' '}
              <a href="https://www.muscleandstrength.com/workout-routines" target="_blank" rel="noopener noreferrer"
                className="underline hover:text-forest-deep transition-colors">
                Muscle &amp; Strength
              </a>
              , preview the full plan, customize it, and submit it to the community.
            </p>
          </div>

          <div className="space-y-4">
            {TEMPLATES.map(t => {
              const totalExercises = t.workoutDays.reduce((a, d) => a + d.exercises.length, 0)
              return (
                <div key={t.id} className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm hover:shadow-md hover:border-sprout/30 transition-all">
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <h2 className="font-extrabold text-forest-deep text-base">{t.name}</h2>
                        <LevelBadge template={t} />
                      </div>
                      <p className="text-xs text-forest-deep/50">{t.goal}</p>
                    </div>
                  </div>

                  <p className="text-sm text-forest-deep/70 mb-4">{t.description}</p>

                  <div className="flex flex-wrap gap-3 text-xs text-forest-deep/50 mb-4">
                    <span>📅 {t.durationWeeks} weeks</span>
                    <span>·</span>
                    <span>🏋️ {t.daysPerWeek} days/week</span>
                    <span>·</span>
                    <span>⏱ {t.timePerSession}</span>
                    <span>·</span>
                    <span>💪 {totalExercises} exercises total</span>
                  </div>

                  <div className="flex flex-wrap gap-1.5 mb-4">
                    {t.equipment.map(eq => (
                      <span key={eq} className="text-xs px-2.5 py-1 bg-mist border border-forest-deep/10 rounded-full text-forest-deep/60 font-medium">{eq}</span>
                    ))}
                  </div>

                  <div className="flex gap-2">
                    <button
                      onClick={() => openPreview(t)}
                      className="flex-1 bg-forest-deep text-white font-semibold py-2.5 rounded-xl hover:bg-sprout-dark transition-all text-sm shadow"
                    >
                      Preview Full Plan
                    </button>
                  </div>
                </div>
              )
            })}
          </div>

          <div className="border-t border-forest-deep/10 pt-6">
            <h2 className="font-bold text-forest-deep mb-1">Build Your Own</h2>
            <p className="text-sm text-forest-deep/50 mb-4">Create a custom workout preset from scratch and submit it for the community.</p>
            <button
              onClick={startFromScratch}
              className="inline-flex items-center gap-2 border-2 border-forest-deep/20 text-forest-deep font-semibold px-5 py-2.5 rounded-xl hover:bg-mist transition-all text-sm"
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Start from Scratch
            </button>
          </div>
        </div>
      )}

      {/* ── Plan Preview ── */}
      {view === 'preview' && selectedTemplate && (
        <div className="space-y-4">
          <button onClick={() => setView('gallery')} className="flex items-center gap-1 text-sm text-forest-deep/50 hover:text-forest-deep transition-colors">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
            </svg>
            Back to templates
          </button>
          <PlanPreview template={selectedTemplate} onUse={loadIntoEditor} />
        </div>
      )}

      {/* ── Editor ── */}
      {view === 'editor' && (
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-extrabold text-forest-deep mb-1">
                {selectedTemplate ? 'Customize Template' : 'Build from Scratch'}
              </h1>
              {selectedTemplate && (
                <p className="text-sm text-forest-deep/50">Based on: <span className="font-medium">{selectedTemplate.name}</span></p>
              )}
            </div>
            <button type="button" onClick={() => setView(selectedTemplate ? 'preview' : 'gallery')}
              className="text-sm text-forest-deep/50 hover:text-forest-deep transition-colors shrink-0 mt-1">
              ← Back
            </button>
          </div>

          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5">Plan Name <span className="text-red-500">*</span></label>
            <input type="text" required value={presetName} onChange={e => setPresetName(e.target.value)}
              placeholder="e.g. My 8-Week Hypertrophy Plan"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout bg-white" />
          </div>

          <div>
            <div className="flex items-center justify-between mb-3">
              <label className="text-sm font-semibold text-forest-deep">Exercises <span className="text-red-500">*</span></label>
              <span className="text-xs text-forest-deep/40">{steps.length} exercise{steps.length !== 1 ? 's' : ''}</span>
            </div>
            <StepEditor steps={steps} onStepsChange={setSteps} />
          </div>

          {error && (
            <p className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-4 py-3">{error}</p>
          )}

          <div className="flex gap-3 pb-4">
            <button type="button" onClick={() => setView(selectedTemplate ? 'preview' : 'gallery')}
              className="flex-1 border border-forest-deep/20 text-forest-deep font-semibold py-3 rounded-xl hover:bg-forest-deep/5 transition-all text-sm">
              Cancel
            </button>
            <button type="submit" disabled={submitStatus === 'submitting'}
              className="flex-1 bg-forest-deep text-white font-bold py-3 rounded-xl hover:bg-sprout-dark transition-all disabled:opacity-60 disabled:cursor-not-allowed shadow text-sm">
              {submitStatus === 'submitting' ? 'Submitting…' : 'Submit for Review'}
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
