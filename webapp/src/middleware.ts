import { NextResponse, type NextRequest } from 'next/server'
import { DV_TOKEN_COOKIE } from '@/lib/session'

const protectedPrefixes = ['/profile', '/presets', '/admin']

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  const isProtected = protectedPrefixes.some((prefix) => pathname.startsWith(prefix))
  const token = request.cookies.get(DV_TOKEN_COOKIE)?.value

  if (isProtected && !token) {
    const redirectUrl = request.nextUrl.clone()
    redirectUrl.pathname = '/sign-in'
    redirectUrl.searchParams.set('redirectedFrom', pathname)
    return NextResponse.redirect(redirectUrl)
  }

  if (pathname.startsWith('/admin') && token) {
    try {
      const base = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_BACKEND_URL
      if (!base) throw new Error('Missing backend URL')
      const meRes = await fetch(`${base.replace(/\/$/, '')}/auth/me`, {
        headers: { authorization: `Bearer ${token}` },
        cache: 'no-store',
      })

      if (!meRes.ok) {
        return NextResponse.redirect(new URL('/sign-in', request.url))
      }

      const me = (await meRes.json()) as { isAdmin?: boolean }
      if (!me.isAdmin) {
        return NextResponse.redirect(new URL('/', request.url))
      }
    } catch {
      return NextResponse.redirect(new URL('/sign-in', request.url))
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
