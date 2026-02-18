// Square Webhook: receives item availability changes (stock events)
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { pauseUberItem } from '@/lib/uber'
import crypto from 'crypto'

export async function POST(req: NextRequest) {
  const body = await req.text()
  const signature = req.headers.get('x-square-hmacsha256-signature') || ''
  const sigKey = process.env.SQUARE_WEBHOOK_SIGNATURE_KEY || ''

  // Verify signature
  if (sigKey) {
    const url = process.env.NEXTAUTH_URL + '/api/webhooks/square'
    const hmac = crypto.createHmac('sha256', sigKey).update(url + body).digest('base64')
    if (hmac !== signature) {
      return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
    }
  }

  const event = JSON.parse(body)
  const eventType: string = event.type || ''

  await prisma.webhookLog.create({
    data: {
      source: 'square',
      eventType,
      payload: body,
    },
  })

  // Handle item count changes (out of stock)
  if (eventType === 'inventory.count.updated') {
    const counts = event.data?.object?.inventory_counts || []
    for (const count of counts) {
      if (count.state === 'IN_STOCK' || count.state === 'SOLD') {
        const catalogObjectId = count.catalog_object_id
        const quantity = parseInt(count.quantity || '0')
        const isAvailable = quantity > 0

        const item = await prisma.menuItem.findUnique({
          where: { squareItemId: catalogObjectId },
        })

        if (item) {
          await prisma.menuItem.update({
            where: { id: item.id },
            data: { squareIsAvailable: isAvailable },
          })

          // Auto-pause on Uber if feature enabled
          if (item.uberItemId && item.uberSynced) {
            // Get any user with settings (first admin user)
            const settings = await prisma.settings.findFirst({
              where: { autoSyncStock: true },
            })
            if (settings) {
              try {
                await pauseUberItem(settings.userId, item.uberItemId, !isAvailable)
              } catch (e) {
                console.error('Failed to pause Uber item:', e)
              }
            }
          }
        }
      }
    }
  }

  await prisma.webhookLog.updateMany({
    where: { source: 'square', eventType, processed: false },
    data: { processed: true },
  })

  return NextResponse.json({ ok: true })
}
