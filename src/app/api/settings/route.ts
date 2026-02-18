import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const settings = await prisma.settings.findUnique({
    where: { userId: session.user.id },
    select: {
      squareAccessToken: true,
      squareLocationId: true,
      squareEnvironment: true,
      uberClientId: true,
      uberClientSecret: true,
      uberStoreId: true,
      markupType: true,
      markupValue: true,
      autoSyncStock: true,
      autoSyncHours: true,
      syncImages: true,
    },
  })

  // Mask tokens partially
  const masked = settings ? {
    ...settings,
    squareAccessToken: settings.squareAccessToken
      ? settings.squareAccessToken.slice(0, 8) + '••••••••'
      : '',
    uberClientSecret: settings.uberClientSecret
      ? settings.uberClientSecret.slice(0, 8) + '••••••••'
      : '',
  } : null

  return NextResponse.json({ settings: masked })
}

export async function PUT(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const body = await req.json()

  // Only update token fields if they don't contain mask characters
  const updateData: Record<string, unknown> = {
    squareLocationId: body.squareLocationId,
    squareEnvironment: body.squareEnvironment,
    uberClientId: body.uberClientId,
    uberStoreId: body.uberStoreId,
    markupType: body.markupType,
    markupValue: parseFloat(body.markupValue),
    autoSyncStock: body.autoSyncStock,
    autoSyncHours: body.autoSyncHours,
    syncImages: body.syncImages,
  }

  if (body.squareAccessToken && !body.squareAccessToken.includes('••••')) {
    updateData.squareAccessToken = body.squareAccessToken
  }
  if (body.uberClientSecret && !body.uberClientSecret.includes('••••')) {
    updateData.uberClientSecret = body.uberClientSecret
  }

  await prisma.settings.upsert({
    where: { userId: session.user.id },
    create: { userId: session.user.id, ...updateData },
    update: updateData,
  })

  return NextResponse.json({ ok: true })
}
