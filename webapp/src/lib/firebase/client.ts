import { initializeApp, getApps, getApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider } from 'firebase/auth'

const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY?.trim()
const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN?.trim()
const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID?.trim()
const storageBucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET?.trim()
const messagingSenderId =
  process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID?.trim()
const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID?.trim()
const measurementId = process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID?.trim()

const missingKeys = [
  !apiKey && 'NEXT_PUBLIC_FIREBASE_API_KEY',
  !authDomain && 'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
  !projectId && 'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
  !storageBucket && 'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
  !messagingSenderId && 'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
  !appId && 'NEXT_PUBLIC_FIREBASE_APP_ID',
  !measurementId && 'NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID',
].filter(Boolean) as string[]

if (missingKeys.length > 0) {
  console.error('[firebase/client] Missing required env var(s):', missingKeys)
  throw new Error(`Missing required env var(s): ${missingKeys.join(', ')}`)
}

const firebaseConfig = {
  apiKey,
  authDomain,
  projectId,
  storageBucket,
  messagingSenderId,
  appId,
  measurementId,
}

const app = getApps().length ? getApp() : initializeApp(firebaseConfig)
console.info('[firebase/client] Initialized Firebase app', {
  projectId: firebaseConfig.projectId,
  authDomain: firebaseConfig.authDomain,
  appIdSuffix: firebaseConfig.appId!.slice(-8),
})

export const firebaseAuth = getAuth(app)
export const googleProvider = new GoogleAuthProvider()
