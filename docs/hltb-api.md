# HLTB API

This document describes the How Long To Beat API used to fetch game completion time data.

## Important Notice

How Long To Beat does not provide an official public API. The endpoint and request format documented here are reverse-engineered from their website. This API may change without notice, and usage should respect the service.

## Endpoint

```
POST https://howlongtobeat.com/api/search
```

## Request Headers

The following headers are required for successful requests:

```
Content-Type: application/json
Origin: https://howlongtobeat.com
Referer: https://howlongtobeat.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0
```

Note: CORS restrictions may prevent direct browser requests. A backend proxy may be required.

## Request Body

### TypeScript Interface

```typescript
interface HltbSearchPayload {
  searchType: 'games';
  searchTerms: string[];
  searchPage: number;
  size: number;
  searchOptions: {
    games: {
      userId: number;
      platform: string;
      sortCategory: string;
      rangeCategory: string;
      rangeTime: { min: null; max: null };
      gameplay: { perspective: string; flow: string; genre: string };
      modifier: string;
    };
    users: { sortCategory: string };
    filter: string;
    sort: number;
    randomizer: number;
  };
}
```

### Example Request

```json
{
  "searchType": "games",
  "searchTerms": ["hollow", "knight"],
  "searchPage": 1,
  "size": 50,
  "searchOptions": {
    "games": {
      "userId": 0,
      "platform": "",
      "sortCategory": "name",
      "rangeCategory": "main",
      "rangeTime": { "min": null, "max": null },
      "gameplay": { "perspective": "", "flow": "", "genre": "" },
      "modifier": "hide_dlc"
    },
    "users": { "sortCategory": "postcount" },
    "filter": "",
    "sort": 0,
    "randomizer": 0
  }
}
```

### Field Descriptions

| Field | Description |
|-------|-------------|
| searchType | Always "games" for game searches |
| searchTerms | Array of search terms (split game name by spaces) |
| searchPage | Pagination page number (1-indexed) |
| size | Number of results per page (max 50) |
| modifier | "hide_dlc" excludes DLC from results |
| sortCategory | Sort order: "name", "popular", "rating" |

## Response Format

### TypeScript Interface

```typescript
interface HltbSearchResponse {
  color: string;
  title: string;
  category: string;
  pageCurrent: number;
  pageTotal: number;
  pageSize: number;
  count: number;
  data: HltbGameResult[];
}

interface HltbGameResult {
  game_id: number;
  game_name: string;
  game_name_date: number;
  game_alias: string;
  game_type: string;
  game_image: string;
  comp_lvl_combine: number;
  comp_lvl_sp: number;
  comp_lvl_co: number;
  comp_lvl_mp: number;
  comp_lvl_spd: number;
  comp_main: number;
  comp_plus: number;
  comp_100: number;
  comp_all: number;
  comp_main_count: number;
  comp_plus_count: number;
  comp_100_count: number;
  comp_all_count: number;
  invested_co: number;
  invested_mp: number;
  invested_co_count: number;
  invested_mp_count: number;
  count_comp: number;
  count_speedrun: number;
  count_backlog: number;
  count_review: number;
  review_score: number;
  count_playing: number;
  count_retired: number;
  profile_dev: string;
  profile_popular: number;
  profile_steam: number;
  profile_platform: string;
  release_world: number;
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| game_id | HLTB internal game ID |
| game_name | Game title |
| profile_steam | Steam App ID (0 if not linked) |
| comp_main | Main story completion time in seconds |
| comp_plus | Main + Extras completion time in seconds |
| comp_100 | Completionist time in seconds |
| comp_all | All play styles average in seconds |
| comp_main_count | Number of Main story submissions |

### Time Values

Completion times are returned in seconds. Convert to hours for display:

```typescript
function formatTime(seconds: number): string {
  if (!seconds || seconds === 0) return '--';
  const hours = Math.round(seconds / 3600 * 10) / 10;
  return `${hours} hrs`;
}
```

## Game Matching

The search returns multiple results. Match the correct game using this priority:

### Priority 1: Steam App ID

If the game has a Steam link, match by `profile_steam`:

```typescript
const appIdMatch = results.find(r => r.profile_steam === steamAppId);
```

### Priority 2: Exact Name Match

Compare normalized game names:

```typescript
const exactMatch = results.find(r =>
  normalize(r.game_name) === normalize(steamGameName)
);
```

### Priority 3: Fuzzy Match

Use Levenshtein distance with a threshold:

```typescript
const fuzzyMatches = results
  .map(r => ({
    ...r,
    distance: levenshtein(normalize(steamGameName), normalize(r.game_name))
  }))
  .filter(r => r.distance < normalize(steamGameName).length * 0.3)
  .sort((a, b) => {
    if (a.distance !== b.distance) return a.distance - b.distance;
    return b.comp_main_count - a.comp_main_count;
  });

return fuzzyMatches[0] ?? null;
```

## Name Normalization

Normalize names before comparison:

```typescript
function normalize(str: string): string {
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')  // Remove diacritics
    .replace(/[^a-zA-Z0-9\-\/\s]/g, '')  // Remove special chars
    .trim();
}
```

## Caching Strategy

Implement caching to minimize API requests:

- Cache duration: 2 hours recommended
- Cache key: Steam App ID
- Store both successful results and "not found" status
- Include timestamp for TTL validation

```typescript
interface CacheEntry {
  data: HltbGameResult | null;
  timestamp: number;
  notFound: boolean;
}

const CACHE_DURATION = 2 * 60 * 60 * 1000; // 2 hours
```

## Error Handling

Handle these error scenarios:

| Error | Handling |
|-------|----------|
| Network failure | Retry with backoff, show cached data if available |
| 429 Rate Limited | Increase cache TTL, add request delays |
| 500 Server Error | Retry later, show error message |
| Empty results | Cache as "not found", show appropriate UI |
| Invalid response | Log error, do not cache |

## Rate Limiting

HLTB may rate limit aggressive requests. Mitigation strategies:

1. Cache aggressively (2+ hour TTL)
2. Debounce rapid navigation
3. Limit concurrent requests
4. Back off on 429 responses

## CORS Considerations

Browser-based requests to the HLTB API may be blocked by CORS. Options:

1. Test if CORS is enforced (may work in Steam's CEF)
2. Use Lua backend as proxy if needed
3. Consider alternative APIs (e.g., AugmentedSteam's proxy)

## Example Implementation

Complete API client:

```typescript
async function fetchHltbData(gameName: string, appId: number): Promise<HltbGameResult | null> {
  const cached = getCache(appId);
  if (cached) {
    return cached.notFound ? null : cached.data;
  }

  const searchTerms = gameName.split(/\s+/).filter(t => t.length > 0);

  const response = await fetch('https://howlongtobeat.com/api/search', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://howlongtobeat.com',
      'Referer': 'https://howlongtobeat.com'
    },
    body: JSON.stringify({
      searchType: 'games',
      searchTerms,
      searchPage: 1,
      size: 50,
      searchOptions: {
        games: {
          userId: 0,
          platform: '',
          sortCategory: 'name',
          rangeCategory: 'main',
          rangeTime: { min: null, max: null },
          gameplay: { perspective: '', flow: '', genre: '' },
          modifier: 'hide_dlc'
        },
        users: { sortCategory: 'postcount' },
        filter: '',
        sort: 0,
        randomizer: 0
      }
    })
  });

  if (!response.ok) {
    throw new Error(`HLTB API error: ${response.status}`);
  }

  const result: HltbSearchResponse = await response.json();
  const match = findBestMatch(gameName, appId, result.data);

  setCache(appId, match);
  return match;
}
```
