# Development Workflow

This document describes the day-to-day development workflow for building and testing the plugin.

## Build Commands

| Command | Description |
|---------|-------------|
| `bun dev` | Development build with source maps |
| `bun watch` | Auto-rebuild on file changes |
| `bun build` | Production build for distribution |

During active development, use `bun watch` to automatically rebuild when files change.

## Starting Steam in Development Mode

Development mode enables CEF DevTools, hot reload, and verbose logging.

Windows (PowerShell):
```powershell
& "$((gp 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam').InstallPath)\steam.exe" -dev
```

Windows (Command Prompt):
```cmd
"C:\Program Files (x86)\Steam\steam.exe" -dev
```

Linux:
```bash
steam -dev
```

The `-dev` flag enables:
- CEF DevTools accessible on port 8080
- Hot reload of frontend changes with F5
- Verbose logging to console and log files

## Testing Changes

Different types of changes require different reload procedures:

| Change Type | How to Test |
|-------------|-------------|
| Frontend TypeScript/React | Press F5 in Steam window |
| CSS styles | Press F5 in Steam window |
| Backend Lua code | Full Steam restart required |
| plugin.json changes | Full Steam restart required |

### Quick Iteration Cycle

1. Make code changes in your editor
2. If using `bun watch`, build happens automatically
3. Otherwise run `bun dev`
4. Press F5 in Steam to reload frontend
5. Test the changes
6. Check DevTools console for errors
7. Repeat

## Debugging

### Opening DevTools

Two methods to access the CEF DevTools:

1. URL method: Type `steam://millennium/devtools/open` in a browser or Steam
2. Browser method: Open `http://localhost:8080` in Chrome or Edge

Note: Port 8080 is only available when Steam runs with the `-dev` flag.

### DevTools Tabs

The DevTools interface shows multiple tabs representing different Steam windows and contexts:

| Tab Name | Description |
|----------|-------------|
| SP Desktop_uid0 | Main Steam desktop window |
| SP GamepadUI_uid0 | Big Picture mode window (if active) |
| SharedJSContext | JavaScript execution context for plugins |
| Steam Store | Store page context |
| Steam Library | Library page context |

For plugin debugging, focus on:
- SharedJSContext for console.log output
- SP Desktop_uid0 for DOM inspection

### Console Logging

Frontend (TypeScript):
```typescript
console.log('Message');
console.warn('Warning');
console.error('Error');
```

Logs appear in the SharedJSContext tab of DevTools.

Backend (Lua):
```lua
local logger = require("logger")
logger:info("Info message")
logger:warn("Warning message")
logger:error("Error message")
```

Backend logs appear in the Millennium log file.

### Log File Locations

| Platform | Log Path |
|----------|----------|
| Windows | `<Steam>\logs\millennium.log` |
| Linux | `~/.steam/steam/logs/millennium.log` |

Use `tail -f` on Linux or a log viewer on Windows to monitor logs in real-time.

## Testing Modes

### Desktop UI Testing

1. Start Steam with `-dev` flag
2. Navigate to Library
3. Select any game with HLTB data
4. Verify the HLTB display appears
5. Navigate between games to test updates
6. Try a game without HLTB data to test error handling

### Big Picture Mode Testing

Launch Steam directly in Big Picture mode:

```powershell
steam.exe -gamepadui -dev
```

```bash
steam -gamepadui -dev
```

Testing checklist:
1. Enter Big Picture mode
2. Navigate to Library
3. Select a game
4. Verify HLTB data appears
5. Test with controller navigation

## Testing Checklist

### Functional Tests

- [ ] HLTB data displays for games with data
- [ ] Graceful handling for games without HLTB data
- [ ] Cache stores and retrieves data correctly
- [ ] Navigation between games updates display
- [ ] Settings panel renders correctly
- [ ] Settings changes take effect

### Edge Cases

- [ ] Games with special characters in names
- [ ] Games with very long names
- [ ] Games with localized names
- [ ] DLC and non-game items
- [ ] Rapid navigation between games
- [ ] Network errors during API calls

### Big Picture Mode

- [ ] Plugin loads in GamepadUI
- [ ] Display renders correctly
- [ ] Controller navigation works
- [ ] Mode switching (Desktop to Big Picture) works

## Common Issues

### Plugin Not Loading After Changes

1. Verify build completed without errors
2. Check that symlink is still valid
3. Try pressing F5 multiple times
4. If F5 fails, restart Steam

### Changes Not Appearing

1. Check DevTools console for JavaScript errors
2. Verify the correct file was modified
3. Ensure build watcher is running
4. Try a full Steam restart

### DevTools Not Opening

1. Confirm Steam was started with `-dev` flag
2. Check that port 8080 is not in use by another application
3. Try accessing directly at http://localhost:8080
4. Check firewall settings

### React Error 130

This error typically indicates Steam updated and broke UI component compatibility:
1. Check for Millennium updates
2. Update CSS selectors if Steam changed class names
3. Consider switching to Steam stable branch

### CORS Errors

If fetch requests fail with CORS errors:
1. Check browser DevTools Network tab for details
2. Consider implementing Lua backend for API calls
3. Verify request headers match expected format
