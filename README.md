# HLTB for Millennium

A [Millennium](https://steambrew.app/) plugin that displays [How Long To Beat](https://howlongtobeat.com/) completion time data on game pages in the Steam library.

## Features

- Displays HLTB completion times directly on game detail pages
  - Main Story
  - Main + Extras
  - Completionist
  - All Styles average
- Automatic game matching via Steam App ID and fuzzy name search
- Local caching to minimize API requests (2 hour TTL)
- Configurable display options
- Support for Desktop UI and Big Picture mode

## Requirements

- [Millennium](https://steambrew.app/) installed on Steam
- Windows or Linux

## Installation

### From Plugin Database (Recommended)

1. Open Steam
2. Go to Millennium Settings > Plugins
3. Click "Install a plugin"
4. Search for "HLTB for Steam"
5. Click Install

### Manual Installation

1. Download the latest release
2. Extract to `<Steam>/plugins/hltb-for-millennium/`
3. Restart Steam

## Usage

Once installed, HLTB data automatically appears on game pages in your Steam library. Click any game to see its completion times.

### Settings

Access plugin settings through Millennium Settings > Plugins > HLTB for Steam:

- Toggle individual stat categories on/off
- Clear the local cache

## Development

See the [docs](docs/) folder for development documentation.

Quick start:

```bash
# Install dependencies
bun install

# Development build with watch
bun watch

# Start Steam in dev mode
steam -dev
```

## How It Works

The plugin queries the How Long To Beat website when you view a game, matches it against your Steam library using App ID and game name, then displays the completion time estimates. Results are cached locally to avoid repeated requests.

## Known Limitations

- Games not in the HLTB database will show no data
- Some games may not match correctly due to name differences
- Big Picture mode has some known issues (see [docs](docs/big-picture-mode.md))

## Credits

- [HLTB for Deck](https://github.com/hulkrelax/hltb-for-deck) - Original Decky plugin that inspired this project
- [How Long To Beat](https://howlongtobeat.com/) - Data source
- [Millennium](https://steambrew.app/) - Plugin framework

## License

MIT
