import { Millennium, sleep } from '@steambrew/client';
import { fetchHltbData, formatTime, type HltbGameResult } from './services/hltbApi';

let steamDocument: Document | undefined;
let currentAppId: number | null = null;
let observer: MutationObserver | null = null;

// Styles matching hltb-for-deck
const HLTB_STYLES = `
#hltb-for-millennium {
  position: absolute;
  bottom: 0;
  right: 0;
  width: fit-content;
  z-index: 100;
}

.hltb-info {
  background: rgba(14, 20, 27, 0.85);
  border-top: 2px solid rgba(61, 68, 80, 0.54);
  padding: 8px 0;
}

.hltb-info ul {
  list-style: none;
  padding: 0 20px;
  margin: 0;
  display: flex;
  justify-content: space-evenly;
  align-items: center;
}

.hltb-info ul li {
  text-align: center;
  padding: 0 10px;
}

.hltb-info p {
  margin: 0;
  color: #ffffff;
}

.hltb-gametime {
  font-size: 16px;
  font-weight: bold;
}

.hltb-label {
  text-transform: uppercase;
  font-size: 10px;
  opacity: 0.7;
}

.hltb-details-btn {
  background: transparent;
  border: none;
  color: #1a9fff;
  font-size: 10px;
  font-weight: bold;
  text-transform: uppercase;
  cursor: pointer;
  padding: 5px 10px;
}

.hltb-details-btn:hover {
  color: #ffffff;
}
`;

function injectStyles(): void {
  if (!steamDocument || steamDocument.getElementById('hltb-styles')) return;
  const style = steamDocument.createElement('style');
  style.id = 'hltb-styles';
  style.textContent = HLTB_STYLES;
  steamDocument.head.appendChild(style);
}

function removeExisting(): void {
  steamDocument?.getElementById('hltb-for-millennium')?.remove();
}

function createLoadingDisplay(): HTMLElement {
  const container = steamDocument!.createElement('div');
  container.id = 'hltb-for-millennium';

  container.innerHTML = `
    <div class="hltb-info">
      <ul>
        <li>
          <p class="hltb-gametime">--</p>
          <p class="hltb-label">Main Story</p>
        </li>
        <li>
          <p class="hltb-gametime">--</p>
          <p class="hltb-label">Main + Extras</p>
        </li>
        <li>
          <p class="hltb-gametime">--</p>
          <p class="hltb-label">Completionist</p>
        </li>
      </ul>
    </div>
  `;

  return container;
}

function createDisplay(data: HltbGameResult): HTMLElement {
  const container = steamDocument!.createElement('div');
  container.id = 'hltb-for-millennium';

  const hltbUrl = `https://howlongtobeat.com/game/${data.game_id}`;

  let statsHtml = '';

  if (data.comp_main > 0) {
    statsHtml += `
      <li>
        <p class="hltb-gametime">${formatTime(data.comp_main)}</p>
        <p class="hltb-label">Main Story</p>
      </li>`;
  }

  if (data.comp_plus > 0) {
    statsHtml += `
      <li>
        <p class="hltb-gametime">${formatTime(data.comp_plus)}</p>
        <p class="hltb-label">Main + Extras</p>
      </li>`;
  }

  if (data.comp_100 > 0) {
    statsHtml += `
      <li>
        <p class="hltb-gametime">${formatTime(data.comp_100)}</p>
        <p class="hltb-label">Completionist</p>
      </li>`;
  }

  statsHtml += `
    <li>
      <button class="hltb-details-btn" onclick="window.open('steam://openurl_external/${hltbUrl}')">
        View Details
      </button>
    </li>`;

  container.innerHTML = `
    <div class="hltb-info">
      <ul>${statsHtml}</ul>
    </div>
  `;

  return container;
}

async function checkAndInject(): Promise<void> {
  // Find the header image element
  const headerImg = steamDocument?.querySelector('._3NBxSLAZLbbbnul8KfDFjw._2dzwXkCVAuZGFC-qKgo8XB') as HTMLImageElement | null;

  if (!headerImg) {
    return;
  }

  const src = headerImg.src || '';
  const match = src.match(/\/assets\/(\d+)/);
  if (!match) {
    return;
  }

  const appId = parseInt(match[1], 10);

  if (appId === currentAppId) {
    return;
  }

  currentAppId = appId;
  removeExisting();

  const headerContainer = headerImg.closest('._2aPcBP45fdgOK22RN0jbhm');
  if (!headerContainer) {
    return;
  }

  // Show loading placeholder immediately
  (headerContainer as HTMLElement).style.position = 'relative';
  headerContainer.appendChild(createLoadingDisplay());

  try {
    const result = await fetchHltbData(appId);
    const existing = steamDocument?.getElementById('hltb-for-millennium');

    const updateDisplay = (data: typeof result.data) => {
      if (data && (data.comp_main > 0 || data.comp_plus > 0 || data.comp_100 > 0)) {
        if (existing) {
          existing.innerHTML = createDisplay(data).innerHTML;
        }
        return true;
      }
      return false;
    };

    updateDisplay(result.data);

    // Handle background refresh for stale data
    if (result.refreshPromise) {
      result.refreshPromise.then((newData) => {
        if (newData && currentAppId === appId) {
          updateDisplay(newData);
        }
      });
    }
  } catch (e) {
    // Keep placeholder on error
  }
}

function setupObserver(): void {
  if (!steamDocument) return;

  observer = new MutationObserver(() => {
    checkAndInject();
  });

  observer.observe(steamDocument.body, {
    childList: true,
    subtree: true,
  });

  // Initial check
  checkAndInject();
}

async function init(): Promise<void> {
  // @ts-ignore
  while (!steamDocument) {
    // @ts-ignore
    steamDocument = SteamUIStore?.WindowStore?.SteamUIWindows?.[0]?.m_BrowserWindow?.document;
    await sleep(500);
  }

  injectStyles();
  setupObserver();
}

init();

export default async function PluginMain() {
  // Plugin initialization is handled by init()
}
