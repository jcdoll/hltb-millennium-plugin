# HLTB for Steam

A [Millennium](https://steambrew.app/) plugin that displays [How Long To Beat](https://howlongtobeat.com/) completion times on game pages in the Steam library and store.

![Desktop Mode](example_desktop.png)

![Big Picture Mode](example_bigPictureMode.png)

## Features

> [!IMPORTANT]
> HLTB does not have an official public API. This plugin relies on undocumented endpoints that can change without notice. When that happens, the plugin will stop working until the code is updated. This may take a week or more unless you submit a PR.

- Shows HLTB completion times on library game pages and store pages:
  - Main Story
  - Main + Extras
  - Completionist
- Works in both Desktop and Big Picture modes
- Caches results to disk, optionally clear via the settings page
- Click "View Details" to open the full HLTB page

## Requirements

- [Millennium](https://steambrew.app/) installed on Steam
- Windows or Linux

## Installation

1. Ensure you have Millennium installed on your Steam client
2. Navigate to HLTB from the [plugins page](https://steambrew.app/plugins)
3. Click the "Copy Plugin ID" button
4. Back in Steam, go to Steam menu > Millenium > Plugins > Install a plugin and paste the code
5. Follow the remaining instructions to install and enable the plugin

## Usage

Once installed, HLTB data automatically appears on game pages in your Steam library and on store pages. Simply click on any game to see its completion times.

## How It Works

On startup, if your Steam profile is public, the plugin fetches your library from HLTB's Steam import API. This provides a direct mapping from Steam app IDs to HLTB game IDs, which is more reliable than name-based search and avoids issues with mismatched game names.

When you view a game page:

1. The plugin detects the Steam App ID from the page
2. If a cached HLTB ID exists (from the Steam import), it fetches data directly by ID
3. Otherwise, it falls back to searching HLTB by name
4. Results are cached to disk and displayed

The same caching and lookup logic is shared between the library and store views.

If your Steam profile is private, the plugin will still work using name-based search but it may be less reliable.

## Settings

Access settings via Steam menu > Millennium Library Manager > HLTB for Steam.

Library view:
- Show in Library (default = true): Show or hide HLTB data in the library
- Horizontal/Vertical Offset (default = 0): Offset from the aligned edge, useful for avoiding Steam UI elements
- Align to Right / Align to Bottom (default = true): Position the box on the header image
- Show View Details Link (default = true): Toggle the link to the HLTB game page

Store view:
- Show in Store (default = true): Show or hide HLTB data on store pages
- Position (default = Top of page): Where to insert the HLTB box on store pages. The header placement sits under the release date / developer / publisher row; the older sidebar placements are still available
- Show View Details Link (default = true): Toggle the link to the HLTB game page

Cache:
- Cache Statistics: View the number of cached games and ID mappings
- Clear Cache: Clear all cached data

## Known Limitations

HLTB constantly changes their API. This plugin will periodically break for a week or more at a time. This is a known issue across all HLTB data consumers. Set your expectations accordingly or submit a PR.

The plugin determines the HLTB game ID from two sources: the Steam import API (if your profile is public) and the [game IDs](./backend/game_ids.lua) file, which maps Steam AppIDs directly to HLTB game IDs. If neither source has an entry, the plugin falls back to a name-based search which sometimes fails. Feel free to submit a PR for any additional game ID mappings.

## How to add a game ID mapping

We'll use Final Fantasy Tactics for this example.

1. Navigate to the [Steam](https://store.steampowered.com/app/1004640/FINAL_FANTASY_TACTICS__The_Ivalice_Chronicles/) or [Steam Hunters](https://steamhunters.com/apps/1004640/achievements) page
2. Note the Steam App ID from the URL: `1004640`
3. Find the game on [HLTB](https://howlongtobeat.com/game/169173)
4. Note the HLTB game ID from the URL: `169173`

Add a line to the game_ids.lua file like this:
`[1004640] = 169173, -- Final Fantasy Tactics: The Ivalice Chronicles`

The format is `[STEAM_APPID] = HLTB_ID, -- HLTB Game Name`. The comment with the game name is required so we can recover if HLTB ever changes IDs.

You should add this correction to your local file and verify that it works before submitting a PR:
`Steam/plugins/hltb-for-millennium/backend/game_ids.lua`

When you add the game ID mapping, it needs to be:
* in sorted order by Steam App ID
* not a duplicate
* correct syntax: `[APPID] = HLTB_ID, -- Game Name`
* include a comment with the HLTB game name

When you submit your PR, an automated test will check all of these features before it can be accepted.

You **must** test it on your local copy before submitting it. I can't test it for you because I probably don't own the game. Other users can't test it for you because they are in different regions and might have other issues going on.

## Contributing

PRs are encouraged! See the [development docs](./docs/README.md) for setup instructions.

Contributions must meet these requirements:
- Compiles and passes all existing tests
- Tested locally before submission
- Matches the existing code style and architecture
- No regressions in Desktop or Big Picture mode
- Includes a clear description of what changed and why
- Address any concerns raised by the package maintainer

Any PRs that don't meet these requirements will be closed.

Contributions from AI agents are encouraged to help maintain quality and style guidelines. Use the AGENTS.md file and docs. You are still responsible for your work - review the code closely and test thoroughly.

## Credits

- [How Long To Beat](https://howlongtobeat.com/) for the game completion data
- [HLTB for Deck](https://github.com/morwy/hltb-for-deck/) for inspiration
- [HowLongToBeat-PythonAPI](https://github.com/ScrappyCocco/HowLongToBeat-PythonAPI) for initial HLTB reference implementation
- [Millennium](https://steambrew.app/) for the plugin framework

## Disclaimer

This plugin is not affiliated with, endorsed by, or connected to How Long To Beat or HowLongToBeat.com. All game data is sourced from their public website.

## License

MIT
