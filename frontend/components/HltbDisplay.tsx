import { type HltbGameResult, formatTime } from '../services/hltbApi';

interface HltbDisplayProps {
  data: HltbGameResult;
}

interface StatItemProps {
  label: string;
  value: string;
  count?: number;
}

function StatItem({ label, value, count }: StatItemProps) {
  return (
    <div className="hltb-stat">
      <span className="hltb-stat-label">{label}</span>
      <span className="hltb-stat-value">{value}</span>
      {count !== undefined && count > 0 && (
        <span className="hltb-stat-count">({count})</span>
      )}
    </div>
  );
}

export function HltbDisplay({ data }: HltbDisplayProps) {
  const hltbUrl = `https://howlongtobeat.com/game/${data.game_id}`;

  return (
    <div className="hltb-container" id="hltb-for-millennium">
      <div className="hltb-header">
        <span className="hltb-title">How Long To Beat</span>
        <a
          className="hltb-link"
          href={hltbUrl}
          target="_blank"
          rel="noopener noreferrer"
        >
          View
        </a>
      </div>
      <div className="hltb-stats">
        <StatItem
          label="Main"
          value={formatTime(data.comp_main)}
          count={data.comp_main_count}
        />
        <StatItem
          label="Main+"
          value={formatTime(data.comp_plus)}
          count={data.comp_plus_count}
        />
        <StatItem
          label="100%"
          value={formatTime(data.comp_100)}
          count={data.comp_100_count}
        />
        <StatItem
          label="All"
          value={formatTime(data.comp_all)}
          count={data.comp_all_count}
        />
      </div>
    </div>
  );
}

export function HltbLoading() {
  return (
    <div className="hltb-container hltb-loading" id="hltb-for-millennium">
      <div className="hltb-header">
        <span className="hltb-title">How Long To Beat</span>
      </div>
      <div className="hltb-stats">
        <span>Loading...</span>
      </div>
    </div>
  );
}

export function HltbError({ message }: { message?: string }) {
  return (
    <div className="hltb-container hltb-error" id="hltb-for-millennium">
      <div className="hltb-header">
        <span className="hltb-title">How Long To Beat</span>
      </div>
      <div className="hltb-stats">
        <span>{message || 'No data available'}</span>
      </div>
    </div>
  );
}
