import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { DV_TOKEN_COOKIE } from '@/lib/session'

export async function POST(request: NextRequest) {
  const response = NextResponse.redirect(new URL('/', request.url))
  response.cookies.set(DV_TOKEN_COOKIE, '', {
    path: '/',
    expires: new Date(0),
    sameSite: 'lax',
  })
  return response
}
