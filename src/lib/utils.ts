import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatPrice(amount: number): string {
  return new Intl.NumberFormat('en-AU', { style: 'currency', currency: 'AUD' }).format(amount)
}

export function formatDateTime(date: string | Date): string {
  return new Intl.DateTimeFormat('en-AU', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(date))
}

export function calcAdjustedPrice(
  basePrice: number,
  markupType: 'percent' | 'fixed',
  markupValue: number
): number {
  if (markupType === 'percent') {
    return Math.round((basePrice * (1 + markupValue / 100)) * 100) / 100
  } else {
    return Math.round((basePrice + markupValue) * 100) / 100
  }
}

export function centsToDecimal(cents: number): number {
  return cents / 100
}

export function decimalToCents(dollars: number): number {
  return Math.round(dollars * 100)
}

export function uberPriceInCents(basePrice: number, markupType: 'percent' | 'fixed', markupValue: number): number {
  return decimalToCents(calcAdjustedPrice(basePrice, markupType, markupValue))
}
