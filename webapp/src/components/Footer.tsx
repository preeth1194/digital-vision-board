import Link from 'next/link'
import Image from 'next/image'
import { APP_NAME } from '@/lib/constants'

export default function Footer() {
  return (
    <footer className="bg-forest-deep border-t border-sprout/20 mt-auto">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-10">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-8">
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Image
                src="/app-icon.png"
                alt={APP_NAME}
                width={28}
                height={28}
                className="rounded-lg"
              />
              <span className="font-bold text-white">{APP_NAME}</span>
            </div>
            <p className="text-mist/50 text-sm leading-relaxed">
              Grow your life, one habit at a time.
            </p>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-3 text-sm uppercase tracking-wide">
              Legal
            </h4>
            <ul className="space-y-2">
              <li>
                <Link
                  href="/privacy-policy"
                  className="text-mist/60 hover:text-sprout text-sm transition-colors"
                >
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link
                  href="/terms"
                  className="text-mist/60 hover:text-sprout text-sm transition-colors"
                >
                  Terms &amp; Conditions
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-3 text-sm uppercase tracking-wide">
              Account
            </h4>
            <ul className="space-y-2">
              <li>
                <Link
                  href="/contact"
                  className="text-mist/60 hover:text-sprout text-sm transition-colors"
                >
                  Contact Us
                </Link>
              </li>
              <li>
                <Link href="/faq" className="text-mist/60 hover:text-sprout text-sm transition-colors">
                  FAQ
                </Link>
              </li>
              <li>
                <Link
                  href="/sign-in"
                  className="text-mist/60 hover:text-sprout text-sm transition-colors"
                >
                  Sign In
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t border-sprout/10 flex flex-col sm:flex-row items-center justify-between gap-3">
          <p className="text-mist/40 text-sm">
            &copy; {new Date().getFullYear()} {APP_NAME}. All rights reserved.
          </p>
          <p className="text-mist/30 text-xs">
            Made with 🌱 for dreamers and doers
          </p>
        </div>
      </div>
    </footer>
  )
}
