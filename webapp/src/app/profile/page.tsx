import type { Metadata } from 'next'
import Link from 'next/link'
import { backendServerFetch } from '@/lib/backend/server'
import EditProfileForm from './EditProfileForm'
import type { UserSettings } from '@/types'

export const metadata: Metadata = {
  title: 'Profile',
}

type MeResponse = {
  ok: boolean
  userId?: string
}

type SettingsResponse = UserSettings & {
  ok?: boolean
}

export default async function ProfilePage() {
  const me = await backendServerFetch<MeResponse>('/auth/me', {}, { redirectOnUnauthorized: true })

  const settings = await backendServerFetch<SettingsResponse>('/user/settings')

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-12">
      <h1 className="text-2xl font-extrabold text-forest-deep mb-1">Your Profile</h1>
      <p className="text-forest-deep/50 text-sm mb-8">User ID: {me.userId}</p>

      <div className="bg-white rounded-2xl shadow-sm border border-forest-deep/10 p-6 mb-6">
        <h2 className="text-sm font-semibold text-forest-deep/50 uppercase tracking-wide mb-4">
          Account Info
        </h2>
        <EditProfileForm initialDisplayName={settings.display_name ?? ''} />
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-forest-deep/10 p-6">
        <h2 className="text-sm font-semibold text-forest-deep/50 uppercase tracking-wide mb-4">
          Quick Links
        </h2>
        <div className="flex flex-col gap-3">
          <Link
            href="/presets"
            className="flex items-center justify-between p-3 rounded-xl bg-mist hover:bg-mist-sky transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 bg-sprout/20 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-sprout-dark" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z" />
                </svg>
              </div>
              <div>
                <div className="text-sm font-semibold text-forest-deep">My Presets</div>
                <div className="text-xs text-forest-deep/50">View your submitted presets</div>
              </div>
            </div>
            <svg className="w-4 h-4 text-forest-deep/30 group-hover:text-forest-deep/60 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </Link>

          <Link
            href="/presets/upload"
            className="flex items-center justify-between p-3 rounded-xl bg-mist hover:bg-mist-sky transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 bg-forest-deep/10 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-forest-deep" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              </div>
              <div>
                <div className="text-sm font-semibold text-forest-deep">Submit a Preset</div>
                <div className="text-xs text-forest-deep/50">Share your habit preset with the community</div>
              </div>
            </div>
            <svg className="w-4 h-4 text-forest-deep/30 group-hover:text-forest-deep/60 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        </div>
      </div>
    </div>
  )
}
