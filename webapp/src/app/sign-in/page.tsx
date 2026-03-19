'use client'

import { Suspense, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter, useSearchParams } from 'next/navigation'
import { APP_NAME } from '@/lib/constants'
import { backendClientFetch, setDvTokenCookie } from '@/lib/backend/client'
import { firebaseAuth, googleProvider } from '@/lib/firebase/client'
import { signInWithEmailAndPassword, signInWithPopup } from 'firebase/auth'

type ExchangeResponse = {
  ok: boolean
  dvToken: string
  userId: string
}

function SignInPageContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirectTo = searchParams.get('redirectedFrom') ?? '/profile'

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    console.info('[sign-in] Email sign-in started', { redirectTo })

    try {
      const cred = await signInWithEmailAndPassword(firebaseAuth, email, password)
      console.info('[sign-in] Firebase email auth success', {
        uid: cred.user.uid,
        hasEmail: Boolean(cred.user.email),
      })
      const idToken = await cred.user.getIdToken()
      console.info('[sign-in] ID token acquired for email flow')
      const exchange = await backendClientFetch<ExchangeResponse>(
        '/auth/firebase/exchange',
        {
          method: 'POST',
          body: JSON.stringify({ idToken }),
        },
        { auth: false }
      )

      if (!exchange.ok || !exchange.dvToken) {
        throw new Error('Failed to create backend session')
      }

      setDvTokenCookie(exchange.dvToken)
      console.info('[sign-in] Backend token exchange success (email)')
      router.push(redirectTo)
      router.refresh()
    } catch (err: unknown) {
      console.error('[sign-in] Email sign-in failed', err)
      setError(err instanceof Error ? err.message : 'Sign in failed')
      setLoading(false)
    }
  }

  const handleGoogleSignIn = async () => {
    setError('')
    setLoading(true)
    console.info('[sign-in] Google sign-in started', { redirectTo })

    try {
      const cred = await signInWithPopup(firebaseAuth, googleProvider)
      console.info('[sign-in] Firebase Google auth success', {
        uid: cred.user.uid,
        hasEmail: Boolean(cred.user.email),
      })
      const idToken = await cred.user.getIdToken()
      console.info('[sign-in] ID token acquired for Google flow')
      const exchange = await backendClientFetch<ExchangeResponse>(
        '/auth/firebase/exchange',
        {
          method: 'POST',
          body: JSON.stringify({ idToken }),
        },
        { auth: false }
      )

      if (!exchange.ok || !exchange.dvToken) {
        throw new Error('Failed to create backend session')
      }

      setDvTokenCookie(exchange.dvToken)
      console.info('[sign-in] Backend token exchange success (google)')
      router.push(redirectTo)
      router.refresh()
    } catch (err: unknown) {
      console.error('[sign-in] Google sign-in failed', err)
      setError(err instanceof Error ? err.message : 'Google sign in failed')
      setLoading(false)
    }
  }

  return (
    <div className="min-h-[calc(100vh-8rem)] flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <Image
            src="/app-icon.png"
            alt={APP_NAME}
            width={56}
            height={56}
            className="rounded-2xl shadow-md mx-auto mb-4"
          />
          <h1 className="text-2xl font-extrabold text-forest-deep">Welcome back</h1>
          <p className="text-forest-deep/50 text-sm mt-1">Sign in to {APP_NAME}</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 bg-white rounded-2xl shadow-sm border border-forest-deep/10 p-6">
          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-semibold text-forest-deep mb-1.5" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full border border-forest-deep/20 rounded-xl px-4 py-2.5 text-forest-deep placeholder-forest-deep/30 focus:outline-none focus:ring-2 focus:ring-sprout/50 focus:border-sprout text-sm"
            />
          </div>

          {error && (
            <p className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-3 py-2">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-forest-deep text-white font-bold py-2.5 rounded-xl hover:bg-sprout-dark transition-all disabled:opacity-60 disabled:cursor-not-allowed shadow text-sm"
          >
            {loading ? 'Signing in…' : 'Sign In'}
          </button>

          <div className="relative py-1">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-forest-deep/15" />
            </div>
            <div className="relative text-center">
              <span className="bg-white px-3 text-xs text-forest-deep/45">or</span>
            </div>
          </div>

          <button
            type="button"
            onClick={handleGoogleSignIn}
            disabled={loading}
            className="w-full border border-forest-deep/20 text-forest-deep font-semibold py-2.5 rounded-xl hover:bg-forest-deep/5 transition-all disabled:opacity-60 disabled:cursor-not-allowed text-sm"
          >
            Continue with Google
          </button>
        </form>

        <p className="text-center text-sm text-forest-deep/60 mt-5">
          Don&apos;t have an account?{' '}
          <Link href="/sign-up" className="text-sprout-dark font-semibold hover:underline">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  )
}

export default function SignInPage() {
  return (
    <Suspense fallback={<div className="min-h-[calc(100vh-8rem)]" />}>
      <SignInPageContent />
    </Suspense>
  )
}
