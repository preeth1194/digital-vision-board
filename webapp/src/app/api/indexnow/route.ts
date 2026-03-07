import { NextResponse } from 'next/server'
import { CRAWLABLE_PATHS, getSiteHost, getSiteUrl } from '@/lib/seo'

type IndexNowRequest = {
  urls?: string[]
}

function normalizeUrl(raw: string): string | null {
  try {
    const u = new URL(raw)
    const baseHost = getSiteHost()
    if (u.host !== baseHost) return null
    return u.toString()
  } catch {
    return null
  }
}

export async function POST(request: Request) {
  const token = process.env.INDEXNOW_PING_TOKEN?.trim()
  if (!token) {
    return NextResponse.json({ ok: false, error: 'indexnow_token_not_configured' }, { status: 503 })
  }

  const provided = request.headers.get('x-indexnow-token')?.trim()
  if (!provided || provided !== token) {
    return NextResponse.json({ ok: false, error: 'unauthorized' }, { status: 401 })
  }

  const key = process.env.INDEXNOW_KEY?.trim()
  if (!key) {
    return NextResponse.json({ ok: false, error: 'indexnow_key_not_configured' }, { status: 503 })
  }

  let payload: IndexNowRequest = {}
  try {
    payload = (await request.json()) as IndexNowRequest
  } catch {
    payload = {}
  }

  const siteUrl = getSiteUrl()
  const urlListInput = Array.isArray(payload.urls) && payload.urls.length
    ? payload.urls
    : CRAWLABLE_PATHS.map((path) => `${siteUrl}${path}`)

  const urlSet = new Set<string>()
  for (const rawUrl of urlListInput) {
    const normalized = normalizeUrl(rawUrl)
    if (normalized) urlSet.add(normalized)
  }
  const urlList = Array.from(urlSet)
  if (!urlList.length) {
    return NextResponse.json({ ok: false, error: 'no_valid_urls' }, { status: 400 })
  }

  const keyLocation = (process.env.INDEXNOW_KEY_LOCATION ?? `${siteUrl}/indexnow-key.txt`).trim()
  const upstream = await fetch('https://api.indexnow.org/indexnow', {
    method: 'POST',
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      host: getSiteHost(),
      key,
      keyLocation,
      urlList,
    }),
    cache: 'no-store',
  })

  if (!upstream.ok) {
    const text = await upstream.text()
    return NextResponse.json(
      {
        ok: false,
        error: 'indexnow_submit_failed',
        upstreamStatus: upstream.status,
        upstreamBody: text,
      },
      { status: 502 }
    )
  }

  return NextResponse.json({ ok: true, submitted: urlList.length })
}
