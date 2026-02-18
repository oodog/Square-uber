// Uber OAuth redirect handler
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { exchangeUberCode } from '@/lib/uber'

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const code = searchParams.get('code')
  const state = searchParams.get('state') // userId
  const error = searchParams.get('error')

  if (error) {
    return NextResponse.redirect(
      new URL(`/dashboard/settings?uber_error=${encodeURIComponent(error)}`, req.url)
    )
  }

  if (!code || !state) {
    return NextResponse.redirect(new URL('/dashboard/settings?uber_error=missing_params', req.url))
  }

  try {
    await exchangeUberCode(state, code)
    return NextResponse.redirect(new URL('/dashboard/settings?uber_connected=1', req.url))
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'OAuth failed'
    return NextResponse.redirect(
      new URL(`/dashboard/settings?uber_error=${encodeURIComponent(msg)}`, req.url)
    )
  }
}
