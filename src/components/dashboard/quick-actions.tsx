'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Icons } from '@/components/ui/icons'
import { useToast } from '@/components/ui/use-toast'
import Link from 'next/link'

export function QuickActions() {
  const { toast } = useToast()
  const [pulling, setPulling] = useState(false)

  const pullMenu = async () => {
    setPulling(true)
    try {
      const res = await fetch('/api/square/pull-menu', { method: 'POST' })
      const data = await res.json()
      toast({ title: '✅ Done', description: `${data.count} items pulled from Square` })
    } catch {
      toast({ title: 'Error', description: 'Pull failed', variant: 'destructive' })
    } finally {
      setPulling(false)
    }
  }

  return (
    <Card className="border-slate-200">
      <CardHeader className="pb-2">
        <CardTitle className="text-base font-semibold text-slate-900">Quick Actions</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <Button variant="outline" className="w-full justify-start text-sm" onClick={pullMenu} disabled={pulling}>
          {pulling
            ? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" />
            : <Icons.download className="mr-2 h-4 w-4" />}
          Pull menu from Square
        </Button>
        <Button variant="outline" className="w-full justify-start text-sm" asChild>
          <Link href="/dashboard/menu-sync">
            <Icons.upload className="mr-2 h-4 w-4" />
            Sync items to Uber Eats
          </Link>
        </Button>
        <Button variant="outline" className="w-full justify-start text-sm" asChild>
          <Link href="/dashboard/settings">
            <Icons.settings className="mr-2 h-4 w-4" />
            Configure settings
          </Link>
        </Button>
        <Button variant="outline" className="w-full justify-start text-sm" asChild>
          <Link href="/dashboard/orders">
            <Icons.shoppingBag className="mr-2 h-4 w-4" />
            View all orders
          </Link>
        </Button>
      </CardContent>
    </Card>
  )
}
