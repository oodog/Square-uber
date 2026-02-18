'use client'

import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Separator } from '@/components/ui/separator'
import { Icons } from '@/components/ui/icons'
import { useToast } from '@/components/ui/use-toast'

interface SettingsData {
  squareAccessToken: string
  squareLocationId: string
  squareEnvironment: string
  uberClientId: string
  uberClientSecret: string
  uberStoreId: string
  markupType: string
  markupValue: number
  autoSyncStock: boolean
  autoSyncHours: boolean
  syncImages: boolean
}

export default function SettingsPage() {
  const { toast } = useToast()
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)
  const [showTokens, setShowTokens] = useState(false)
  const [form, setForm] = useState<SettingsData>({
    squareAccessToken: '',
    squareLocationId: '',
    squareEnvironment: 'sandbox',
    uberClientId: '',
    uberClientSecret: '',
    uberStoreId: '',
    markupType: 'percent',
    markupValue: 30,
    autoSyncStock: true,
    autoSyncHours: true,
    syncImages: true,
  })

  useEffect(() => {
    fetch('/api/settings')
      .then(r => r.json())
      .then(d => { if (d.settings) setForm(d.settings) })
      .finally(() => setLoading(false))
  }, [])

  const set = (key: keyof SettingsData, value: string | number | boolean) =>
    setForm(f => ({ ...f, [key]: value }))

  const save = async () => {
    setSaving(true)
    try {
      const res = await fetch('/api/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })
      if (!res.ok) throw new Error('Save failed')
      toast({ title: '✅ Settings saved', description: 'Your configuration has been updated' })
    } catch {
      toast({ title: 'Error', description: 'Failed to save settings', variant: 'destructive' })
    } finally {
      setSaving(false)
    }
  }

  const testSquare = async () => {
    try {
      const res = await fetch('/api/square/test')
      const data = await res.json()
      if (data.ok) {
        toast({ title: '✅ Square Connected', description: `Location: ${data.locationName}` })
      } else {
        throw new Error(data.error)
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Connection failed'
      toast({ title: 'Square Error', description: msg, variant: 'destructive' })
    }
  }

  const connectUber = () => {
    window.location.href = '/api/uber/auth'
  }

  if (loading) return <div className="flex justify-center py-20"><Icons.spinner className="h-8 w-8 animate-spin text-primary" /></div>

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Settings</h1>
        <p className="text-slate-500 text-sm mt-1">Configure your Square and Uber Eats integration</p>
      </div>

      {/* Square */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <div className="w-7 h-7 bg-slate-800 rounded-lg flex items-center justify-center">
              <Icons.square className="h-4 w-4 text-white" />
            </div>
            Square Configuration
          </CardTitle>
          <CardDescription>Connect your Square POS account</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <Label className="text-sm">Environment</Label>
            <div className="flex rounded-lg overflow-hidden border">
              {['sandbox', 'production'].map(env => (
                <button key={env} onClick={() => set('squareEnvironment', env)}
                  className={`px-3 py-1.5 text-xs font-medium capitalize transition-colors ${
                    form.squareEnvironment === env ? 'bg-slate-800 text-white' : 'bg-white text-slate-600 hover:bg-slate-50'
                  }`}>
                  {env}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="squareAccessToken">Access Token</Label>
            <div className="relative">
              <Input id="squareAccessToken" type={showTokens ? 'text' : 'password'}
                value={form.squareAccessToken} onChange={e => set('squareAccessToken', e.target.value)}
                placeholder="EAAAExxxx..." className="pr-10" />
              <button onClick={() => setShowTokens(!showTokens)}
                className="absolute right-3 top-2.5 text-slate-400 hover:text-slate-600">
                {showTokens ? <Icons.eyeOff className="h-4 w-4" /> : <Icons.eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="squareLocationId">Location ID</Label>
            <Input id="squareLocationId" value={form.squareLocationId}
              onChange={e => set('squareLocationId', e.target.value)} placeholder="LxxxxXXXXXXXXX" />
          </div>

          <Button variant="outline" onClick={testSquare} size="sm">
            <Icons.zap className="mr-2 h-4 w-4" />
            Test Connection
          </Button>
        </CardContent>
      </Card>

      {/* Uber Eats */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <div className="w-7 h-7 bg-[#06C167] rounded-lg flex items-center justify-center">
              <Icons.truck className="h-4 w-4 text-white" />
            </div>
            Uber Eats Configuration
          </CardTitle>
          <CardDescription>
            OAuth redirect: https://app.mangkokavenue.com/uber-redirect/
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="uberClientId">Client ID</Label>
            <Input id="uberClientId" value={form.uberClientId}
              onChange={e => set('uberClientId', e.target.value)} placeholder="Uber Client ID" />
          </div>

          <div className="space-y-2">
            <Label htmlFor="uberClientSecret">Client Secret</Label>
            <div className="relative">
              <Input id="uberClientSecret" type={showTokens ? 'text' : 'password'}
                value={form.uberClientSecret} onChange={e => set('uberClientSecret', e.target.value)}
                placeholder="TQ3Ov8d..." className="pr-10" />
              <button onClick={() => setShowTokens(!showTokens)}
                className="absolute right-3 top-2.5 text-slate-400 hover:text-slate-600">
                {showTokens ? <Icons.eyeOff className="h-4 w-4" /> : <Icons.eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="uberStoreId">Store ID (UUID)</Label>
            <Input id="uberStoreId" value={form.uberStoreId}
              onChange={e => set('uberStoreId', e.target.value)} placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" />
          </div>

          <Button onClick={connectUber} className="bg-[#06C167] hover:bg-[#05a657] text-white">
            <Icons.externalLink className="mr-2 h-4 w-4" />
            Connect / Re-auth Uber Eats
          </Button>
        </CardContent>
      </Card>

      {/* Pricing Defaults */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Icons.dollarSign className="h-5 w-5 text-amber-500" />
            Default Price Markup
          </CardTitle>
          <CardDescription>Default applied to all items (can be overridden per-item in Menu Sync)</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-4">
            <div>
              <Label className="text-sm mb-2 block">Type</Label>
              <div className="flex rounded-lg overflow-hidden border">
                {[['percent', '% Percent'], ['fixed', '$ Fixed']].map(([val, label]) => (
                  <button key={val} onClick={() => set('markupType', val)}
                    className={`px-3 py-1.5 text-xs font-medium transition-colors ${
                      form.markupType === val ? 'bg-slate-800 text-white' : 'bg-white text-slate-600 hover:bg-slate-50'
                    }`}>
                    {label}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <Label htmlFor="markupValue" className="text-sm mb-2 block">
                Value {form.markupType === 'percent' ? '(%)' : '($)'}
              </Label>
              <Input id="markupValue" type="number" min="0"
                value={form.markupValue} onChange={e => set('markupValue', parseFloat(e.target.value) || 0)}
                className="w-28" />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Features */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Icons.settings className="h-5 w-5 text-slate-500" />
            Automation Features
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {([
            ['autoSyncStock', 'Auto-pause Uber items when out of stock in Square', '86 items automatically'],
            ['autoSyncHours', 'Sync Square opening hours to Uber Eats', 'Keep availability in sync'],
            ['syncImages', 'Sync item photos from Square to Uber Eats', 'Better item presentation'],
          ] as const).map(([key, label, desc]) => (
            <div key={key} className="flex items-center justify-between py-1">
              <div>
                <p className="text-sm font-medium text-slate-900">{label}</p>
                <p className="text-xs text-slate-400">{desc}</p>
              </div>
              <Switch checked={form[key as keyof SettingsData] as boolean}
                onCheckedChange={v => set(key as keyof SettingsData, v)} />
            </div>
          ))}
        </CardContent>
      </Card>

      <Button onClick={save} disabled={saving} className="w-full sm:w-auto" size="lg">
        {saving ? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" /> : <Icons.save className="mr-2 h-4 w-4" />}
        Save Settings
      </Button>
    </div>
  )
}
