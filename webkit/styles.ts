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

/* Header placement. The lane carries the position and the width so that the
   card keeps its own chrome, including the one themes give it. */
#hltb-store-hero-lane {
  box-sizing: border-box;
  display: flex;
  justify-content: flex-start;
  max-width: 1316px;
  width: calc(100% - 32px);
  margin: 12px auto 2px;
  /* themes draw the header with an absolutely positioned media stage; a
     positioned lane keeps the card above it instead of behind the artwork */
  position: relative;
  z-index: 2;
}

#hltb-store-data.hltb-store-hero {
  display: inline-flex;
  flex-direction: column;
  box-sizing: border-box;
  max-width: 100%;
  margin: 0;
  padding: 11px 16px 12px;
  background: rgba(10, 14, 18, 0.62);
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-radius: 8px;
  box-shadow: 0 4px 18px rgba(0, 0, 0, 0.35);
}

#hltb-store-data.hltb-store-hero .hltb-store-title {
  margin: 0 0 9px 0;
  letter-spacing: 1.2px;
}

#hltb-store-data.hltb-store-hero .hltb-store-rows {
  flex-direction: row;
  gap: 34px;
}

#hltb-store-data.hltb-store-hero .hltb-store-row {
  flex-direction: column;
  align-items: flex-start;
  gap: 1px;
  font-size: 11px;
  line-height: 1.2;
}

#hltb-store-data.hltb-store-hero .hltb-store-row span {
  color: #ffffff;
  font-size: 16px;
  line-height: 1.15;
}

#hltb-store-data.hltb-store-hero .hltb-store-link {
  margin-top: 9px;
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
