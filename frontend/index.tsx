import { definePlugin, Millennium, IconsModule, Field, DialogButton } from '@steambrew/client';
import { log } from './services/logger';
import { LIBRARY_SELECTORS } from './types';
import { setupObserver, resetState, disconnectObserver } from './injection/observer';
import { exposeDebugTools, removeDebugTools } from './debug/tools';
import { removeStyles } from './display/styles';
import { removeExistingDisplay } from './display/components';
import { clearCache, getCacheStats } from './services/cache';

const { useState } = (window as any).SP_REACT;

let currentDocument: Document | undefined;

const SettingsContent = () => {
  const [message, setMessage] = useState('');

  const onCacheStats = () => {
    const stats = getCacheStats();
    if (stats.count === 0) {
      setMessage('Cache is empty');
    } else {
      const age = stats.oldestTimestamp
        ? Math.round((Date.now() - stats.oldestTimestamp) / (1000 * 60 * 60 * 24))
        : 0;
      setMessage(`${stats.count} games cached, oldest is ${age} days old`);
    }
  };

  const onClearCache = () => {
    clearCache();
    setMessage('Cache cleared');
  };

  return (
    <>
      <Field label="Cache Statistics" bottomSeparator="standard">
        <DialogButton onClick={onCacheStats} style={{ padding: '8px 16px' }}>View Stats</DialogButton>
      </Field>
      <Field label="Clear Cache" bottomSeparator="standard">
        <DialogButton onClick={onClearCache} style={{ padding: '8px 16px' }}>Clear</DialogButton>
      </Field>
      {message && <Field description={message} />}
    </>
  );
};

export default definePlugin(() => {
  log('HLTB plugin loading...');

  Millennium.AddWindowCreateHook?.((context: any) => {
    // Only handle main Steam windows (Desktop or Big Picture)
    if (!context.m_strName?.startsWith('SP ')) return;

    const doc = context.m_popup?.document;
    if (!doc?.body) return;

    log('Window created:', context.m_strName);

    // Clean up old document if switching modes
    if (currentDocument && currentDocument !== doc) {
      log('Mode switch detected, cleaning up old document');
      removeDebugTools(currentDocument);
      removeStyles(currentDocument);
      removeExistingDisplay(currentDocument);
      disconnectObserver();
      resetState();
    }

    currentDocument = doc;
    setupObserver(doc, LIBRARY_SELECTORS);
    exposeDebugTools(doc);
  });

  return {
    title: 'HLTB for Steam',
    icon: <IconsModule.Settings />,
    content: <SettingsContent />,
  };
});
