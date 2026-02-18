import axios from 'axios'
import { prisma } from './prisma'

const UBER_BASE = 'https://api.uber.com/v1'
const UBER_AUTH = 'https://login.uber.com/oauth/v2/token'

export async function getUberSettings(userId: string) {
  const settings = await prisma.settings.findUnique({ where: { userId } })
  return settings
}

export async function getUberAccessToken(userId: string): Promise<string> {
  const settings = await getUberSettings(userId)
  if (!settings) throw new Error('No settings found')

  // Check if token is still valid (with 5 min buffer)
  const buffer = 5 * 60 * 1000
  if (settings.uberAccessToken && settings.uberTokenExpiry) {
    if (new Date(settings.uberTokenExpiry).getTime() - buffer > Date.now()) {
      return settings.uberAccessToken
    }
  }

  // Refresh token
  if (settings.uberRefreshToken) {
    try {
      const resp = await axios.post(UBER_AUTH, new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: settings.uberRefreshToken,
        client_id: settings.uberClientId || '',
        client_secret: settings.uberClientSecret || '',
      }), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      })

      await prisma.settings.update({
        where: { userId },
        data: {
          uberAccessToken: resp.data.access_token,
          uberRefreshToken: resp.data.refresh_token || settings.uberRefreshToken,
          uberTokenExpiry: new Date(Date.now() + resp.data.expires_in * 1000),
        },
      })
      return resp.data.access_token
    } catch (e) {
      throw new Error('Uber token refresh failed. Please reconnect Uber Eats in Settings.')
    }
  }

  throw new Error('No Uber access token. Please connect Uber Eats in Settings.')
}

export async function getUberAuthUrl(userId: string): Promise<string> {
  const settings = await getUberSettings(userId)
  if (!settings?.uberClientId) throw new Error('Set Uber Client ID in Settings first')

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: settings.uberClientId,
    redirect_uri: process.env.UBER_REDIRECT_URI || 'https://app.mangkokavenue.com/uber-redirect/',
    scope: 'eats.store eats.order',
    state: userId,
  })

  return `https://login.uber.com/oauth/v2/authorize?${params.toString()}`
}

export async function exchangeUberCode(userId: string, code: string) {
  const settings = await getUberSettings(userId)
  if (!settings) throw new Error('No settings found')

  const resp = await axios.post(UBER_AUTH, new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: process.env.UBER_REDIRECT_URI || 'https://app.mangkokavenue.com/uber-redirect/',
    client_id: settings.uberClientId || '',
    client_secret: settings.uberClientSecret || '',
  }), {
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  })

  await prisma.settings.update({
    where: { userId },
    data: {
      uberAccessToken: resp.data.access_token,
      uberRefreshToken: resp.data.refresh_token,
      uberTokenExpiry: new Date(Date.now() + resp.data.expires_in * 1000),
    },
  })

  return resp.data
}

export async function syncMenuItemToUber(
  userId: string,
  item: {
    squareItemId: string
    name: string
    description?: string | null
    priceCents: number
    imageUrl?: string | null
    category?: string | null
  }
): Promise<string> {
  const token = await getUberAccessToken(userId)
  const settings = await getUberSettings(userId)
  const storeId = settings?.uberStoreId
  if (!storeId) throw new Error('Uber Store ID not configured in Settings')

  const payload = {
    title: { translations: { en: item.name } },
    description: item.description
      ? { translations: { en: item.description } }
      : undefined,
    price_info: {
      price: item.priceCents,
      currency_code: 'AUD',
    },
    tax_info: { tax_rate: 0, tax_type: 'GST' },
    ...(item.imageUrl ? { image_url: item.imageUrl } : {}),
  }

  // Try to find existing item on Uber by external reference
  const existingItem = await prisma.menuItem.findFirst({
    where: { squareItemId: item.squareItemId },
  })

  let uberItemId: string

  if (existingItem?.uberItemId) {
    // Update existing
    await axios.put(
      `${UBER_BASE}/eats/stores/${storeId}/menus/items/${existingItem.uberItemId}`,
      payload,
      { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
    )
    uberItemId = existingItem.uberItemId
  } else {
    // Create new
    const resp = await axios.post(
      `${UBER_BASE}/eats/stores/${storeId}/menus/items`,
      payload,
      { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
    )
    uberItemId = resp.data.id || resp.data.item_id
  }

  return uberItemId
}

export async function pauseUberItem(userId: string, uberItemId: string, paused: boolean) {
  const token = await getUberAccessToken(userId)
  const settings = await getUberSettings(userId)
  const storeId = settings?.uberStoreId
  if (!storeId) throw new Error('Uber Store ID not configured')

  await axios.patch(
    `${UBER_BASE}/eats/stores/${storeId}/menus/items/${uberItemId}/pause`,
    { paused },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  )
}
