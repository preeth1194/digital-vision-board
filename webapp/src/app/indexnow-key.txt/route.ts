import { getSiteUrl } from '@/lib/seo'

export const dynamic = 'force-static'

export async function GET() {
  const key = (process.env.INDEXNOW_KEY ?? '').trim()
  if (!key) {
    return new Response('INDEXNOW_KEY is not configured.\n', {
      status: 503,
      headers: { 'content-type': 'text/plain; charset=utf-8' },
    })
  }

  const keyLocation = (process.env.INDEXNOW_KEY_LOCATION ?? `${getSiteUrl()}/indexnow-key.txt`).trim()
  const body = `${key}\n${keyLocation}\n`

  return new Response(body, {
    headers: { 'content-type': 'text/plain; charset=utf-8' },
  })
}
