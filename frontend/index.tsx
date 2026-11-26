import { useState, useEffect } from 'react';
import { definePlugin, Millennium, IconsModule, Field, DialogButton, callable } from '@steambrew/client';
import { log, logError } from './services/logger';
import type { UIMode } from './types';
import type { StorePosition } from './services/settings';
import { setupObserver, resetState, disconnectObserver, refreshDisplay } from './injection/observer';
import { exposeDebugTools, removeDebugTools } from './debug/tools';
import { removeStyles } from './display/styles';
import { removeExistingDisplay } from './display/components';
import { getSettings, saveSettings, initSettings } from './services/settings';
import { initializeIdCache } from './services/hltbApi';

const GetCacheStats = callable<[], string>('GetCacheStats');
const ClearCacheRpc = callable<[], string>('ClearCache');

let currentDocument: Document | undefined;
let currentUIMode: UIMode | undefined;
let initializedForUserId: string | null = null;

const STORE_POSITION_OPTIONS = [
  { value: 'top', label: 'Sidebar start' },
  { value: 'achievements', label: 'Achievements' },
  { value: 'details', label: 'Game details' },
  { value: 'bottom', label: 'Sidebar end' },
];

const sectionHeaderStyle = { fontSize: '16px', fontWeight: 'bold' as const, textTransform: 'uppercase' as const, letterSpacing: '1px' };
const sectionDescStyle = { fontSize: '11px', color: '#8f98a0', padding: '4px 0 8px', borderBottom: '1px solid rgba(255,255,255,0.1)' };

