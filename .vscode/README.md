# VS Code Configuration for Exercise-App

This folder contains VS Code configuration for the repository root.

## Important: Multi-Root Workspace Available

This repository works best when opened as a **multi-root workspace** rather than a single folder.

### If you opened this via GitHub Desktop:

After opening, you can switch to the workspace view:

1. **Quick Switch:** Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type: "Tasks: Run Task"
3. Select: "Open Multi-Root Workspace"

OR manually:

1. File → Open Workspace from File
2. Select `Exercise-App.code-workspace` from the root folder

### Why use the workspace?

- ✅ PlatformIO automatically detects the Firmware folder
- ✅ Work on both mobile app and firmware in one window
- ✅ Better project organization
- ✅ No need to manually navigate to Firmware folder

### Files in this folder:

- `settings.json` - Basic VS Code settings for the root folder
- `extensions.json` - Recommends PlatformIO extension
- `tasks.json` - Includes a task to quickly open the workspace file
