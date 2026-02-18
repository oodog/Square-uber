import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const logs = await prisma.webhookLog.findMany({
    orderBy: { receivedAt: 'desc' },
    take: 100,
    select: {
      id: true,
      source: true,
      eventType: true,
      processed: true,
      error: true,
      receivedAt: true,
    },
  })

  return NextResponse.json({ logs })
}
