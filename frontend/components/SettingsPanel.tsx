import { DialogButton, Field } from '@steambrew/client';
import { clearCache, getCacheStats } from '../services/cache';
import { useState } from 'react';

export function SettingsPanel() {
  const [cacheCleared, setCacheCleared] = useState(false);
  const stats = getCacheStats();

  const handleClearCache = () => {
    clearCache();
    setCacheCleared(true);
    setTimeout(() => setCacheCleared(false), 2000);
  };

  const cacheInfo = stats.count > 0
    ? `${stats.count} games cached`
    : 'No cached data';

  return (
    <div>
      <Field
        label="Cache"
        description={cacheInfo}
        bottomSeparator="standard"
      >
        <DialogButton onClick={handleClearCache} disabled={cacheCleared}>
          {cacheCleared ? 'Cleared!' : 'Clear Cache'}
        </DialogButton>
      </Field>
      <Field
        label="About"
        description="HLTB data is fetched from howlongtobeat.com and cached for 2 hours."
        bottomSeparator="none"
      />
    </div>
  );
}
