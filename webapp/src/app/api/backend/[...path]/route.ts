import { NextRequest, NextResponse } from 'next/server'

function resolveBackendBaseUrl() {
  const base = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_BACKEND_URL
  if (!base || base.trim().length === 0) {
    throw new Error('Missing BACKEND_URL/NEXT_PUBLIC_BACKEND_URL for backend proxy.')
  }
  return base.replace(/\/$/, '')
}

async function proxyToBackend(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  try {
    const backendBase = resolveBackendBaseUrl()
    const incomingUrl = new URL(req.url)
    const joinedPath = ctx.params.path.join('/')
    const targetUrl = new URL(`${backendBase}/${joinedPath}`)
    incomingUrl.searchParams.forEach((value, key) => {
      targetUrl.searchParams.append(key, value)
    })

    const headers = new Headers()
    const auth = req.headers.get('authorization')
    if (auth) headers.set('authorization', auth)
    const contentType = req.headers.get('content-type')
    if (contentType) headers.set('content-type', contentType)

    const method = req.method.toUpperCase()
    const hasBody = !['GET', 'HEAD'].includes(method)
    const upstream = await fetch(targetUrl, {
      method,
      headers,
      body: hasBody ? await req.text() : undefined,
      cache: 'no-store',
    })

    const text = await upstream.text()
    const responseHeaders = new Headers()
    const upstreamType = upstream.headers.get('content-type')
    if (upstreamType) responseHeaders.set('content-type', upstreamType)
    return new NextResponse(text, {
      status: upstream.status,
      headers: responseHeaders,
    })
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Backend proxy failed'
    return NextResponse.json({ ok: false, error: message }, { status: 500 })
  }
}

export async function GET(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  return proxyToBackend(req, ctx)
}

export async function POST(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  return proxyToBackend(req, ctx)
}

export async function PUT(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  return proxyToBackend(req, ctx)
}

export async function PATCH(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  return proxyToBackend(req, ctx)
}

export async function DELETE(
  req: NextRequest,
  ctx: { params: { path: string[] } }
) {
  return proxyToBackend(req, ctx)
}
