import { callable } from '@steambrew/client';
import { log, logError } from './logger';

export type StorePosition = 'top' | 'achievements' | 'details' | 'bottom';

export interface PluginSettings {
  showInLibrary: boolean;
  showInStore: boolean;
  showViewDetails: boolean;
  alignRight: boolean;
  alignBottom: boolean;
  horizontalOffset: number;
  verticalOffset: number;
  storePosition: StorePosition;
  showStoreViewDetails: boolean;
}

interface SettingsResponse {
  success: boolean;
  error?: string;
  data?: PluginSettings;
}

const DEFAULT_SETTINGS: PluginSettings = {
  showInLibrary: true,
  showInStore: true,
  showViewDetails: true,
  alignRight: true,
  alignBottom: true,
  horizontalOffset: 0,
  verticalOffset: 0,
  storePosition: 'achievements' as StorePosition,
  showStoreViewDetails: true,
};

const GetSettingsRpc = callable<[], string>('GetSettings');
const SaveSettingsRpc = callable<[{ settings_json: string }], string>('SaveSettings');

let savedSettings: PluginSettings = { ...DEFAULT_SETTINGS };
let cachedSettings = savedSettings;
let pendingSave = Promise.resolve(true);

export async function initSettings(): Promise<void> {
  const previous = savedSettings;
  try {
    const resultJson = await GetSettingsRpc();
    if (!resultJson) return;

    const result: SettingsResponse = JSON.parse(resultJson);
    if (result.success && result.data && savedSettings === previous) {
      savedSettings = { ...DEFAULT_SETTINGS, ...result.data };
      if (cachedSettings === previous) cachedSettings = savedSettings;
      log('Settings loaded from backend');
    }
  } catch (e) {
    logError('Failed to load settings:', e);
  }
}

export function getSettings(): PluginSettings {
  return cachedSettings;
}

export function saveSettings(settings: PluginSettings): Promise<boolean> {
  cachedSettings = settings;
  // Each RPC writes the entire settings file. Preserve the order of UI edits.
  pendingSave = pendingSave.then(() => persistSettings(settings));
  return pendingSave;
}

async function persistSettings(settings: PluginSettings): Promise<boolean> {
  try {
    const resultJson = await SaveSettingsRpc({ settings_json: JSON.stringify(settings) });
    const result: SettingsResponse | null = resultJson ? JSON.parse(resultJson) : null;
    if (result?.success) {
      savedSettings = settings;
      return true;
    }
    logError('Failed to save settings:', result?.error ?? 'No confirmation from backend');
  } catch (e) {
    logError('Failed to save settings:', e);
  }
  if (cachedSettings === settings) cachedSettings = savedSettings;
  return false;
}
