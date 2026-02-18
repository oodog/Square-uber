'use client'

import { useState, useEffect, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Icons } from '@/components/ui/icons'
import { formatPrice, formatDateTime } from '@/lib/utils'

interface Order {
  id: string
  uberOrderId: string
  uberCustomerName: string
  squareOrderId?: string
  status: string
  totalAmount: number
  createdAt: string
  items: { name: string; quantity: number; unitPrice: number }[]
}

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  accepted: 'bg-blue-100 text-blue-800',
  completed: 'bg-green-100 text-green-800',
  cancelled: 'bg-red-100 text-red-800',
  failed: 'bg-red-100 text-red-800',
}

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [expanded, setExpanded] = useState<string | null>(null)

  const fetchOrders = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/orders')
      const data = await res.json()
      setOrders(data.orders || [])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { fetchOrders() }, [fetchOrders])

  const filtered = orders.filter(o =>
    o.uberCustomerName.toLowerCase().includes(search.toLowerCase()) ||
    o.uberOrderId.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Order History</h1>
          <p className="text-slate-500 text-sm mt-1">Uber Eats orders bridged to Square</p>
        </div>
        <Button variant="outline" onClick={fetchOrders} size="sm">
          <Icons.refresh className="mr-2 h-4 w-4" />
          Refresh
        </Button>
      </div>

      <Input
        placeholder="Search by customer name or order ID..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="max-w-sm"
      />

      {loading ? (
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="h-20 bg-slate-100 animate-pulse rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <Card className="py-16">
          <CardContent className="text-center">
            <Icons.shoppingBag className="h-12 w-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-500 font-medium">No orders yet</p>
            <p className="text-slate-400 text-sm mt-1">
              Uber Eats orders will appear here when accepted in the kitchen
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-3">
          {filtered.map(order => (
            <Card key={order.id} className="border-slate-200 hover:border-slate-300 transition-colors">
              <CardContent className="p-4">
                <div
                  className="flex items-center justify-between cursor-pointer"
                  onClick={() => setExpanded(expanded === order.id ? null : order.id)}
                >
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 rounded-full bg-[#06C167]/10 flex items-center justify-center">
                      <Icons.user className="h-5 w-5 text-[#06C167]" />
                    </div>
                    <div>
                      <p className="font-semibold text-slate-900">
                        UBER – {order.uberCustomerName}
                      </p>
                      <p className="text-xs text-slate-400">
                        {order.uberOrderId} · {formatDateTime(order.createdAt)}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full capitalize ${STATUS_COLORS[order.status] || 'bg-slate-100 text-slate-600'}`}>
                      {order.status}
                    </span>
                    <span className="font-bold text-slate-900">{formatPrice(order.totalAmount)}</span>
                    {order.squareOrderId
                      ? <Badge className="bg-slate-100 text-slate-700 text-xs">✓ Square</Badge>
                      : <Badge variant="destructive" className="text-xs">No Square</Badge>
                    }
                    <Icons.chevronDown className={`h-4 w-4 text-slate-400 transition-transform ${expanded === order.id ? 'rotate-180' : ''}`} />
                  </div>
                </div>

                {expanded === order.id && (
                  <div className="mt-4 pt-4 border-t border-slate-100">
                    <h4 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">Items</h4>
                    <div className="space-y-1">
                      {order.items.map((item, idx) => (
                        <div key={idx} className="flex justify-between text-sm">
                          <span className="text-slate-700">{item.quantity}× {item.name}</span>
                          <span className="text-slate-500">{formatPrice(item.unitPrice * item.quantity)}</span>
                        </div>
                      ))}
                    </div>
                    {order.squareOrderId && (
                      <p className="text-xs text-slate-400 mt-3">Square Order: {order.squareOrderId}</p>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
