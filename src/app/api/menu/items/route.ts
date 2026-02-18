import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const items = await prisma.menuItem.findMany({
    orderBy: { squareName: 'asc' },
    select: {
      id: true,
      squareItemId: true,
      squareName: true,
      squareDesc: true,
      squarePrice: true,
      squareImageUrl: true,
      squareCategoryName: true,
      squareIsAvailable: true,
      uberItemId: true,
      uberSynced: true,
      uberLastSynced: true,
      customMarkupType: true,
      customMarkupValue: true,
      adjustedPrice: true,
    },
  })

  return NextResponse.json({
    items: items.map(i => ({
      id: i.id,
      squareItemId: i.squareItemId,
      name: i.squareName,
      description: i.squareDesc,
      price: i.squarePrice,
      imageUrl: i.squareImageUrl,
      category: i.squareCategoryName,
      isAvailable: i.squareIsAvailable,
      uberItemId: i.uberItemId,
      uberSynced: i.uberSynced,
      uberLastSynced: i.uberLastSynced,
      customMarkupType: i.customMarkupType,
      customMarkupValue: i.customMarkupValue,
      adjustedPrice: i.adjustedPrice,
    })),
  })
}

// Save a per-item manual price override (or clear it)
export async function PATCH(request: Request) {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { id, manualPrice } = await request.json()
  if (!id) return NextResponse.json({ error: 'Missing item id' }, { status: 400 })

  await prisma.menuItem.update({
    where: { id },
    data: manualPrice != null
      ? { customMarkupType: 'manual', customMarkupValue: null, adjustedPrice: manualPrice }
      : { customMarkupType: null, customMarkupValue: null, adjustedPrice: null },
  })

  return NextResponse.json({ ok: true })
}
