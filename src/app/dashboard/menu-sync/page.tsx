'use client'

import { useState, useEffect, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Icons } from '@/components/ui/icons'
import { useToast } from '@/components/ui/use-toast'
import { formatPrice, calcAdjustedPrice } from '@/lib/utils'
import Image from 'next/image'

interface SquareItem {
  id: string
  name: string
  description?: string
  price: number
  imageUrl?: string
  category?: string
  isAvailable: boolean
  uberSynced: boolean
  uberItemId?: string
  customMarkupType?: string | null
  customMarkupValue?: number | null
  adjustedPrice?: number | null
}

interface MarkupSettings {
  type: 'percent' | 'fixed'
  value: number
}

export default function MenuSyncPage() {
  const { toast } = useToast()
  const [items, setItems] = useState<SquareItem[]>([])
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [syncing, setSyncing] = useState(false)
  const [pulling, setPulling] = useState(false)
  const [search, setSearch] = useState('')
  const [filterSynced, setFilterSynced] = useState<'all' | 'synced' | 'unsynced'>('all')
  const [globalMarkup, setGlobalMarkup] = useState<MarkupSettings>({ type: 'percent', value: 30 })

  // Per-item saved manual prices (loaded from DB or saved this session)
  const [priceOverrides, setPriceOverrides] = useState<Record<string, number>>({})
  // Raw string values while user is actively typing in a price field
  const [editingPrices, setEditingPrices] = useState<Record<string, string>>({})
  // Which item is currently being auto-saved
  const [savingItemId, setSavingItemId] = useState<string | null>(null)

  const fetchItems = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/menu/items')
      const data = await res.json()
      const loadedItems: SquareItem[] = data.items || []
      setItems(loadedItems)
      // Restore any saved manual prices from DB
      const overrides: Record<string, number> = {}
      for (const item of loadedItems) {
        if (item.customMarkupType === 'manual' && item.adjustedPrice != null) {
          overrides[item.id] = item.adjustedPrice
        }
      }
      setPriceOverrides(overrides)
    } catch {
      toast({ title: 'Error', description: 'Failed to load menu items', variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }, [toast])

  useEffect(() => { fetchItems() }, [fetchItems])

  // Returns the final Uber price for an item (manual override > DB markup > global markup)
  const getUberPrice = useCallback((item: SquareItem): number => {
    if (priceOverrides[item.id] !== undefined) return priceOverrides[item.id]
    if (item.customMarkupType != null && item.customMarkupType !== 'manual' && item.customMarkupValue != null) {
      return calcAdjustedPrice(item.price, item.customMarkupType as 'percent' | 'fixed', item.customMarkupValue)
    }
    return calcAdjustedPrice(item.price, globalMarkup.type, globalMarkup.value)
  }, [priceOverrides, globalMarkup])

  const isManualPrice = (item: SquareItem) => priceOverrides[item.id] !== undefined

  const saveItemPrice = async (id: string, manualPrice: number | null) => {
    setSavingItemId(id)
    try {
      await fetch('/api/menu/items', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, manualPrice }),
      })
    } catch {
      toast({ title: 'Error', description: 'Failed to save price', variant: 'destructive' })
    } finally {
      setSavingItemId(null)
    }
  }

  const handlePriceBlur = async (item: SquareItem) => {
    const typedValue = editingPrices[item.id]
    // Clear editing state
    setEditingPrices(prev => { const n = { ...prev }; delete n[item.id]; return n })
    if (typedValue === undefined) return

    const parsed = parseFloat(typedValue)
    if (isNaN(parsed) || parsed < 0) return

    const calculated = calcAdjustedPrice(item.price, globalMarkup.type, globalMarkup.value)

    // If typed value matches calculated (within 1 cent), clear any manual override
    if (Math.abs(parsed - calculated) < 0.005) {
      if (priceOverrides[item.id] !== undefined) {
        setPriceOverrides(prev => { const n = { ...prev }; delete n[item.id]; return n })
        await saveItemPrice(item.id, null)
        toast({ title: 'Price reset', description: `${item.name} now uses global markup` })
      }
      return
    }

    // Save as manual override
    setPriceOverrides(prev => ({ ...prev, [item.id]: parsed }))
    await saveItemPrice(item.id, parsed)
    toast({ title: 'Price saved', description: `${item.name} set to ${formatPrice(parsed)}` })
  }

  const clearManualPrice = async (item: SquareItem, e: React.MouseEvent) => {
    e.stopPropagation()
    setPriceOverrides(prev => { const n = { ...prev }; delete n[item.id]; return n })
    setEditingPrices(prev => { const n = { ...prev }; delete n[item.id]; return n })
    await saveItemPrice(item.id, null)
    toast({ description: `${item.name} reset to calculated price` })
  }

  const pullFromSquare = async () => {
    setPulling(true)
    try {
      const res = await fetch('/api/square/pull-menu', { method: 'POST' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      toast({ title: ' Menu pulled', description: `${data.count} items imported from Square` })
      fetchItems()
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Unknown error'
      toast({ title: 'Error', description: msg, variant: 'destructive' })
    } finally {
      setPulling(false)
    }
  }

  const syncToUber = async () => {
    if (selected.size === 0) {
      toast({ title: 'Nothing selected', description: 'Select items to sync to Uber Eats' })
      return
    }
    setSyncing(true)
    try {
      const res = await fetch('/api/uber/sync-menu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemIds: Array.from(selected), globalMarkup }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      toast({ title: ' Synced to Uber Eats', description: `${data.synced} items pushed successfully` })
      setSelected(new Set())
      fetchItems()
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Unknown error'
      toast({ title: 'Sync failed', description: msg, variant: 'destructive' })
    } finally {
      setSyncing(false)
    }
  }

  const filtered = items.filter(item => {
    const matchSearch = item.name.toLowerCase().includes(search.toLowerCase()) ||
      item.category?.toLowerCase().includes(search.toLowerCase())
    const matchFilter = filterSynced === 'all' ? true :
      filterSynced === 'synced' ? item.uberSynced : !item.uberSynced
    return matchSearch && matchFilter
  })

  const toggleAll = () => {
    if (selected.size === filtered.length) {
      setSelected(new Set())
    } else {
      setSelected(new Set(filtered.map(i => i.id)))
    }
  }

  const toggleItem = (id: string) => {
    setSelected(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Menu Sync</h1>
          <p className="text-slate-500 text-sm mt-1">Pull from Square, set Uber prices, push selected items to Uber Eats</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={pullFromSquare} disabled={pulling}>
            {pulling ? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" /> : <Icons.download className="mr-2 h-4 w-4" />}
            Pull from Square
          </Button>
          <Button
            className="bg-[#06C167] hover:bg-[#05a657] text-white"
            onClick={syncToUber}
            disabled={syncing || selected.size === 0}
          >
            {syncing ? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" /> : <Icons.upload className="mr-2 h-4 w-4" />}
            Push {selected.size > 0 ? `(${selected.size})` : ''} to Uber
          </Button>
        </div>
      </div>

      {/* Global Markup Controls */}
      <Card className="border-amber-200 bg-amber-50">
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <Icons.percent className="h-4 w-4 text-amber-600" />
            Global Price Markup
          </CardTitle>
          <CardDescription className="text-amber-700">
            Applied to all items. You can override individual items by editing the price directly on any card.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap items-end gap-4">
            <div className="space-y-1">
              <Label className="text-xs text-slate-600">Markup Type</Label>
              <div className="flex rounded-lg overflow-hidden border border-amber-300">
                {(['percent', 'fixed'] as const).map(t => (
                  <button
                    key={t}
                    onClick={() => setGlobalMarkup(m => ({ ...m, type: t }))}
                    className={`px-4 py-2 text-sm font-medium transition-colors ${
                      globalMarkup.type === t
                        ? 'bg-amber-500 text-white'
                        : 'bg-white text-slate-600 hover:bg-amber-50'
                    }`}
                  >
                    {t === 'percent' ? '% Percentage' : '$ Fixed Amount'}
                  </button>
                ))}
              </div>
            </div>
            <div className="space-y-1">
              <Label className="text-xs text-slate-600">
                {globalMarkup.type === 'percent' ? 'Percentage (%)' : 'Amount ($)'}
              </Label>
              <Input
                type="number"
                min="0"
                step={globalMarkup.type === 'percent' ? '1' : '0.50'}
                value={globalMarkup.value}
                onChange={e => setGlobalMarkup(m => ({ ...m, value: parseFloat(e.target.value) || 0 }))}
                className="w-28 border-amber-300 bg-white"
              />
            </div>
            <div className="pb-2 text-sm text-amber-800">
              e.g. $10.00{' '}
              <span className="text-slate-500"></span>{' '}
              <strong className="text-slate-900">{formatPrice(calcAdjustedPrice(10, globalMarkup.type, globalMarkup.value))}</strong>
              {globalMarkup.type === 'percent' && (
                <span className="text-slate-400 ml-1">(+{globalMarkup.value}%)</span>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Filters & Search */}
      <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
        <Input
          placeholder="Search items or categories..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="max-w-xs"
        />
        <div className="flex rounded-lg overflow-hidden border border-slate-200">
          {(['all', 'unsynced', 'synced'] as const).map(f => (
            <button
              key={f}
              onClick={() => setFilterSynced(f)}
              className={`px-3 py-1.5 text-xs font-medium capitalize transition-colors ${
                filterSynced === f ? 'bg-slate-800 text-white' : 'bg-white text-slate-600 hover:bg-slate-50'
              }`}
            >
              {f}
            </button>
          ))}
        </div>
        <span className="text-sm text-slate-500">{filtered.length} items</span>
        {filtered.length > 0 && (
          <button onClick={toggleAll} className="text-sm text-primary hover:underline ml-auto">
            {selected.size === filtered.length ? 'Deselect all' : 'Select all'}
          </button>
        )}
      </div>

      {/* Items Grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-48 bg-slate-100 animate-pulse rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <Card className="py-16">
          <CardContent className="text-center">
            <Icons.package className="h-12 w-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-500 font-medium">No items found</p>
            <p className="text-slate-400 text-sm mt-1">Pull from Square to import your menu</p>
            <Button className="mt-4" onClick={pullFromSquare} disabled={pulling}>
              {pulling ? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" /> : null}
              Pull from Square
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(item => {
            const isSelected = selected.has(item.id)
            const uberPrice = getUberPrice(item)
            const isManual = isManualPrice(item)
            const margin = uberPrice - item.price
            // The value shown in the input: what user is typing, or the computed price
            const inputDisplayValue = editingPrices[item.id] ?? uberPrice.toFixed(2)

            return (
              <Card
                key={item.id}
                onClick={() => toggleItem(item.id)}
                className={`cursor-pointer transition-all hover:shadow-md ${
                  isSelected ? 'ring-2 ring-primary border-primary' : 'border-slate-200'
                }`}
              >
                <CardContent className="p-4">
                  <div className="flex gap-3">
                    {item.imageUrl ? (
                      <Image src={item.imageUrl} alt={item.name} width={64} height={64}
                        className="w-16 h-16 rounded-lg object-cover flex-shrink-0" />
                    ) : (
                      <div className="w-16 h-16 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0">
                        <Icons.utensils className="h-6 w-6 text-slate-300" />
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <h3 className="font-semibold text-slate-900 text-sm leading-tight truncate">{item.name}</h3>
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => toggleItem(item.id)}
                          onClick={e => e.stopPropagation()}
                          className="mt-0.5 flex-shrink-0 w-4 h-4 accent-primary"
                        />
                      </div>
                      {item.category && (
                        <Badge variant="secondary" className="text-xs mt-1">{item.category}</Badge>
                      )}
                      {item.description && (
                        <p className="text-xs text-slate-400 mt-1 line-clamp-2">{item.description}</p>
                      )}
                    </div>
                  </div>

                  <Separator className="my-3" />

                  {/* Price row */}
                  <div className="flex items-center gap-2" onClick={e => e.stopPropagation()}>
                    {/* Square price */}
                    <div className="flex-shrink-0">
                      <p className="text-xs text-slate-400">Square</p>
                      <p className="font-semibold text-slate-700 text-sm">{formatPrice(item.price)}</p>
                    </div>

                    <Icons.arrowRight className="h-3 w-3 text-slate-300 flex-shrink-0" />

                    {/* Uber price (editable) */}
                    <div className="flex-1 text-right">
                      {/* Label row */}
                      <div className="flex items-center justify-end gap-1 mb-0.5 h-4">
                        {isManual ? (
                          <>
                            <span className="text-xs text-amber-600 font-medium"> custom</span>
                            <button
                              onClick={(e) => clearManualPrice(item, e)}
                              className="text-slate-300 hover:text-red-400 text-xs leading-none ml-0.5"
                              title="Reset to calculated price"
                            >
                              
                            </button>
                          </>
                        ) : (
                          <span className="text-xs text-emerald-600">
                            {margin > 0 ? `+${formatPrice(margin)}` : formatPrice(margin)}
                            {globalMarkup.type === 'percent'
                              ? <span className="text-slate-400 ml-0.5">({globalMarkup.value}%)</span>
                              : null
                            }
                          </span>
                        )}
                        {savingItemId === item.id && (
                          <Icons.spinner className="h-3 w-3 animate-spin text-slate-300 ml-1" />
                        )}
                      </div>

                      {/* Editable price input */}
                      <div className="flex items-center justify-end">
                        <span className="text-slate-400 text-xs mr-0.5">$</span>
                        <input
                          type="number"
                          min="0"
                          step="0.10"
                          value={inputDisplayValue}
                          onFocus={e => {
                            e.stopPropagation()
                            setEditingPrices(prev => ({ ...prev, [item.id]: uberPrice.toFixed(2) }))
                            setTimeout(() => e.target.select(), 0)
                          }}
                          onChange={e => {
                            e.stopPropagation()
                            setEditingPrices(prev => ({ ...prev, [item.id]: e.target.value }))
                          }}
                          onBlur={() => handlePriceBlur(item)}
                          onClick={e => e.stopPropagation()}
                          className={`w-20 text-right font-bold bg-transparent border-b focus:outline-none text-sm tabular-nums transition-colors ${
                            isManual
                              ? 'text-amber-700 border-amber-400 focus:border-amber-600'
                              : 'text-slate-900 border-dashed border-slate-300 focus:border-emerald-500'
                          }`}
                        />
                      </div>
                    </div>
                  </div>

                  {/* Status badges */}
                  <div className="flex items-center gap-2 mt-3">
                    {item.uberSynced
                      ? <Badge className="bg-[#06C167]/10 text-[#06C167] hover:bg-[#06C167]/20 text-xs"> On Uber</Badge>
                      : <Badge variant="outline" className="text-xs text-slate-400">Not on Uber</Badge>
                    }
                    {!item.isAvailable && (
                      <Badge variant="destructive" className="text-xs">86&apos;d</Badge>
                    )}
                    {isSelected && (
                      <Badge className="bg-primary/10 text-primary text-xs ml-auto">Selected</Badge>
                    )}
                  </div>
                </CardContent>
              </Card>
            )
          })}
        </div>
      )}
    </div>
  )
}
