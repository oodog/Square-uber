import { SquareClient, SquareEnvironment } from 'square'
import { prisma } from './prisma'

export async function getSquareClient(userId?: string) {
  let accessToken = process.env.SQUARE_ACCESS_TOKEN || ''
  let environment = (process.env.SQUARE_ENVIRONMENT || 'sandbox') as 'sandbox' | 'production'

  if (userId) {
    const settings = await prisma.settings.findUnique({ where: { userId } })
    if (settings?.squareAccessToken) accessToken = settings.squareAccessToken
    if (settings?.squareEnvironment) environment = settings.squareEnvironment as 'sandbox' | 'production'
  }

  if (!accessToken) throw new Error('No Square access token configured. Please add it in Settings.')

  return new SquareClient({
    token: accessToken,
    environment: environment === 'production' ? SquareEnvironment.Production : SquareEnvironment.Sandbox,
  })
}

export async function getSquareLocationId(userId?: string): Promise<string> {
  if (userId) {
    const settings = await prisma.settings.findUnique({ where: { userId } })
    if (settings?.squareLocationId) return settings.squareLocationId
  }
  return process.env.SQUARE_LOCATION_ID || ''
}

export async function pullMenuFromSquare(userId: string) {
  const client = await getSquareClient(userId)

  // Collect all catalog objects via auto-paginated list
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const allObjects: any[] = []
  const page = await client.catalog.list({ types: 'ITEM,IMAGE,CATEGORY' })
  for await (const obj of page) {
    allObjects.push(obj)
  }

  // Build lookup maps for images and categories
  const imageMap = new Map<string, string>()
  const categoryMap = new Map<string, string>()

  for (const obj of allObjects) {
    if (obj.type === 'IMAGE' && obj.id && obj.imageData?.url) {
      imageMap.set(obj.id, obj.imageData.url)
    }
    if (obj.type === 'CATEGORY' && obj.id && obj.categoryData?.name) {
      categoryMap.set(obj.id, obj.categoryData.name)
    }
  }

  const items = allObjects.filter(o => o.type === 'ITEM')
  let count = 0

  for (const item of items) {
    const data = item.itemData
    if (!data || !item.id) continue

    // Get price from first variation (amount may be BigInt from SDK - convert to Number)
    const variation = data.variations?.[0]
    const priceMoney = variation?.itemVariationData?.priceMoney
    const priceInDollars = Number(priceMoney?.amount ?? 0) / 100

    // Get image URL
    const imageId = data.imageIds?.[0]
    const imageUrl = imageId ? imageMap.get(imageId) : undefined

    // Get category — SDK v42 uses categories array instead of categoryId
    const categoryId = (data as any).categories?.[0]?.id ?? (data as any).categoryId
    const categoryName = categoryId ? categoryMap.get(categoryId) : undefined

    await prisma.menuItem.upsert({
      where: { squareItemId: item.id },
      create: {
        squareItemId: item.id,
        squareName: data.name || 'Unnamed Item',
        squareDesc: data.description,
        squarePrice: priceInDollars,
        squareImageUrl: imageUrl,
        squareCategoryName: categoryName,
        squareIsAvailable: !item.isDeleted,
      },
      update: {
        squareName: data.name || 'Unnamed Item',
        squareDesc: data.description,
        squarePrice: priceInDollars,
        squareImageUrl: imageUrl,
        squareCategoryName: categoryName,
        squareIsAvailable: !item.isDeleted,
      },
    })
    count++
  }

  return count
}

export async function createSquareOrderFromUber(
  userId: string,
  customerName: string,
  items: Array<{ name: string; squareItemId?: string; quantity: number; unitPriceCents: number }>,
  uberOrderId: string
) {
  const client = await getSquareClient(userId)
  const locationId = await getSquareLocationId(userId)
  if (!locationId) throw new Error('No Square location ID configured. Please add it in Settings.')

  const lineItems = items.map(item => ({
    name: item.name,
    quantity: String(item.quantity),
    basePriceMoney: {
      amount: BigInt(item.unitPriceCents), // SDK v42 requires BigInt
      currency: 'AUD' as const,
    },
    note: `UBER - ${customerName}`,
  }))

  const response = await client.orders.create({
    order: {
      locationId,
      lineItems,
      ticketName: `UBER – ${customerName}`,
      state: 'OPEN',
      metadata: {
        uber_order_id: uberOrderId,
        customer_name: customerName,
        source: 'uber_eats',
      },
    },
    idempotencyKey: `uber-${uberOrderId}-${Date.now()}`,
  })

  return response.order
}
