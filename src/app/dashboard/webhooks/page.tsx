'use client'

import { useState, useEffect, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Icons } from '@/components/ui/icons'
import { formatDateTime } from '@/lib/utils'

interface WebhookLog {
  id: string
  source: string
  eventType: string
  processed: boolean
  error?: string
  receivedAt: string
}

export default function WebhooksPage() {
  const [logs, setLogs] = useState<WebhookLog[]>([])
  const [loading, setLoading] = useState(true)

  const fetchLogs = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/webhooks/log')
      const data = await res.json()
      setLogs(data.logs || [])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchLogs()
    const interval = setInterval(fetchLogs, 15000)
    return () => clearInterval(interval)
  }, [fetchLogs])

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Activity Log</h1>
          <p className="text-slate-500 text-sm mt-1">Incoming webhooks from Square & Uber Eats (auto-refreshes every 15s)</p>
        </div>
        <Button variant="outline" onClick={fetchLogs} size="sm">
          <Icons.refresh className="mr-2 h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {['uber', 'square'].map(source => {
          const sourceLogs = logs.filter(l => l.source === source)
          return (
            <Card key={source} className="border-slate-200">
              <CardContent className="p-4 text-center">
                <p className="text-2xl font-bold text-slate-900">{sourceLogs.length}</p>
                <p className="text-xs text-slate-500 capitalize">{source} events</p>
              </CardContent>
            </Card>
          )
        })}
        <Card className="border-slate-200">
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-green-600">{logs.filter(l => l.processed).length}</p>
            <p className="text-xs text-slate-500">Processed</p>
          </CardContent>
        </Card>
        <Card className="border-slate-200">
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-red-500">{logs.filter(l => l.error).length}</p>
            <p className="text-xs text-slate-500">Errors</p>
          </CardContent>
        </Card>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[...Array(8)].map((_, i) => <div key={i} className="h-14 bg-slate-100 animate-pulse rounded-lg" />)}
        </div>
      ) : logs.length === 0 ? (
        <Card className="py-16">
          <CardContent className="text-center">
            <Icons.refresh className="h-12 w-12 text-slate-300 mx-auto mb-3" />
            <p className="text-slate-500">No webhook events yet</p>
            <p className="text-slate-400 text-sm mt-1">Configure webhooks in Square & Uber portals pointing to your domain</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2">
          {logs.map(log => (
            <Card key={log.id} className="border-slate-200">
              <CardContent className="py-3 px-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Badge className={log.source === 'uber'
                      ? 'bg-[#06C167]/10 text-[#06C167] border-0 text-xs'
                      : 'bg-slate-100 text-slate-700 border-0 text-xs'}>
                      {log.source.toUpperCase()}
                    </Badge>
                    <span className="text-sm font-mono text-slate-700">{log.eventType}</span>
                    {log.error && (
                      <span className="text-xs text-red-500 truncate max-w-xs">{log.error}</span>
                    )}
                  </div>
                  <div className="flex items-center gap-3">
                    <Badge variant={log.processed ? 'default' : 'outline'} className="text-xs">
                      {log.processed ? '✓ Processed' : 'Pending'}
                    </Badge>
                    <span className="text-xs text-slate-400">{formatDateTime(log.receivedAt)}</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Card className="border-amber-200 bg-amber-50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-amber-800">Webhook URLs to configure</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <div className="text-xs font-mono bg-white rounded border border-amber-200 p-2">
            <p className="text-slate-500 mb-1">Square Dashboard → Webhooks:</p>
            <p className="text-slate-800">https://app.mangkokavenue.com/api/webhooks/square</p>
          </div>
          <div className="text-xs font-mono bg-white rounded border border-amber-200 p-2">
            <p className="text-slate-500 mb-1">Uber Eats Developer Portal → Webhooks:</p>
            <p className="text-slate-800">https://app.mangkokavenue.com/api/webhooks/uber</p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
