import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { syncMenuItemToUber } from '@/lib/uber'
import { calcAdjustedPrice, decimalToCents } from '@/lib/utils'

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { itemIds, globalMarkup } = await req.json()
  if (!itemIds?.length) return NextResponse.json({ error: 'No items selected' }, { status: 400 })

  const items = await prisma.menuItem.findMany({
    where: { id: { in: itemIds } },
  })

  let synced = 0
  const errors: string[] = []

  for (const item of items) {
    try {
      let adjustedPrice: number

      if (item.customMarkupType === 'manual' && item.adjustedPrice != null) {
        // Use the manually set price
        adjustedPrice = item.adjustedPrice
      } else if (item.customMarkupType != null && item.customMarkupValue != null) {
        // Use item-specific % or fixed markup
        adjustedPrice = calcAdjustedPrice(item.squarePrice, item.customMarkupType as 'percent' | 'fixed', item.customMarkupValue)
      } else {
        // Fall back to the global markup sent from the UI
        const gm = globalMarkup || { type: 'percent', value: 30 }
        adjustedPrice = calcAdjustedPrice(item.squarePrice, gm.type, gm.value)
      }

      const priceCents = decimalToCents(adjustedPrice)

      const uberItemId = await syncMenuItemToUber(session.user!.id, {
        squareItemId: item.squareItemId,
        name: item.squareName,
        description: item.squareDesc,
        priceCents,
        imageUrl: item.squareImageUrl,
        category: item.squareCategoryName,
      })

      await prisma.menuItem.update({
        where: { id: item.id },
        data: {
          uberItemId,
          uberSynced: true,
          uberLastSynced: new Date(),
          adjustedPrice,
        },
      })

      synced++
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Unknown error'
      errors.push(`${item.squareName}: ${msg}`)
    }
  }

  await prisma.syncLog.create({
    data: {
      type: 'menu',
      status: errors.length === 0 ? 'success' : synced > 0 ? 'partial' : 'failed',
      itemsSynced: synced,
      message: errors.length > 0 ? errors.join('; ') : `${synced} items synced to Uber Eats`,
    },
  })

  return NextResponse.json({ ok: true, synced, errors })
}
