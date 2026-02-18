import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { pullMenuFromSquare } from '@/lib/square'
import { prisma } from '@/lib/prisma'

export async function POST() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  try {
    const count = await pullMenuFromSquare(session.user.id)

    await prisma.syncLog.create({
      data: {
        type: 'menu',
        status: 'success',
        itemsSynced: count,
        message: `Pulled ${count} items from Square`,
      },
    })

    return NextResponse.json({ ok: true, count })
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Unknown error'
    await prisma.syncLog.create({
      data: { type: 'menu', status: 'failed', message },
    })
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
