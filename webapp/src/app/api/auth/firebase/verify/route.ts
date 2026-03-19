import { NextRequest, NextResponse } from 'next/server'
import { firebaseAdminAuth } from '@/lib/firebase/admin'

type VerifyBody = {
  idToken?: string
}

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as VerifyBody
    const idToken = body.idToken?.trim()
    if (!idToken) {
      return NextResponse.json(
        { ok: false, error: 'Missing idToken' },
        { status: 400 }
      )
    }

    const decoded = await firebaseAdminAuth.verifyIdToken(idToken)
    return NextResponse.json({
      ok: true,
      uid: decoded.uid,
      email: decoded.email ?? null,
    })
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Token verification failed'
    return NextResponse.json({ ok: false, error: message }, { status: 401 })
  }
}
