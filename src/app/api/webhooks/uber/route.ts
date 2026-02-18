// Uber Eats Webhook: receives new orders
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createSquareOrderFromUber } from '@/lib/square'
import crypto from 'crypto'

export async function POST(req: NextRequest) {
  const body = await req.text()
  const signature = req.headers.get('x-uber-signature') || ''
  const webhookSecret = process.env.UBER_WEBHOOK_SECRET || ''

  // Verify Uber webhook signature
  if (webhookSecret) {
    const hmac = crypto.createHmac('sha256', webhookSecret).update(body).digest('hex')
    if (hmac !== signature) {
      return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
    }
  }

  const event = JSON.parse(body)
  const eventType: string = event.event_type || ''
  const orderId: string = event.order_id || event.meta?.order_id || ''

  await prisma.webhookLog.create({
    data: {
      source: 'uber',
      eventType,
      payload: body,
    },
  })

  // New order placed on Uber Eats
  if (eventType === 'orders.order.scheduled' || eventType === 'orders.order.upcoming' || eventType === 'eats.order') {
    const orderData = event.order || event.data?.order || {}
    const customerName = orderData.eater?.name
      || orderData.consumer?.name
      || 'Uber Customer'

    const items = (orderData.cart?.items || orderData.items || []).map((item: Record<string, unknown>) => ({
      name: (item.title as string | Record<string, string>)?.toString?.() || String(item.title || 'Item'),
      quantity: parseInt(String(item.quantity || 1)),
      unitPrice: parseInt(String(item.price || 0)), // in cents from Uber
    }))

    const totalCents = parseInt(String(orderData.payment?.charges?.total?.amount || 0))

    // Save order to DB
    const dbOrder = await prisma.order.create({
      data: {
        uberOrderId: orderId,
        uberCustomerName: customerName,
        status: 'pending',
        totalAmount: totalCents / 100,
        rawUberPayload: body,
        items: {
          create: items.map((i: { name: string; quantity: number; unitPrice: number }) => ({
            name: i.name,
            quantity: i.quantity,
            unitPrice: i.unitPrice / 100,
          })),
        },
      },
    })

    // Create Square order automatically
    try {
      const settings = await prisma.settings.findFirst()
      if (settings) {
        const squareOrder = await createSquareOrderFromUber(
          settings.userId,
          customerName,
          items.map((i: { name: string; quantity: number; unitPrice: number }) => ({
            ...i,
            unitPriceCents: i.unitPrice,
          })),
          orderId
        )

        await prisma.order.update({
          where: { id: dbOrder.id },
          data: {
            squareOrderId: squareOrder?.id,
            status: 'accepted',
          },
        })
      }
    } catch (e) {
      console.error('Failed to create Square order:', e)
      await prisma.order.update({
        where: { id: dbOrder.id },
        data: { status: 'failed' },
      })
    }
  }

  if (eventType === 'orders.order.cancel_order') {
    const orderId2 = event.order_id || event.meta?.order_id
    if (orderId2) {
      await prisma.order.updateMany({
        where: { uberOrderId: orderId2 },
        data: { status: 'cancelled' },
      })
    }
  }

  await prisma.webhookLog.updateMany({
    where: { source: 'uber', processed: false },
    data: { processed: true },
  })

  return NextResponse.json({ ok: true })
}
