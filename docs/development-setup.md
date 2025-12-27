# Development Setup

This document describes how to set up a development environment for the HLTB for Millennium plugin.

## Prerequisites

### 1. Install Millennium

Millennium must be installed on your Steam client before developing plugins.

Windows (PowerShell as Administrator):
```powershell
iwr -useb "https://steambrew.app/install.ps1" | iex
```

Linux:
```bash
curl -fsSL "https://steambrew.app/install.sh" | sh
```

After installation, restart Steam and verify Millennium is working by checking for the Millennium settings panel.

### 2. Install Bun

Bun is used as the package manager and build tool for Millennium plugins.

Windows (PowerShell):
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```

Linux/macOS:
```bash
curl -fsSL https://bun.sh/install | bash
```

Verify installation:
```bash
bun --version
```

### 3. Verify Steam Paths

Locate your Steam installation directory and plugins folder:

| Platform | Steam Directory | Plugins Folder |
|----------|-----------------|----------------|
| Windows | `C:\Program Files (x86)\Steam\` | `<Steam>\plugins\` |
| Linux | `~/.steam/steam/` or `~/.local/share/Steam/` | `<Steam>\plugins\` |

The plugins folder may not exist until Millennium is installed and a plugin is added.

## Project Setup

### Clone the Repository

```bash
git clone <repository-url>
cd hltb-millenium-plugin
```

### Install Dependencies

```bash
bun install
```

This installs all required packages including:
- `@steambrew/client` - Frontend plugin APIs
- `@steambrew/api` - Core utilities
- `@steambrew/webkit` - WebKit integration
- `@steambrew/ttc` - Build toolchain

### Create Symlink to Plugins Folder

For development, create a symbolic link from your project to the Steam plugins folder. This allows you to edit code in your development directory while Steam loads the plugin.

Windows (run as Administrator):
```cmd
mklink /D "C:\Program Files (x86)\Steam\plugins\hltb-for-millennium" "D:\Documents\GitHub\personal\hltb-millenium-plugin"
```

Linux:
```bash
ln -s /path/to/hltb-millenium-plugin ~/.steam/steam/plugins/hltb-for-millennium
```

Verify the symlink was created correctly by checking that the `plugins` folder contains a link to your project.

### Verify Plugin Recognition

1. Build the plugin: `bun dev`
2. Restart Steam
3. Open Millennium settings (gear icon in Steam)
4. Navigate to Plugins tab
5. Verify "HLTB for Steam" appears in the list

## Project Structure

After setup, your project should have this structure:

```
hltb-millenium-plugin/
├── docs/                    # Documentation
├── frontend/                # TypeScript/React frontend code
│   ├── index.tsx           # Plugin entry point
│   ├── components/         # React components
│   ├── services/           # API and cache services
│   ├── hooks/              # React hooks
│   └── utils/              # Utility functions
├── backend/                 # Lua backend (optional)
├── webkit/                  # CSS styles
├── plugin.json             # Plugin manifest
├── package.json            # Dependencies
└── tsconfig.json           # TypeScript config
```

## Configuration Files

### plugin.json

The plugin manifest defines metadata for Millennium:

```json
{
  "$schema": "https://millennium.web.app/schemas/v2/plugin.schema.json",
  "name": "hltb-for-millennium",
  "common_name": "HLTB for Steam",
  "description": "Displays How Long To Beat completion times on game pages",
  "version": "1.0.0"
}
```

### package.json

Key scripts for development:

```json
{
  "scripts": {
    "dev": "millennium-ttc --build dev",
    "watch": "millennium-ttc --build dev --watch",
    "build": "millennium-ttc --build prod"
  }
}
```

## Troubleshooting Setup

### Plugin Not Appearing

1. Verify symlink points to correct directory
2. Check that `plugin.json` exists and is valid JSON
3. Ensure plugin was built with `bun dev`
4. Restart Steam completely (not just reload)

### Symlink Creation Fails

Windows:
- Must run Command Prompt as Administrator
- Developer Mode may need to be enabled in Windows Settings

Linux:
- Check target directory exists
- Verify permissions on Steam plugins folder

### Build Errors

1. Delete `node_modules` and run `bun install` again
2. Verify Bun version is current: `bun upgrade`
3. Check TypeScript errors in console output

### Millennium Not Loading

1. Verify Millennium is installed: look for `millennium.dll` in Steam folder
2. Check for antivirus blocking
3. Review logs at `<Steam>\logs\millennium.log`
4. Try reinstalling Millennium with the install script
