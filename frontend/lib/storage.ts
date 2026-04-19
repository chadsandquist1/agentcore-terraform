import type { Item } from '@/types';

const KEY = 'receipt-classifier.items';

export function loadItems(): Item[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Item[]) : [];
  } catch {
    return [];
  }
}

export function saveItems(items: Item[]): void {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(KEY, JSON.stringify(items));
  } catch (e) {
    if (e instanceof DOMException && e.name === 'QuotaExceededError') {
      // Drop oldest items one at a time until it fits
      const trimmed = items.slice(0, -1);
      if (trimmed.length > 0) saveItems(trimmed);
    }
  }
}
