// HLTB game data from backend
export interface HltbGameResult {
  game_id: number;
  game_name: string;
  comp_main: number | null; // hours
  comp_plus: number | null; // hours
  comp_100: number | null; // hours
  comp_all: number | null; // hours
}

// Cache entry for localStorage
export interface CacheEntry {
  data: HltbGameResult | null;
  timestamp: number;
  notFound: boolean;
}

// Result from fetchHltbData with stale-while-revalidate support
export interface FetchResult {
  data: HltbGameResult | null;
  fromCache: boolean;
  refreshPromise: Promise<HltbGameResult | null> | null;
}

// Library selectors for finding game pages
export interface LibrarySelectors {
  headerImageSelector: string;
  fallbackImageSelector: string;
  containerSelector: string;
  appIdPattern: RegExp;
}

export const LIBRARY_SELECTORS: LibrarySelectors = {
  headerImageSelector: '._3NBxSLAZLbbbnul8KfDFjw._2dzwXkCVAuZGFC-qKgo8XB',
  fallbackImageSelector: 'img.HNbe3eZf6H7dtJ042x1vM[src*="library_hero"]',
  containerSelector: '.NZMJ6g2iVnFsOOp-lDmIP',
  appIdPattern: /\/assets\/(\d+)/,
};

// Detected game page info
export interface GamePageInfo {
  appId: number;
  container: HTMLElement;
}
