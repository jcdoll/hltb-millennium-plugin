import { getCache, setCache } from './cache';

// Using AugmentedSteam's API which already maps Steam appId to HLTB data
const AUGMENTED_STEAM_API = 'https://api.augmentedsteam.com/app';

// Our result type (matching what we display)
export interface HltbGameResult {
  game_id: number;
  game_name: string;
  comp_main: number; // seconds
  comp_plus: number; // seconds
  comp_100: number; // seconds
  comp_all: number; // seconds
}

interface AugmentedSteamResponse {
  hltb?: {
    story: number | null;
    extras: number | null;
    complete: number | null;
    url: string;
  };
}

/**
 * Fetch HLTB data using AugmentedSteam's API (same approach they use)
 */
export async function fetchHltbData(appId: number): Promise<HltbGameResult | null> {
  // Check cache first
  const cached = getCache(appId);
  if (cached) {
    return cached.notFound ? null : cached.data;
  }

  try {
    const response = await fetch(`${AUGMENTED_STEAM_API}/${appId}/v2`);

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    const data: AugmentedSteamResponse = await response.json();

    if (!data.hltb) {
      setCache(appId, null);
      return null;
    }

    const result: HltbGameResult = {
      game_id: appId,
      game_name: '', // Not needed for display
      comp_main: (data.hltb.story || 0) * 60, // Convert minutes to seconds
      comp_plus: (data.hltb.extras || 0) * 60,
      comp_100: (data.hltb.complete || 0) * 60,
      comp_all: 0, // Not provided by this API
    };

    setCache(appId, result);
    return result;
  } catch (e) {
    console.error('[HLTB] Fetch error:', e);
    return null;
  }
}

/**
 * Format seconds to hours display string
 */
export function formatTime(seconds: number): string {
  if (!seconds || seconds === 0) return '--';
  const hours = Math.round((seconds / 3600) * 10) / 10;
  if (hours < 1) {
    const mins = Math.round(seconds / 60);
    return `${mins}m`;
  }
  return `${hours}h`;
}
