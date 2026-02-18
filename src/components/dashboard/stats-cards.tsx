'use client'

import { useEffect, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { TrendingUp, ShoppingBag, RefreshCw, DollarSign } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface Stats {
  totalOrders: number
  totalRevenue: number
  syncedItems: number
  totalItems: number
}

export function StatsCards() {
  const [stats, setStats] = useState<Stats | null>(null)

  useEffect(() => {
    fetch('/api/dashboard/stats').then(r => r.json()).then(d => setStats(d.stats))
  }, [])

  const cards = [
    {
      label: 'Total Uber Orders',
      value: stats ? stats.totalOrders.toString() : '—',
      icon: ShoppingBag,
      color: 'bg-[#06C167]/10 text-[#06C167]',
      trend: 'All time',
    },
    {
      label: 'Total Revenue',
      value: stats ? formatPrice(stats.totalRevenue) : '—',
      icon: DollarSign,
      color: 'bg-blue-100 text-blue-600',
      trend: 'From Uber orders',
    },
    {
      label: 'Items on Uber Eats',
      value: stats ? `${stats.syncedItems} / ${stats.totalItems}` : '—',
      icon: RefreshCw,
      color: 'bg-amber-100 text-amber-600',
      trend: 'Synced to Uber',
    },
    {
      label: 'Uber Commission',
      value: stats ? formatPrice(stats.totalRevenue * 0.30) : '—',
      icon: TrendingUp,
      color: 'bg-red-100 text-red-600',
      trend: '~30% of revenue',
    },
  ]

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      {cards.map((card) => (
        <Card key={card.label} className="border-slate-200 hover:shadow-md transition-shadow">
          <CardContent className="p-5">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-slate-500 font-medium">{card.label}</p>
              <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${card.color}`}>
                <card.icon className="h-5 w-5" />
              </div>
            </div>
            <p className="text-2xl font-bold text-slate-900">{card.value}</p>
            <p className="text-xs text-slate-400 mt-1">{card.trend}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
