import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session?.user?.id) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const [totalOrders, totalRevenue, syncedItems, totalItems, recentOrders, syncLogs] = await Promise.all([
    prisma.order.count(),
    prisma.order.aggregate({ _sum: { totalAmount: true } }),
    prisma.menuItem.count({ where: { uberSynced: true } }),
    prisma.menuItem.count(),
    prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 7,
      select: { createdAt: true, totalAmount: true, status: true },
    }),
    prisma.syncLog.findMany({ orderBy: { createdAt: 'desc' }, take: 5 }),
  ])

  // Build chart data (last 7 days)
  const now = new Date()
  const chartData = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now)
    d.setDate(d.getDate() - (6 - i))
    const dayStr = d.toLocaleDateString('en-AU', { weekday: 'short' })
    const dayOrders = recentOrders.filter(o => {
      const od = new Date(o.createdAt)
      return od.getDate() === d.getDate() && od.getMonth() === d.getMonth()
    })
    return {
      day: dayStr,
      orders: dayOrders.length,
      revenue: dayOrders.reduce((s, o) => s + o.totalAmount, 0),
    }
  })

  return NextResponse.json({
    stats: {
      totalOrders,
      totalRevenue: totalRevenue._sum.totalAmount || 0,
      syncedItems,
      totalItems,
    },
    chartData,
    syncLogs,
  })
}
