export const DEFAULT_SITE_URL = 'https://habitseeding.com'

export const CRAWLABLE_PATHS = [
  '/',
  '/contact',
  '/privacy-policy',
  '/terms',
] as const

export function getSiteUrl(): string {
  const raw = process.env.NEXT_PUBLIC_SITE_URL?.trim() || DEFAULT_SITE_URL
  return raw.replace(/\/+$/, '')
}

export function getSiteHost(): string {
  return new URL(getSiteUrl()).host
}
