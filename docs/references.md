# References

This document lists all source materials, related projects, and documentation used in developing this plugin.

## Primary References

### HLTB for Steam Deck (Decky Loader)

The primary inspiration for this plugin. A Decky Loader plugin that displays HLTB data on Steam Deck.

- Reddit announcement: https://www.reddit.com/r/SteamDeck/comments/yf6md3/hltb_for_deck_how_long_to_beat_data_added_to_the/
- GitHub repository: https://github.com/hulkrelax/hltb-for-deck

Key files studied:
- `src/index.tsx` - Plugin initialization and route patching
- `src/hooks/useHltb.ts` - HLTB API integration
- `src/hooks/Cache.ts` - Caching implementation
- `src/patches/LibraryApp.tsx` - UI injection into game pages
- `src/utils.ts` - Game name normalization

### AugmentedSteam Extension Plugin

A Millennium plugin that ports the Augmented Steam browser extension to Steam desktop. Archived but valuable for understanding Millennium patterns.

- GitHub repository: https://github.com/BossSloth/AugmentedSteam-Extension-Plugin

Key files studied:
- `frontend/index.tsx` - Plugin entry point and initialization
- `frontend/HltbInjection.ts` - Library page injection patterns
- `frontend/HtlbData.ts` - HLTB data fetching via AugmentedSteam API

### Extendium

An actively maintained Millennium plugin that adds Chrome extension support to Steam. Provides current examples of Millennium patterns.

- GitHub repository: https://github.com/BossSloth/Extendium

Key files studied:
- `frontend/index.tsx` - Window detection with `g_PopupManager`
- `frontend/shared.ts` - Window name constants (`SP Desktop_uid0`)
- `frontend/onPopupCreation.tsx` - Popup type differentiation

## Millennium Framework

### Official Resources

- Main website: https://steambrew.app/
- Documentation: https://docs.steambrew.app/
- GitHub organization: https://github.com/SteamClientHomebrew
- Plugin database: https://steambrew.app/plugins

### Plugin Development

- Plugin template: https://github.com/SteamClientHomebrew/PluginTemplate
- SDK repository: https://github.com/SteamClientHomebrew/PluginComponents
- Millennium core: https://github.com/SteamClientHomebrew/Millennium

### NPM Packages

- `@steambrew/client` - Frontend plugin APIs
- `@steambrew/api` - Core API utilities
- `@steambrew/webkit` - WebKit integration
- `@steambrew/ttc` - Build toolchain

## How Long To Beat

- Main website: https://howlongtobeat.com/
- API endpoint: `https://howlongtobeat.com/api/search`

Note: HLTB does not provide a public API. The endpoint is reverse-engineered from their website and may change without notice.

## Steam Client Technical References

### CEF (Chromium Embedded Framework)

Steam's UI is built on CEF, rendering web content in embedded Chromium instances.

- Valve Developer Wiki: https://developer.valvesoftware.com/wiki/Chromium_Embedded_Framework

### Steam Launch Parameters

Relevant command-line parameters:
- `-dev` - Enable development mode, CEF DevTools on port 8080
- `-gamepadui` - Launch in Big Picture / GamepadUI mode
- `-no-browser` - Disable CEF (breaks modern UI)

Reference: https://developer.valvesoftware.com/wiki/Command_line_options_(Steam)

## Related Projects

### Decky Loader

Plugin framework for Steam Deck, similar role to Millennium for desktop.

- Website: https://decky.xyz/
- GitHub: https://github.com/SteamDeckHomebrew/decky-loader

### Steam for Linux Issues

Useful for understanding Steam client internals and window management.

- GitHub: https://github.com/ValveSoftware/steam-for-linux/issues

## Version Information

This documentation was compiled in December 2024. Steam client updates may affect selector compatibility and API behavior. The Millennium framework version at time of writing was 2.31.0.
