import { initializeApp, getApps, getApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const fromEnv = (key: string, fallback: string) => {
  const value = process.env[key]
  return value && value.trim().length > 0 ? value : fallback
}

const firebaseConfig = {
  apiKey: fromEnv('NEXT_PUBLIC_FIREBASE_API_KEY', 'AIzaSyCCXvAbvOhPLjje6DfrO43-jiupGwh-Lao'),
  authDomain: fromEnv('NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN', 'seerohabitseeding.firebaseapp.com'),
  projectId: fromEnv('NEXT_PUBLIC_FIREBASE_PROJECT_ID', 'seerohabitseeding'),
  storageBucket: fromEnv('NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET', 'seerohabitseeding.firebasestorage.app'),
  messagingSenderId: fromEnv('NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID', '250088132481'),
  appId: fromEnv('NEXT_PUBLIC_FIREBASE_APP_ID', '1:250088132481:web:58453f7c98fa1ee54c2280'),
  measurementId: fromEnv('NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID', 'G-3Q89HQYGQV'),
}

const app = getApps().length ? getApp() : initializeApp(firebaseConfig)

export const firebaseAuth = getAuth(app)
