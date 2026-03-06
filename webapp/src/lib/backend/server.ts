import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { DV_TOKEN_COOKIE, getBackendBaseUrl } from '@/lib/session'

export async function backendServerFetch<T>(
  path: string,
  init: RequestInit = {},
  opts: { auth?: boolean; redirectOnUnauthorized?: boolean } = {
    auth: true,
    redirectOnUnauthorized: false,
  }
): Promise<T> {
  const headers = new Headers(init.headers)

  if (opts.auth !== false) {
    const token = cookies().get(DV_TOKEN_COOKIE)?.value
    if (!token) {
      if (opts.redirectOnUnauthorized) redirect('/sign-in')
      throw new Error('Not authenticated')
    }
    headers.set('authorization', `Bearer ${token}`)
  }

  const response = await fetch(`${getBackendBaseUrl()}${path}`, {
    ...init,
    headers,
    cache: 'no-store',
  })

  if (response.status === 401 && opts.redirectOnUnauthorized) {
    redirect('/sign-in')
  }

  if (!response.ok) {
    const text = await response.text()
    throw new Error(text || `Request failed with ${response.status}`)
  }

  return (await response.json()) as T
}
