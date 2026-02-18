import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { getSquareClient, getSquareLocationId } from '@/lib/square'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  try {
    const client = await getSquareClient(session.user.id)
    const locationId = await getSquareLocationId(session.user.id)
    if (!locationId) return NextResponse.json({ ok: false, error: 'No location ID configured' }, { status: 400 })
    const response = await client.locations.get({ locationId })
    const location = response.location

    return NextResponse.json({
      ok: true,
      locationName: location?.name || 'Unknown',
      businessName: location?.businessName,
    })
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Connection failed'
    return NextResponse.json({ ok: false, error: message }, { status: 400 })
  }
}
