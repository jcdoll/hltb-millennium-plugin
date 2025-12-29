import type { LibrarySelectors, GamePageInfo } from '../types';

function tryExtractGamePage(
  doc: Document,
  imageSelector: string,
  containerSelector: string,
  appIdPattern: RegExp
): GamePageInfo | null {
  const img = doc.querySelector(imageSelector) as HTMLImageElement | null;
  if (!img) return null;

  const src = img.src || '';
  const match = src.match(appIdPattern);
  if (!match) return null;

  const appId = parseInt(match[1], 10);
  const container = img.closest(containerSelector) as HTMLElement | null;
  if (!container) return null;

  return { appId, container };
}

export function detectGamePage(doc: Document, selectors: LibrarySelectors): GamePageInfo | null {
  // Try primary selector first (logo.png), then fallback (library_hero.jpg)
  return (
    tryExtractGamePage(doc, selectors.headerImageSelector, selectors.containerSelector, selectors.appIdPattern) ||
    tryExtractGamePage(doc, selectors.fallbackImageSelector, selectors.containerSelector, selectors.appIdPattern)
  );
}
