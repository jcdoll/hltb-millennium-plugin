import type { HltbGameResult } from './hltbApi';

interface CacheEntry {
  data: HltbGameResult | null;
  timestamp: number;
  notFound: boolean;
}

interface CacheStore {
  [appId: number]: CacheEntry;
}

const CACHE_KEY = 'hltb-millennium-cache';
const CACHE_DURATION = 2 * 60 * 60 * 1000; // 2 hours

/**
 * Get cached HLTB data for an app
 */
export function getCache(appId: number): CacheEntry | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return null;

    const cache: CacheStore = JSON.parse(raw);
    const entry = cache[appId];

    if (!entry) return null;

    // Check if expired
    if (Date.now() - entry.timestamp > CACHE_DURATION) {
      delete cache[appId];
      localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
      return null;
    }

    return entry;
  } catch (e) {
    console.error('[HLTB] Cache read error:', e);
    return null;
  }
}

/**
 * Store HLTB data in cache
 */
export function setCache(appId: number, data: HltbGameResult | null): void {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    const cache: CacheStore = raw ? JSON.parse(raw) : {};

    cache[appId] = {
      data,
      timestamp: Date.now(),
      notFound: data === null,
    };

    localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
  } catch (e) {
    console.error('[HLTB] Cache write error:', e);
  }
}

/**
 * Clear all cached HLTB data
 */
export function clearCache(): void {
  try {
    localStorage.removeItem(CACHE_KEY);
    console.log('[HLTB] Cache cleared');
  } catch (e) {
    console.error('[HLTB] Cache clear error:', e);
  }
}

/**
 * Get cache statistics
 */
export function getCacheStats(): { count: number; oldestTimestamp: number | null } {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return { count: 0, oldestTimestamp: null };

    const cache: CacheStore = JSON.parse(raw);
    const entries = Object.values(cache);

    if (entries.length === 0) return { count: 0, oldestTimestamp: null };

    const oldestTimestamp = Math.min(...entries.map((e) => e.timestamp));
    return { count: entries.length, oldestTimestamp };
  } catch (e) {
    return { count: 0, oldestTimestamp: null };
  }
}
