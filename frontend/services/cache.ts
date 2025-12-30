import type { HltbGameResult, CacheEntry } from '../types';
import { log, logError } from './logger';

interface CacheStore {
  [appId: number]: CacheEntry;
}

const CACHE_KEY = 'hltb-millennium-cache';
const CACHE_DURATION = 12 * 60 * 60 * 1000; // 12 hours
const MAX_CACHE_AGE = 90 * 24 * 60 * 60 * 1000; // 90 days
const MAX_CACHE_ENTRIES = 2000;
const PRUNE_INTERVAL = 50; // Prune every N writes

let writeCount = 0;

export function getCache(appId: number): { entry: CacheEntry; isStale: boolean } | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return null;

    const cache: CacheStore = JSON.parse(raw);
    const entry = cache[appId];

    if (!entry) return null;

    const isStale = Date.now() - entry.timestamp > CACHE_DURATION;
    return { entry, isStale };
  } catch (e) {
    logError('Cache read error:', e);
    return null;
  }
}

function pruneCache(cache: CacheStore): CacheStore {
  const now = Date.now();
  let entries = Object.entries(cache);

  // Remove entries older than MAX_CACHE_AGE
  entries = entries.filter(([_, entry]) => {
    return now - entry.timestamp < MAX_CACHE_AGE;
  });

  // If still over limit, remove oldest entries
  if (entries.length > MAX_CACHE_ENTRIES) {
    entries.sort((a, b) => b[1].timestamp - a[1].timestamp); // Newest first
    entries = entries.slice(0, MAX_CACHE_ENTRIES);
    log(`Pruned cache to ${MAX_CACHE_ENTRIES} entries`);
  }

  return Object.fromEntries(entries);
}

export function setCache(appId: number, data: HltbGameResult | null): void {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    let cache: CacheStore = raw ? JSON.parse(raw) : {};

    cache[appId] = {
      data,
      timestamp: Date.now(),
      notFound: data === null,
    };

    // Periodically prune old/excess entries
    writeCount++;
    if (writeCount >= PRUNE_INTERVAL) {
      writeCount = 0;
      cache = pruneCache(cache);
    }

    localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
  } catch (e) {
    logError('Cache write error:', e);
  }
}

export function clearCache(): void {
  try {
    localStorage.removeItem(CACHE_KEY);
    log('Cache cleared');
  } catch (e) {
    logError('Cache clear error:', e);
  }
}

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
