import { initializeApp, getApps, getApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCCXvAbvOhPLjje6DfrO43-jiupGwh-Lao',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? 'seerohabitseeding.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'seerohabitseeding',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ?? 'seerohabitseeding.firebasestorage.app',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID ?? '250088132481',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID ?? '1:250088132481:web:58453f7c98fa1ee54c2280',
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID ?? 'G-3Q89HQYGQV',
}

const app = getApps().length ? getApp() : initializeApp(firebaseConfig)

export const firebaseAuth = getAuth(app)
