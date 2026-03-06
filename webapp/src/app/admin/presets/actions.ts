'use server'

import { cookies } from 'next/headers'
import { revalidatePath } from 'next/cache'
import { DV_TOKEN_COOKIE, getBackendBaseUrl } from '@/lib/session'

async function backendAdminPost(path: string, body: Record<string, unknown>) {
  const token = cookies().get(DV_TOKEN_COOKIE)?.value
  if (!token) throw new Error('Unauthorized')

  const response = await fetch(`${getBackendBaseUrl()}${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
    cache: 'no-store',
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(text || 'Action failed')
  }

  return response.json()
}

export async function approvePreset(presetId: string) {
  await backendAdminPost(`/action-templates/${encodeURIComponent(presetId)}/review`, {
    status: 'approved',
  })
  revalidatePath('/admin/presets')
  revalidatePath('/presets')
}

export async function rejectPreset(presetId: string, reviewNotes: string | null) {
  await backendAdminPost(`/action-templates/${encodeURIComponent(presetId)}/review`, {
    status: 'rejected',
    reviewNotes: reviewNotes || null,
  })
  revalidatePath('/admin/presets')
  revalidatePath('/presets')
}
