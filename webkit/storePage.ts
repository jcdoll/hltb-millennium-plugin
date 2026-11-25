import { callable } from '@steambrew/webkit';
import { fetchHltbData, HltbGameResult } from './hltbApi';
import { injectStyles } from './styles';

const GetSettingsRpc = callable<[], string>('GetSettings');

const CONTAINER_ID = 'hltb-store-data';
const HERO_CLASS = 'hltb-store-hero';
const HERO_LANE_ID = 'hltb-store-hero-lane';

type StorePosition = 'hero' | 'top' | 'achievements' | 'details' | 'bottom';
type Placement = 'hero' | 'sidebar' | 'none';

const DEFAULT_POSITION: StorePosition = 'hero';

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

// Store pages render the game header - title, price, purchase actions, release
// date, developer, publisher, tags - above a two-column body, while the legacy
// right column starts below it. Measured in the client on a 1280x1310 window:
// header meta at ~1300 px, right column at ~1840 px and the achievement module
// (points shop items on these pages) at ~3590 px. A card inserted after that
// module, which is what the `achievements` position does, is three screens
// below the fold: it exists but is never seen. The header anchors below put the
// card next to the information it belongs to.
//
// The card is wrapped in a lane element because themes style `#hltb-store-data`
// itself (Aika paints it as a card). Position and width belong to the lane, so
// the card keeps whatever chrome it is given.
interface HeroTarget {
  selector: string;
  insert(anchor: HTMLElement, element: HTMLElement): void;
}

const HERO_TARGETS: HeroTarget[] = [
  {
    // Aika theme, "Cinematic" store header: the card goes under the facts strip
    // (release date, developer, publisher, tags), which closes the first screen
    selector: '.aika-cine-facts',
    insert: (anchor, element) => anchor.insertAdjacentElement('afterend', element),
  },
  {
    // Default client, header meta column (release date, developer, genres)
    selector: '#game_highlights .glance_ctn',
    insert: (anchor, element) => anchor.insertAdjacentElement('afterend', element),
  },
  {
    // Default client, header container
    selector: '#game_highlights .game_header_image_ctn',
    insert: (anchor, element) => anchor.insertAdjacentElement('afterend', element),
  },
];

const STORE_CONTAINER_SELECTORS = [...HERO_TARGETS.map(t => t.selector), SIDEBAR_SELECTOR].join(
  ', '
);

interface RenderState {
  data: HltbGameResult | null;
  showViewDetails: boolean;
  position: StorePosition;
}

let state: RenderState | null = null;
let keepAliveTimer: ReturnType<typeof setInterval> | null = null;

function isVisible(el: Element | null): el is HTMLElement {
  if (!el) return false;
  const rect = el.getBoundingClientRect();
  return rect.width > 40 && rect.height > 4;
}

function insertInHero(element: HTMLElement): boolean {
  for (const target of HERO_TARGETS) {
    const anchor = document.querySelector(target.selector);
    if (!isVisible(anchor) || !anchor.parentElement) continue;

    target.insert(anchor, element);
    return true;
  }

  return false;
}

function insertInSidebar(element: HTMLElement, position: string): boolean {
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

function getHeroLane(): HTMLElement {
  const existing = document.getElementById(HERO_LANE_ID);
  if (existing) return existing;

  const lane = document.createElement('div');
  lane.id = HERO_LANE_ID;
  return lane;
}

function place(element: HTMLElement, position: StorePosition): Placement {
  if (position === 'hero') {
    const lane = getHeroLane();
    if (element.parentElement !== lane) lane.appendChild(element);
    element.classList.add(HERO_CLASS);

    if (insertInHero(lane)) return 'hero';

    // Header not available: keep the card in view at the top of the sidebar
    element.classList.remove(HERO_CLASS);
    lane.remove();

    if (insertInSidebar(element, 'top')) return 'sidebar';
    return insertInSidebar(element, 'bottom') ? 'sidebar' : 'none';
  }

  if (insertInSidebar(element, position)) return 'sidebar';
  return insertInSidebar(element, 'bottom') ? 'sidebar' : 'none';
}

function render(): Placement {
  if (!state) return 'none';

  const element = state.data
    ? createDataDisplay(state.data, state.showViewDetails)
    : createLoadingDisplay();

  return place(element, state.position);
}

// The page keeps re-rendering while it hydrates (themes rebuild their own
// header), which can drop the card or make the header anchors appear only after
// the first placement attempt. Retry for a minute, then leave the page alone.
function keepCardMounted(): void {
  if (keepAliveTimer) clearInterval(keepAliveTimer);

  const deadline = Date.now() + 60000;
  keepAliveTimer = setInterval(() => {
    const card = document.getElementById(CONTAINER_ID);
    const inLane = card?.parentElement?.id === HERO_LANE_ID;

    if (!card) {
      render();
    } else if (state?.position === 'hero' && !inLane) {
      place(card, 'hero');
    }

    if (Date.now() > deadline) {
      clearInterval(keepAliveTimer!);
      keepAliveTimer = null;
    }
  }, 500);
}

function waitForStoreContainer(timeoutMs: number): Promise<Element | null> {
  return new Promise(resolve => {
    const find = () => document.querySelector(STORE_CONTAINER_SELECTORS);

    const found = find();
    if (found) {
      resolve(found);
      return;
    }

    const observer = new MutationObserver(() => {
      const element = find();
      if (!element) return;
      observer.disconnect();
      resolve(element);
    });

    observer.observe(document.documentElement, { childList: true, subtree: true });
    setTimeout(() => {
      observer.disconnect();
      resolve(null);
    }, timeoutMs);
  });
}

interface StoreSettings {
  showInStore: boolean;
  storePosition: StorePosition;
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
  const storePosition = settings?.storePosition || DEFAULT_POSITION;
  checkPositionOnReturn(storePosition);
  if (settings && !settings.showInStore) return;
  const showViewDetails = settings?.showStoreViewDetails !== false;
  injectStyles();

  const container = await waitForStoreContainer(5000);
  if (!container) {
    console.warn('[HLTB] Store page containers not found, skipping injection');
    return;
  }

  // Don't inject twice
  if (document.getElementById(CONTAINER_ID)) return;

  state = { data: null, showViewDetails, position: storePosition };
  if (render() === 'none') {
    state = null;
    console.warn('[HLTB] Could not find insertion point, skipping injection');
    return;
  }

  keepCardMounted();

  // Get fallback game name from the page
  const nameEl = document.querySelector('.apphub_AppName');
  const fallbackName = nameEl?.textContent?.trim();

  // Fetch data
  const result = await fetchHltbData(appId, fallbackName);

  if (!state) return;

  if (!result.data) {
    state = null;
    if (keepAliveTimer) clearInterval(keepAliveTimer);
    keepAliveTimer = null;
    document.getElementById(CONTAINER_ID)?.remove();
    return;
  }

  state.data = result.data;

  const existing = document.getElementById(CONTAINER_ID);
  if (existing) existing.replaceWith(createDataDisplay(result.data, showViewDetails));

  // Update display when background refresh completes
  if (result.refreshPromise) {
    result.refreshPromise.then(newData => {
      if (!newData || !state) return;

      state.data = newData;

      const current = document.getElementById(CONTAINER_ID);
      if (current) current.replaceWith(createDataDisplay(newData, showViewDetails));
    });
  }
}
