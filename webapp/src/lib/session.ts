export const DV_TOKEN_COOKIE = 'dv_token'

export function getBackendBaseUrl() {
  const base = process.env.NEXT_PUBLIC_BACKEND_URL ?? process.env.BACKEND_URL
  if (!base) {
    throw new Error('Missing backend URL. Set NEXT_PUBLIC_BACKEND_URL in webapp env.')
  }
  return base.replace(/\/$/, '')
}
