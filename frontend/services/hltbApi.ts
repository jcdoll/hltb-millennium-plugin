import { callable } from '@steambrew/client';
import { getCache, setCache } from './cache';

export interface HltbGameResult {
  game_id: number; // HLTB game ID (for URL)
  game_name: string;
  comp_main: number; // seconds
  comp_plus: number; // seconds
  comp_100: number; // seconds
  comp_all: number; // seconds
}

interface BackendResponse {
  success: boolean;
  error?: string;
  data?: HltbGameResult;
}

export interface FetchResult {
  data: HltbGameResult | null;
  fromCache: boolean;
  refreshPromise: Promise<HltbGameResult | null> | null;
}

const GetHltbData = callable<[{ app_id: number }], string>('GetHltbData');

async function fetchFromBackend(appId: number): Promise<HltbGameResult | null> {
  try {
    const resultJson = await GetHltbData({ app_id: appId });
    const result: BackendResponse = JSON.parse(resultJson);

    if (!result.success || !result.data) {
      console.log('[HLTB] Backend error:', result.error);
      // Don't cache failures - keep old data
      return null;
    }

    setCache(appId, result.data);
    return result.data;
  } catch (e) {
    console.error('[HLTB] Backend call error:', e);
    // Don't cache failures - keep old data
    return null;
  }
}

export async function fetchHltbData(appId: number): Promise<FetchResult> {
  const cached = getCache(appId);

  if (cached) {
    const cachedData = cached.entry.notFound ? null : cached.entry.data;

    if (cached.isStale) {
      // Return stale data immediately, refresh in background
      console.log('[HLTB] Returning stale cache, refreshing...');
      const refreshPromise = fetchFromBackend(appId);
      return { data: cachedData, fromCache: true, refreshPromise };
    } else {
      // Fresh cache, no refresh needed
      return { data: cachedData, fromCache: true, refreshPromise: null };
    }
  }

  // No cache, fetch now
  const data = await fetchFromBackend(appId);
  if (!data) {
    // Cache "not found" so we don't keep retrying
    setCache(appId, null);
  }
  return { data, fromCache: false, refreshPromise: null };
}

export function formatTime(seconds: number): string {
  if (!seconds || seconds === 0) return '--';
  const hours = Math.round((seconds / 3600) * 10) / 10;
  if (hours < 1) {
    const mins = Math.round(seconds / 60);
    return `${mins}m`;
  }
  return `${hours}h`;
}
