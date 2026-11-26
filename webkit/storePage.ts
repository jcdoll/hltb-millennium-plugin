import { callable } from '@steambrew/webkit';
import { fetchHltbData, HltbGameResult } from './hltbApi';
import { injectStyles } from './styles';

const GetSettingsRpc = callable<[], string>('GetSettings');

const CONTAINER_ID = 'hltb-store-data';

type StorePosition = 'hero' | 'top' | 'achievements' | 'details' | 'bottom';

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

function displayData(
  container: HTMLElement,
  data: HltbGameResult,
  showViewDetails: boolean,
  compact: boolean
): void {
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
    const href = data.game_id
      ? `https://howlongtobeat.com/game/${data.game_id}`
      : `https://howlongtobeat.com/?q=${encodeURIComponent(data.searched_name)}`;
    const label = compact ? 'How Long To Beat ↗' : data.game_id ? 'View Details' : 'Search HLTB';
    linkHtml = `<a class="hltb-store-link" href="${href}" target="_blank">${label}</a>`;
  }

  container.innerHTML = `
    <p class="hltb-store-title">${compact && linkHtml ? linkHtml : 'How Long To Beat'}</p>
    <div class="hltb-store-rows">${rows}</div>
    ${compact ? '' : linkHtml}
  `;
}

const SIDEBAR_SELECTOR = 'div.rightcol.game_meta_data';

// Position targets in the store sidebar (insert after the matched element)
const POSITION_SELECTORS: Record<string, string> = {
  achievements: '#achievement_block',
  details: '#appDetailsUnderlinedLinks',
};

const PRODUCT_SELECTOR = '.game_page_background .page_content_ctn';
const STORE_CONTAINER_SELECTORS = PRODUCT_SELECTOR + ', ' + SIDEBAR_SELECTOR;

function visible(element: HTMLElement | null): boolean {
  if (!element) return false;
  const box = element.getBoundingClientRect();
  if (box.width === 0 || box.height === 0) return false;
  return element.checkVisibility
    ? element.checkVisibility()
    : getComputedStyle(element).visibility !== 'hidden';
}

// Themes can move Steam's breadcrumbs out of the title area, or hide them on
// narrow windows. Keep the card in normal flow beside the title or above the art.
function mountInHeader(root: Element, card: HTMLElement): boolean {
  const crumbs = Array.from(root.querySelectorAll<HTMLElement>('.breadcrumbs'));
  const breadcrumb = crumbs.find(visible);
  let host: HTMLElement | null;
  let before: Element | null = null;
  let layout: string;

  if (breadcrumb) {
    const title = breadcrumb.closest<HTMLElement>('.page_title_area');
    host = title ?? breadcrumb;
    layout = title ? 'title' : 'crumbs';
  } else {
    const art = Array.from(root.querySelectorAll<HTMLElement>('.game_header_image_ctn')).find(visible);
    if (art) {
      host = art.parentElement;
      before = art;
      layout = 'art';
    } else {
      const moved = crumbs.find(el => !el.closest('.page_title_area') && visible(el.parentElement));
      if (!moved) return false;
      host = moved.parentElement;
      before = moved.nextElementSibling;
      layout = 'header';
    }
  }

  if (!host) return false;
  if (card.dataset.hltbHeader !== layout) card.dataset.hltbHeader = layout;
  if (host !== card.parentElement || (before && before !== card && card.nextElementSibling !== before)) {
    host.insertBefore(card, before);
  }
  return true;
}

// How long the page may stay quiet before the subtree observer is dropped. The
// store mutates a lot while it hydrates and almost not at all afterwards.
const SETTLE_MS = 30000;

function watchVisiblePlacement(root: Element, card: HTMLElement, position: StorePosition): () => void {
  let lastMove = Date.now();

  function place() {
    const previousParent = card.parentElement;

    if (position === 'hero' && mountInHeader(root, card)) {
      if (card.parentElement !== previousParent) lastMove = Date.now();
      return;
    }

    if (card.isConnected && !card.hasAttribute('data-hltb-header')) return;

    card.removeAttribute('data-hltb-header');
    const sidebar = root.matches(SIDEBAR_SELECTOR) ? root : root.querySelector(SIDEBAR_SELECTOR);
    if (!sidebar) {
      card.remove();
      return;
    }

    if (position === 'hero' || position === 'top') {
      sidebar.prepend(card);
    } else {
      const selector = POSITION_SELECTORS[position];
      const target = selector && sidebar.querySelector(selector);
      if (target) target.after(card);
      else sidebar.append(card);
    }

    if (card.parentElement !== previousParent) lastMove = Date.now();
  }

  let frame = 0;
  function schedule() {
    if (document.hidden || frame) return;
    frame = requestAnimationFrame(() => {
      frame = 0;
      place();
    });
  }

  place();

  // Keep following theme and viewport changes after the page settles.
  const layoutObserver = new MutationObserver(schedule);
  layoutObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
  window.addEventListener('resize', schedule);

  // Expensive watcher: only until the page settles.
  const pageObserver = new MutationObserver(schedule);
  pageObserver.observe(root, { childList: true, subtree: true });
  const settleTimer = setInterval(() => {
    if (Date.now() - lastMove < SETTLE_MS) return;
    pageObserver.disconnect();
    clearInterval(settleTimer);
  }, 5000);

  return () => {
    pageObserver.disconnect();
    layoutObserver.disconnect();
    clearInterval(settleTimer);
    window.removeEventListener('resize', schedule);
    cancelAnimationFrame(frame);
  };
}

function watchPlacement(root: Element, card: HTMLElement, position: StorePosition): () => void {
  let stopWatching: (() => void) | undefined;

  function pause() {
    stopWatching?.();
    stopWatching = undefined;
  }

  function syncVisibility() {
    if (document.hidden) pause();
    else if (!stopWatching) stopWatching = watchVisiblePlacement(root, card, position);
  }

  // Back can restore this document without running initStorePage again.
  document.addEventListener('visibilitychange', syncVisibility);
  window.addEventListener('pagehide', pause);
  window.addEventListener('pageshow', syncVisibility);
  syncVisibility();

  return () => {
    pause();
    document.removeEventListener('visibilitychange', syncVisibility);
    window.removeEventListener('pagehide', pause);
    window.removeEventListener('pageshow', syncVisibility);
  };
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

  const card = createLoadingDisplay();
  const root = container.closest('.game_page_background') ?? container.parentElement ?? container;
  const stopWatching = watchPlacement(root, card, storePosition);
  const name = document.querySelector('.apphub_AppName')?.textContent?.trim();
  const result = await fetchHltbData(appId, name);
  if (!result.data) {
    stopWatching();
    card.remove();
    return;
  }

  const compact = storePosition === 'hero';
  displayData(card, result.data, showViewDetails, compact);
  result.refreshPromise?.then(data => {
    if (data) displayData(card, data, showViewDetails, compact);
  });
}
