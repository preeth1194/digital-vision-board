'use client'

import { useRouter } from 'next/navigation'
import { clearDvTokenCookie } from '@/lib/backend/client'
import { firebaseAuth } from '@/lib/firebase/client'
import { signOut } from 'firebase/auth'

export default function SignOutButton() {
  const router = useRouter()

  const handleSignOut = async () => {
    try {
      await signOut(firebaseAuth)
    } catch {
      // Ignore local firebase signout errors and clear session anyway.
    }
    clearDvTokenCookie()
    router.push('/')
    router.refresh()
  }

  return (
    <button
      onClick={handleSignOut}
      className="text-sm text-mist/60 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/10 transition-all"
    >
      Sign Out
    </button>
  )
}
