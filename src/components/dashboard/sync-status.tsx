'use client'

import { useEffect, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { CheckCircle, XCircle, AlertCircle, Clock } from 'lucide-react'
import { formatDateTime } from '@/lib/utils'

interface SyncLog { id: string; type: string; status: string; itemsSynced: number; message?: string; createdAt: string }

export function SyncStatus() {
  const [logs, setLogs] = useState<SyncLog[]>([])

  useEffect(() => {
    fetch('/api/dashboard/stats').then(r => r.json()).then(d => setLogs(d.syncLogs || []))
  }, [])

  const icon = (status: string) => {
    if (status === 'success') return <CheckCircle className="h-4 w-4 text-[#06C167]" />
    if (status === 'failed') return <XCircle className="h-4 w-4 text-red-500" />
    return <AlertCircle className="h-4 w-4 text-amber-500" />
  }

  return (
    <Card className="border-slate-200">
      <CardHeader className="pb-2">
        <CardTitle className="text-base font-semibold text-slate-900">Sync Activity</CardTitle>
      </CardHeader>
      <CardContent>
        {logs.length === 0 ? (
          <div className="py-8 text-center">
            <Clock className="h-8 w-8 text-slate-300 mx-auto mb-2" />
            <p className="text-sm text-slate-400">No syncs yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {logs.map(log => (
              <div key={log.id} className="flex items-start gap-3 text-sm">
                <div className="mt-0.5">{icon(log.status)}</div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-slate-700 capitalize">{log.type} sync</p>
                  <p className="text-xs text-slate-400 truncate">{log.message || `${log.itemsSynced} items`}</p>
                  <p className="text-xs text-slate-300">{formatDateTime(log.createdAt)}</p>
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
