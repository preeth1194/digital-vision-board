import Link from 'next/link'
import Image from 'next/image'
import { APP_NAME } from '@/lib/constants'
import SignOutButton from './SignOutButton'
import { backendServerFetch } from '@/lib/backend/server'

type MeResponse = {
  ok: boolean
  userId?: string | null
  isAdmin?: boolean
}

export default async function Header() {
  let me: MeResponse | null = null
  try {
    me = await backendServerFetch<MeResponse>('/auth/me')
  } catch {
    me = null
  }

  const userLoggedIn = Boolean(me?.ok)
  const isAdmin = Boolean(me?.isAdmin)

  return (
    <header className="sticky top-0 z-50 bg-forest-deep/95 backdrop-blur border-b border-sprout/20">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2 group">
          <Image
            src="/app-icon.png"
            alt={APP_NAME}
            width={36}
            height={36}
            className="rounded-xl shadow-md"
          />
          <span className="font-bold text-white text-lg leading-tight hidden sm:block group-hover:text-sprout transition-colors">
            {APP_NAME}
          </span>
        </Link>

        <nav className="flex items-center gap-1 sm:gap-2">
          {userLoggedIn ? (
            <>
              <Link
                href="/presets"
                className="text-sm text-mist/80 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/10 transition-all"
              >
                Presets
              </Link>
              {isAdmin && (
                <Link
                  href="/admin/contact"
                  className="text-sm text-sprout hover:text-sprout-light px-3 py-1.5 rounded-lg hover:bg-white/10 transition-all"
                >
                  Admin
                </Link>
              )}
              <Link
                href="/profile"
                className="text-sm text-mist/80 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/10 transition-all"
              >
                Profile
              </Link>
              <SignOutButton />
            </>
          ) : (
            <>
              <Link
                href="/sign-in"
                className="text-sm text-mist/80 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/10 transition-all"
              >
                Sign In
              </Link>
              <Link
                href="/sign-up"
                className="text-sm bg-sprout text-forest-deep font-semibold px-4 py-1.5 rounded-lg hover:bg-sprout-light transition-all shadow"
              >
                Sign Up
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  )
}
