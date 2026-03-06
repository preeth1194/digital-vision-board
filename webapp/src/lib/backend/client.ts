import { DV_TOKEN_COOKIE, getBackendBaseUrl } from '@/lib/session'

function getCookieValue(name: string): string | null {
  if (typeof document === 'undefined') return null
  const value = document.cookie
    .split('; ')
    .find((entry) => entry.startsWith(`${name}=`))
    ?.split('=')[1]
  return value ? decodeURIComponent(value) : null
}

export async function backendClientFetch<T>(
  path: string,
  init: RequestInit = {},
  opts: { auth?: boolean } = { auth: true }
): Promise<T> {
  const headers = new Headers(init.headers)
  headers.set('content-type', 'application/json')

  if (opts.auth !== false) {
    const token = getCookieValue(DV_TOKEN_COOKIE)
    if (!token) throw new Error('Not authenticated')
    headers.set('authorization', `Bearer ${token}`)
  }

  const response = await fetch(`${getBackendBaseUrl()}${path}`, {
    ...init,
    headers,
    cache: 'no-store',
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(text || `Request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export function setDvTokenCookie(token: string) {
  document.cookie = `${DV_TOKEN_COOKIE}=${encodeURIComponent(token)}; path=/; max-age=${60 * 60 * 24 * 30}; samesite=lax`
}

export function clearDvTokenCookie() {
  document.cookie = `${DV_TOKEN_COOKIE}=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; samesite=lax`
}