function reloadOpenStoreGame(): void {
  const { MainWindowBrowserManager: browser } = window as Window & {
    MainWindowBrowserManager?: { DisplayURL: string; Reload?(): void };
  };
  if (browser && /^https:\/\/store\.steampowered\.com\/app\/\d+(?:[/?#]|$)/i.test(browser.DisplayURL)) {
    try {
      browser.Reload?.();
    } catch (error) {
      logError('Store position saved, but Steam could not reload the page:', error);
    }
  }
}

const SettingsContent = () => {
  const [message, setMessage] = useState('');
  const [showInLibrary, setShowInLibrary] = useState(true);
  const [showInStore, setShowInStore] = useState(true);
  const [horizontalOffset, setHorizontalOffset] = useState('0');
  const [verticalOffset, setVerticalOffset] = useState('0');
  const [showViewDetails, setShowViewDetails] = useState(true);
  const [alignRight, setAlignRight] = useState(true);
  const [alignBottom, setAlignBottom] = useState(true);
  const [storePosition, setStorePosition] = useState('achievements');
  const [showStoreViewDetails, setShowStoreViewDetails] = useState(true);

  useEffect(() => {
    const settings = getSettings();
    setShowInLibrary(settings.showInLibrary);
    setShowInStore(settings.showInStore);
    setHorizontalOffset(String(settings.horizontalOffset));
    setVerticalOffset(String(settings.verticalOffset));
    setShowViewDetails(settings.showViewDetails);
    setAlignRight(settings.alignRight);
    setAlignBottom(settings.alignBottom);
    setStorePosition(settings.storePosition);
    setShowStoreViewDetails(settings.showStoreViewDetails);
  }, []);

  const onShowInLibraryChange = async (checked: boolean) => {
    setShowInLibrary(checked);
    await saveSettings({ ...getSettings(), showInLibrary: checked });
    refreshDisplay();
  };

  const onShowInStoreChange = async (checked: boolean) => {
    setShowInStore(checked);
    await saveSettings({ ...getSettings(), showInStore: checked });
  };

  const onStorePositionChange = async (e: React.ChangeEvent<HTMLSelectElement>) => {
    const value = e.target.value as StorePosition;
    if (value === getSettings().storePosition) return;
    setStorePosition(value);
    if (await saveSettings({ ...getSettings(), storePosition: value })) {
      reloadOpenStoreGame();
    } else {
      setStorePosition(getSettings().storePosition);
    }
  };

  const onShowStoreViewDetailsChange = async (checked: boolean) => {
    setShowStoreViewDetails(checked);
    await saveSettings({ ...getSettings(), showStoreViewDetails: checked });
  };

  const onHorizontalOffsetChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setHorizontalOffset(value);
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      await saveSettings({ ...getSettings(), horizontalOffset: numValue });
      refreshDisplay();
    }
  };

  const onVerticalOffsetChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setVerticalOffset(value);
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      await saveSettings({ ...getSettings(), verticalOffset: numValue });
      refreshDisplay();
    }
  };

  const onShowViewDetailsChange = async (checked: boolean) => {
    setShowViewDetails(checked);
    await saveSettings({ ...getSettings(), showViewDetails: checked });
    refreshDisplay();
  };

  const onAlignRightChange = async (checked: boolean) => {
    setAlignRight(checked);
    await saveSettings({ ...getSettings(), alignRight: checked });
    refreshDisplay();
  };

  const onAlignBottomChange = async (checked: boolean) => {
    setAlignBottom(checked);
    await saveSettings({ ...getSettings(), alignBottom: checked });
    refreshDisplay();
  };

  const onCacheStats = async () => {
    try {
      const resultJson = await GetCacheStats();
      const result = JSON.parse(resultJson);
      if (!result.success) {
        setMessage('Failed to get cache stats');
        return;
      }

      const { resultCache, idCache } = result.data;
      const lines: string[] = [];

      if (resultCache.count === 0) {
        lines.push('0 games cached');
      } else {
        const age = resultCache.oldestTimestamp
          ? Math.round((Date.now() / 1000 - resultCache.oldestTimestamp) / (60 * 60 * 24))
          : 0;
        lines.push(`${resultCache.count} games cached, oldest ${age}d`);
      }

      if (idCache.count === 0) {
        lines.push('0 ID mappings');
      } else {
        const age = idCache.ageSeconds
          ? Math.round(idCache.ageSeconds / (60 * 60 * 24))
          : 0;
        lines.push(`${idCache.count} ID mappings, ${age}d old`);
      }

      setMessage(lines.join('\n'));
    } catch {
      setMessage('Failed to get cache stats');
    }
  };

  const onClearCache = async () => {
    try {
      await ClearCacheRpc();
      setMessage('All caches cleared');
    } catch {
      setMessage('Failed to clear cache');
    }
  };

  return (
    <>
      {/* Library View */}
      <div style={sectionHeaderStyle}>Library View</div>
      <div style={sectionDescStyle}>Changes apply immediately</div>
      <Field label="Show in Library" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={showInLibrary}
          onChange={(e) => onShowInLibraryChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>
      <Field label="Horizontal Offset (px)" description="Distance from edge, negative values OK" bottomSeparator="standard">
        <input
          type="number"
          value={horizontalOffset}
          onChange={onHorizontalOffsetChange}
          style={{ width: '60px', padding: '4px 8px' }}
        />
      </Field>
      <Field label="Vertical Offset (px)" description="Distance from edge, negative values OK" bottomSeparator="standard">
        <input
          type="number"
          value={verticalOffset}
          onChange={onVerticalOffsetChange}
          style={{ width: '60px', padding: '4px 8px' }}
        />
      </Field>
      <Field label="Align to Right" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={alignRight}
          onChange={(e) => onAlignRightChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>
      <Field label="Align to Bottom" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={alignBottom}
          onChange={(e) => onAlignBottomChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>
      <Field label="Show View Details Link" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={showViewDetails}
          onChange={(e) => onShowViewDetailsChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>

      {/* Store View */}
      <div style={{ ...sectionHeaderStyle, paddingTop: '28px' }}>Store View</div>
      <div style={sectionDescStyle}>Changing position reloads the open Store game page. Other changes apply on the next page load.</div>
      <Field label="Show in Store" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={showInStore}
          onChange={(e) => onShowInStoreChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>
      <Field label="Position" bottomSeparator="standard">
        <select
          value={storePosition}
          onChange={onStorePositionChange}
          style={{ padding: '4px 8px' }}
        >
          {STORE_POSITION_OPTIONS.map(opt => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      </Field>
      <Field label="Show View Details Link" bottomSeparator="standard">
        <input
          type="checkbox"
          checked={showStoreViewDetails}
          onChange={(e) => onShowStoreViewDetailsChange(e.target.checked)}
          style={{ width: '20px', height: '20px' }}
        />
      </Field>

      {/* Cache */}
      <div style={{ ...sectionHeaderStyle, padding: '28px 0 8px', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>Cache</div>
      <Field label="Cache Statistics" bottomSeparator="standard">
        <DialogButton onClick={onCacheStats} style={{ padding: '4px 12px' }}>View Stats</DialogButton>
      </Field>
      <Field label="Clear Cache" bottomSeparator="standard">
        <DialogButton onClick={onClearCache} style={{ padding: '4px 12px' }}>Clear</DialogButton>
      </Field>
      {message && <div style={{ fontSize: '12px', color: '#8f98a0', padding: '8px 0' }}>{message.split('\n').map((line, i) => (
        <div key={i}>{line}</div>
      ))}</div>}
    </>
  );
};

export default definePlugin(() => {
  log('HLTB plugin loading...');

  // Start loading settings from backend in background (non-blocking)
  initSettings();

  Millennium.AddWindowCreateHook?.((context: any) => {
    // Only handle main Steam windows (Desktop or Big Picture)
    if (!context.m_strName?.startsWith('SP ')) return;

    const doc = context.m_popup?.document;
    if (!doc?.body) return;

    const mode: UIMode = context.m_strName.includes('BPM') ? 'bigpicture' : 'desktop';
    log('Window created:', context.m_strName, '(' + mode + ')');

    // Clean up old document/mode before switching
    const documentChanged = currentDocument && currentDocument !== doc;
    const modeChanged = currentUIMode !== undefined && currentUIMode !== mode;
    if (documentChanged || modeChanged) {
      log('Mode/document switch detected, cleaning up');
      if (currentDocument) {
        removeDebugTools(currentDocument);
        removeStyles(currentDocument);
        removeExistingDisplay(currentDocument);
      }
      disconnectObserver();
    }

    currentDocument = doc;
    currentUIMode = mode;
    setupObserver(doc, mode);
    exposeDebugTools(doc);

    // Initialize ID cache in background (non-blocking)
    // Skip if already successfully initialized for this user ID
    const steamUserId = (window as any).App?.m_CurrentUser?.strSteamID;
    if (steamUserId && steamUserId !== initializedForUserId) {
      initializeIdCache(steamUserId).then((success) => {
        if (success) {
          initializedForUserId = steamUserId;
          log('ID cache initialized successfully');
        }
      });
    }
  });

  return {
    title: 'HLTB for Steam',
    icon: <IconsModule.Settings />,
    content: <SettingsContent />,
  };
});
