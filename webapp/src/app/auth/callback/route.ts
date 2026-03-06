import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const next = requestUrl.searchParams.get('next') ?? '/profile'
  return NextResponse.redirect(new URL(next, requestUrl.origin))
}
