import { Millennium, callable } from '@steambrew/webkit';
import { fetchHltbData, HltbGameResult } from './hltbApi';
import { injectStyles } from './styles';

const GetSettingsRpc = callable<[], string>('GetSettings');

const CONTAINER_ID = 'hltb-store-data';

// Also defined in frontend/display/components.ts (separate build target, can't share code)
function formatTime(hours: number | null | undefined): string {
  if (hours == null || hours <= 0) return '--';
  if (hours < 1) {
    const mins = Math.round(hours * 60);
    return `${mins}m`;
  }
  return `${hours}h`;
}

function createLoadingDisplay(): HTMLElement {
  const container = document.createElement('div');
  container.id = CONTAINER_ID;
  container.innerHTML = `
    <p class="hltb-store-title">How Long To Beat</p>
    <span class="hltb-store-loading">Loading...</span>
  `;
  return container;
}

function createDataDisplay(data: HltbGameResult, showViewDetails: boolean): HTMLElement {
  const container = document.createElement('div');
  container.id = CONTAINER_ID;

  const stats = [
    { label: 'Main Story', value: data.comp_main },
    { label: 'Main + Extras', value: data.comp_plus },
    { label: 'Completionist', value: data.comp_100 },
  ];

  const rows = stats
    .map(s => `<div class="hltb-store-row">${s.label}<span>${formatTime(s.value)}</span></div>`)
    .join('');

  let linkHtml = '';
  if (showViewDetails) {
    if (data.game_id) {
      linkHtml = `<a class="hltb-store-link" href="https://howlongtobeat.com/game/${data.game_id}" target="_blank">View Details</a>`;
    } else {
      const query = encodeURIComponent(data.searched_name);
      linkHtml = `<a class="hltb-store-link" href="https://howlongtobeat.com/?q=${query}" target="_blank">Search HLTB</a>`;
    }
  }

  container.innerHTML = `
    <p class="hltb-store-title">How Long To Beat</p>
    <div class="hltb-store-rows">${rows}</div>
    ${linkHtml}
  `;

  return container;
}

const SIDEBAR_SELECTOR = 'div.rightcol.game_meta_data';

// Position targets in the store sidebar (insert after the matched element)
const POSITION_SELECTORS: Record<string, string> = {
  achievements: '#achievement_block',
  details: '#appDetailsUnderlinedLinks',
};

function insertAtPosition(element: HTMLElement, position: string): boolean {
  const sidebar = document.querySelector(SIDEBAR_SELECTOR);
  if (!sidebar) return false;

  if (position === 'top') {
    sidebar.insertBefore(element, sidebar.firstChild);
    return true;
  }

  if (position === 'bottom') {
    sidebar.appendChild(element);
    return true;
  }

  const selector = POSITION_SELECTORS[position];
  if (!selector) return false;

  const target = document.querySelector(selector);
  if (!target?.parentElement) return false;

  target.parentElement.insertBefore(element, target.nextSibling);
  return true;
}

interface StoreSettings {
  showInStore: boolean;
  storePosition: string;
  showStoreViewDetails: boolean;
}

async function readStoreSettings(): Promise<StoreSettings | undefined> {
  try {
    const settingsJson = await GetSettingsRpc();
    if (!settingsJson) return;
    const result = JSON.parse(settingsJson);
    if (result.success) return result.data;
  } catch {
    return undefined;
  }
}

// Steam can restore this document from history after closing Millennium settings.
function checkPositionOnReturn(displayedPosition: string): void {
  let checking = false;
  const check = async () => {
    if (document.hidden || checking) return;
    checking = true;
    const saved = await readStoreSettings();
    if (!document.hidden && saved?.storePosition && saved.storePosition !== displayedPosition) {
      window.location.reload();
      return;
    }
    checking = false;
  };
  document.addEventListener('visibilitychange', check);
  window.addEventListener('pageshow', event => {
    if (event.persisted) void check();
  });
}

export async function initStorePage(appId: number): Promise<void> {
  const settings = await readStoreSettings();
  const storePosition = settings?.storePosition || 'achievements';
  checkPositionOnReturn(storePosition);
  if (settings && !settings.showInStore) return;
  const showViewDetails = settings?.showStoreViewDetails !== false;
  injectStyles();

  // Wait for the sidebar to appear
  try {
    await Millennium.findElement(document, SIDEBAR_SELECTOR, 5000);
  } catch {
    console.warn('[HLTB] Store sidebar not found, skipping injection');
    return;
  }

  // Don't inject twice
  if (document.getElementById(CONTAINER_ID)) return;

  // Insert loading state at chosen position, fall back to bottom of sidebar
  const loading = createLoadingDisplay();
  if (!insertAtPosition(loading, storePosition)) {
    if (!insertAtPosition(loading, 'bottom')) {
      console.warn('[HLTB] Could not find insertion point, skipping injection');
      return;
    }
  }

  // Get fallback game name from the page
  const nameEl = document.querySelector('.apphub_AppName');
  const fallbackName = nameEl?.textContent?.trim();

  // Fetch data
  const result = await fetchHltbData(appId, fallbackName);

  // Replace loading with result
  const existing = document.getElementById(CONTAINER_ID);
  if (!existing) return;

  if (result.data) {
    existing.replaceWith(createDataDisplay(result.data, showViewDetails));

    // Update display when background refresh completes
    if (result.refreshPromise) {
      result.refreshPromise.then((newData) => {
        if (!newData) return;
        const current = document.getElementById(CONTAINER_ID);
        if (current) {
          current.replaceWith(createDataDisplay(newData, showViewDetails));
        }
      });
    }
  } else {
    existing.remove();
  }
}
