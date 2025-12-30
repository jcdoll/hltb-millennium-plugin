import { sleep } from '@steambrew/client';
import type { LibrarySelectors } from '../types';
import { log } from '../services/logger';
import { fetchHltbData } from '../services/hltbApi';
import { getCache } from '../services/cache';
import { detectGamePage } from './detector';
import {
  createLoadingDisplay,
  createDisplay,
  getExistingDisplay,
  removeExistingDisplay,
} from '../display/components';
import { injectStyles } from '../display/styles';

const MAX_RETRIES = 20;
const RETRY_DELAY_MS = 250;

let currentAppId: number | null = null;
let processingAppId: number | null = null;
let observer: MutationObserver | null = null;

export function resetState(): void {
  currentAppId = null;
  processingAppId = null;
}

async function handleGamePage(doc: Document, selectors: LibrarySelectors): Promise<void> {
  const gamePage = detectGamePage(doc, selectors);
  if (!gamePage) {
    return;
  }

  const { appId, container } = gamePage;

  // Already processing this specific app - prevent re-entry from MutationObserver
  if (appId === processingAppId) {
    return;
  }

  // Check if display already exists for this app
  const existingDisplay = getExistingDisplay(doc);
  if (appId === currentAppId && existingDisplay) {
    return;
  }

  // Set processing lock before any DOM modifications
  processingAppId = appId;
  currentAppId = appId;
  log('Found game page for appId:', appId);

  try {
    removeExistingDisplay(doc);

    // Ensure container has relative positioning for absolute child
    container.style.position = 'relative';
    container.appendChild(createLoadingDisplay(doc));

    const result = await fetchHltbData(appId);

    const updateDisplayForApp = (targetAppId: number) => {
      const existing = getExistingDisplay(doc);
      if (!existing) return false;

      const cached = getCache(targetAppId);
      const data = cached?.entry?.data;

      if (data && (data.comp_main || data.comp_plus || data.comp_100)) {
        existing.replaceWith(createDisplay(doc, data));
        return true;
      }
      return false;
    };

    // If game changed during fetch, update display for the new game instead
    if (currentAppId !== null && currentAppId !== appId) {
      log('Game changed during fetch, updating display for current game:', currentAppId);
      updateDisplayForApp(currentAppId);
      return;
    }

    if (updateDisplayForApp(appId)) {
      log('Display updated for appId:', appId);
    }

    // Handle background refresh for stale data
    if (result.refreshPromise) {
      result.refreshPromise.then((newData) => {
        if (newData && currentAppId === appId) {
          updateDisplayForApp(appId);
        }
      });
    }
  } catch (e) {
    log('Error fetching HLTB data:', e);
  } finally {
    // Clear processing lock only if we're still processing this app
    if (processingAppId === appId) {
      processingAppId = null;
    }
  }
}

export async function setupObserver(doc: Document, selectors: LibrarySelectors): Promise<void> {
  // Clean up existing observer
  if (observer) {
    observer.disconnect();
    observer = null;
  }

  injectStyles(doc);

  observer = new MutationObserver(() => {
    handleGamePage(doc, selectors);
  });

  observer.observe(doc.body, {
    childList: true,
    subtree: true,
  });

  log('MutationObserver set up');

  // Retry loop to find game page
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const gamePage = detectGamePage(doc, selectors);
    if (gamePage) {
      log('setupObserver: game page found on attempt', attempt, 'of', MAX_RETRIES);
      handleGamePage(doc, selectors);
      return;
    }
    await sleep(RETRY_DELAY_MS);
  }

  log('setupObserver: no game page found after', MAX_RETRIES, 'attempts');
}

export function disconnectObserver(): void {
  if (observer) {
    observer.disconnect();
    observer = null;
  }
}
