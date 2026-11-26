const STORE_STYLES = `
#hltb-store-data {
  background: rgba(0, 0, 0, 0.2);
  padding: 12px 16px;
  margin-bottom: 12px;
  border-radius: 2px;
}

#hltb-store-data .hltb-store-title {
  color: #556772;
  font-size: 10px;
  font-weight: bold;
  text-transform: uppercase;
  letter-spacing: 1px;
  margin: 0 0 8px 0;
}

#hltb-store-data .hltb-store-rows {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

#hltb-store-data .hltb-store-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: #8f98a0;
  font-size: 12px;
  line-height: 20px;
}

#hltb-store-data .hltb-store-row span {
  color: #acb2b8;
  font-weight: bold;
}

#hltb-store-data .hltb-store-link {
  display: block;
  margin-top: 8px;
  color: #67c1f5;
  font-size: 11px;
  text-decoration: none;
}

#hltb-store-data .hltb-store-link:hover {
  color: #ffffff;
}

#hltb-store-data .hltb-store-loading {
  color: #8f98a0;
  font-size: 12px;
}

/* Compact Store header. The containing row changes only while the card is in it. */
.page_title_area:has(> [data-hltb-header="title"]) {
  display: grid;
  grid-template-columns: minmax(0, 1fr) max-content;
  align-items: center;
  column-gap: 14px;
}

.page_title_area:has(> [data-hltb-header="title"]) > :is(.breadcrumbs, .apphub_HomeHeaderContent) {
  grid-column: 1;
  min-width: 0;
}

.page_title_area:has(> [data-hltb-header="title"]) > .apphub_HomeHeaderContent {
  width: 100%;
  margin-inline: 0;
}

#hltb-store-data[data-hltb-header="title"] {
  grid-column: 2;
  grid-row: 1 / span 2;
}

.breadcrumbs:has(> [data-hltb-header="crumbs"]) {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 4px 12px;
  box-sizing: border-box;
}

.breadcrumbs:has(> [data-hltb-header="crumbs"]) > div:empty { display: none; }

#hltb-store-data[data-hltb-header] {
  position: relative;
  z-index: 1;
  box-sizing: border-box;
  width: max-content;
  max-width: 100%;
  flex: 0 0 auto;
  margin: 0;
  margin-inline-start: auto;
  padding: 7px 12px 8px;
  background: #19232d;
  border: 1px solid #ffffff26;
  border-radius: 5px;
  box-shadow: none;
  text-align: left;
}

#hltb-store-data[data-hltb-header="art"] { margin-block-end: 6px; }

#hltb-store-data[data-hltb-header] .hltb-store-title,
#hltb-store-data[data-hltb-header] .hltb-store-title a {
  display: block;
  margin: 0;
  padding: 0;
  color: #b7c9d9;
  font-family: inherit;
  font-weight: 600;
  font-size: 10px;
  line-height: 12px;
  text-transform: uppercase;
  letter-spacing: .7px;
  text-decoration: none;
}

#hltb-store-data[data-hltb-header] .hltb-store-title a:hover { color: white; }

#hltb-store-data[data-hltb-header] .hltb-store-rows {
  display: grid;
  grid-template-columns: repeat(3, max-content);
  gap: 16px;
  margin: 4px 0 0;
  padding: 0;
}

#hltb-store-data[data-hltb-header] .hltb-store-row {
  flex-direction: column;
  align-items: flex-start;
  white-space: nowrap;
  color: #b0bdc7;
  font-size: 10px;
  line-height: 13px;
  gap: 0;
}

#hltb-store-data[data-hltb-header] .hltb-store-row span {
  color: #edf3f7;
  font-size: 15px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  line-height: 17px;
}
`;

const STYLE_ID = 'hltb-store-styles';

export function injectStyles(): void {
  if (document.getElementById(STYLE_ID)) return;

  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = STORE_STYLES;
  document.head.appendChild(style);
}
