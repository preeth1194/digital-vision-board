'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { APP_NAME } from '@/lib/constants'
import { backendClientFetch, setDvTokenCookie } from '@/lib/backend/client'
import { firebaseAuth } from '@/lib/firebase/client'
import { createUserWithEmailAndPassword } from 'firebase/auth'

type ExchangeResponse = {
  ok: boolean
  dvToken: string
  userId: string
}

export default function SignUpPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const cred = await createUserWithEmailAndPassword(firebaseAuth, email, password)
      const idToken = await cred.user.getIdToken()
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
      router.push('/profile')
      router.refresh()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Sign up failed')
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
          <h1 className="text-2xl font-extrabold text-forest-deep">Create your account</h1>
          <p className="text-forest-deep/50 text-sm mt-1">Start your journey with {APP_NAME}</p>
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
              minLength={6}
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="At least 6 characters"
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
            {loading ? 'Creating account…' : 'Create Account'}
          </button>
        </form>

        <p className="text-center text-sm text-forest-deep/60 mt-5">
          Already have an account?{' '}
          <Link href="/sign-in" className="text-sprout-dark font-semibold hover:underline">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  )
}
