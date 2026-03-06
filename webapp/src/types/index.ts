export type PresetCategory = 'skincare' | 'workout' | 'meal_prep' | 'recipe'
export type PresetStatus = 'submitted' | 'approved' | 'rejected' | 'draft'

export interface HabitActionStep {
  id: string
  title: string
  iconCodePoint: number
  order: number
  stepLabel?: string | null
  productType?: string | null
  productName?: string | null
  notes?: string | null
  plannerDay?: string | null
  plannerWeek?: number | null
}

export interface UserSettings {
  home_timezone?: string | null
  gender?: string | null
  display_name?: string | null
  weight_kg?: number | null
  height_cm?: number | null
  date_of_birth?: string | null
  subscription_plan_id?: string | null
  subscription_active?: boolean | null
  subscription_source?: string | null
}

export interface ActionTemplate {
  id: string
  name: string
  category: PresetCategory
  schemaVersion?: number
  templateVersion?: number
  status: PresetStatus
  isOfficial?: boolean
  setKey?: string | null
  steps: HabitActionStep[]
  metadata?: Record<string, unknown>
  createdByUserId?: string | null
  reviewedBy?: string | null
  reviewedAt?: string | null
  reviewNotes?: string | null
  updatedAt?: string | null
}

export interface ContactMessage {
  name: string
  email: string
  message: string
}
