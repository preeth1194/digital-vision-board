import Image from 'next/image'
import Link from 'next/link'
import type { Metadata } from 'next'
import { APP_NAME, APP_STORE_URL, PLAY_STORE_URL } from '@/lib/constants'

export const metadata: Metadata = {
  title: 'Create Account',
  robots: { index: false },
}

export default function SignUpPage() {
  return (
    <div className="min-h-[calc(100vh-8rem)] flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm text-center">
        <Image
          src="/app-icon.png"
          alt={APP_NAME}
          width={56}
          height={56}
          className="rounded-2xl shadow-md mx-auto mb-6"
        />
        <h1 className="text-2xl font-extrabold text-forest-deep mb-2">Get started on the app</h1>
        <p className="text-forest-deep/55 text-sm leading-relaxed mb-8">
          Web account creation is not available yet. Download the {APP_NAME} app to create your free account on iOS or Android.
        </p>
        <div className="flex flex-col gap-3">
          <a
            href={APP_STORE_URL}
            className="flex items-center justify-center gap-2 bg-forest-deep text-white font-semibold py-3 rounded-xl hover:bg-sprout-dark transition-all shadow text-sm"
          >
            Download on the App Store
          </a>
          <a
            href={PLAY_STORE_URL}
            className="flex items-center justify-center gap-2 border border-forest-deep/20 text-forest-deep font-semibold py-3 rounded-xl hover:bg-forest-deep/5 transition-all text-sm"
          >
            Get it on Google Play
          </a>
        </div>
        <p className="mt-6 text-xs text-forest-deep/35">
          <Link href="/" className="hover:text-sprout-dark transition-colors">Back to home</Link>
        </p>
      </div>
    </div>
  )
}
