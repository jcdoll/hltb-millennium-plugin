import { log } from '../services/logger';
import { LIBRARY_SELECTORS } from '../types';
import { clearCache, getCacheStats } from '../services/cache';

export function logDOMStructure(doc: Document, selector?: string): void {
  log('=== DOM Structure Debug ===');
  log('Document title:', doc.title);
  log('Body classes:', doc.body?.className);

  if (selector) {
    const elements = doc.querySelectorAll(selector);
    log(`Found ${elements.length} elements matching "${selector}"`);
    elements.forEach((el, i) => {
      log(`  [${i}]`, el.tagName, el.className, el.id);
    });
  }

  // Log images with /assets/ to help find game page selectors
  const images = doc.querySelectorAll('img[src*="/assets/"]');
  log(`Found ${images.length} images with /assets/ in src`);
  images.forEach((img, i) => {
    const imgEl = img as HTMLImageElement;
    log(`  [${i}] src: ${imgEl.src}`);
    log(`       class: ${imgEl.className}`);
    log(`       parent classes:`, imgEl.parentElement?.className);

    let parent = imgEl.parentElement;
    for (let level = 1; level <= 5 && parent; level++) {
      log(`       ancestor ${level}: ${parent.tagName}.${parent.className.split(' ')[0] || '(no class)'}`);
      parent = parent.parentElement;
    }
  });

  log('=== End DOM Debug ===');
}

export function exposeDebugTools(doc: Document): void {
  const debugObj = {
    logDOM: (selector?: string) => logDOMStructure(doc, selector),
    getSelectors: () => LIBRARY_SELECTORS,
    findImages: () => {
      const images = doc.querySelectorAll('img');
      images.forEach((img, i) => {
        log(`[${i}] ${(img as HTMLImageElement).src} - class: ${img.className}`);
      });
    },
    findByClass: (className: string) => {
      const elements = doc.querySelectorAll(`.${className}`);
      log(`Found ${elements.length} elements with class "${className}"`);
      elements.forEach((el, i) => {
        log(`  [${i}]`, el.tagName, el.className);
      });
    },
    inspectElement: (selector: string) => {
      const el = doc.querySelector(selector);
      if (!el) {
        log('No element found for selector:', selector);
        return;
      }
      log('Element:', el.tagName);
      log('Classes:', el.className);
      log('ID:', el.id);
      log('Children:', el.children.length);
      Array.from(el.children).forEach((child, i) => {
        log(`  [${i}] ${child.tagName}.${child.className.split(' ')[0] || '(no class)'}`);
      });
    },
    clearCache: () => {
      clearCache();
      log('Cache cleared. Refresh or navigate to a game to fetch fresh data.');
    },
    cacheStats: () => {
      const stats = getCacheStats();
      log('Cache entries:', stats.count);
      if (stats.oldestTimestamp) {
        const age = Math.round((Date.now() - stats.oldestTimestamp) / (1000 * 60 * 60 * 24));
        log('Oldest entry:', age, 'days old');
      }
      return stats;
    },
  };

  // @ts-ignore
  if (doc.defaultView) {
    // @ts-ignore
    doc.defaultView.hltbDebug = debugObj;
  }
  // @ts-ignore
  globalThis.hltbDebug = debugObj;

  log('Debug tools exposed. Use hltbDebug.logDOM(), hltbDebug.findImages(), etc.');
}

export function removeDebugTools(doc: Document): void {
  // @ts-ignore
  if (doc.defaultView) {
    // @ts-ignore
    delete doc.defaultView.hltbDebug;
  }
  // @ts-ignore
  delete globalThis.hltbDebug;
}
