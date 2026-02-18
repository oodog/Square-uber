'use client'

import { useEffect, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { formatPrice } from '@/lib/utils'

interface ChartPoint { day: string; orders: number; revenue: number }

export function RevenueChart() {
  const [data, setData] = useState<ChartPoint[]>([])

  useEffect(() => {
    fetch('/api/dashboard/stats').then(r => r.json()).then(d => setData(d.chartData || []))
  }, [])

  return (
    <Card className="border-slate-200">
      <CardHeader className="pb-2">
        <CardTitle className="text-base font-semibold text-slate-900">Orders & Revenue (Last 7 Days)</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={data} margin={{ top: 5, right: 10, left: 10, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis dataKey="day" tick={{ fontSize: 12, fill: '#94a3b8' }} />
            <YAxis yAxisId="left" tick={{ fontSize: 12, fill: '#94a3b8' }} />
            <YAxis yAxisId="right" orientation="right" tick={{ fontSize: 12, fill: '#94a3b8' }}
              tickFormatter={(v) => `$${v}`} />
            <Tooltip
              formatter={(value, name) => [
                name === 'revenue' ? formatPrice(value as number) : value,
                name === 'revenue' ? 'Revenue' : 'Orders',
              ]}
              contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 12 }}
            />
            <Bar yAxisId="left" dataKey="orders" fill="#3b82f6" radius={[4, 4, 0, 0]} name="orders" />
            <Bar yAxisId="right" dataKey="revenue" fill="#06C167" radius={[4, 4, 0, 0]} name="revenue" />
          </BarChart>
        </ResponsiveContainer>
        <div className="flex gap-4 mt-2 justify-center">
          <div className="flex items-center gap-1.5 text-xs text-slate-500">
            <div className="w-3 h-3 rounded bg-blue-500" /><span>Orders</span>
          </div>
          <div className="flex items-center gap-1.5 text-xs text-slate-500">
            <div className="w-3 h-3 rounded bg-[#06C167]" /><span>Revenue</span>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
