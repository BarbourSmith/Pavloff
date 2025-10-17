# VS Code Workspace Setup

This repository includes a VS Code workspace file (`Exercise-App.code-workspace`) that allows you to work on both the mobile app and firmware simultaneously.

## What is a VS Code Workspace?

A workspace file allows you to:
- Open multiple folders in a single VS Code window
- Each folder maintains its own settings and configurations
- Perfect for monorepo or multi-project repositories

## How to Use

### Opening the Workspace

1. **Install Required Extensions:**
   - PlatformIO IDE (for firmware development)
   - Any other extensions you use for React Native development

2. **Open the Workspace:**
   
   **Method A: Direct Open**
   - Launch VS Code
   - Go to **File → Open Workspace from File**
   - Navigate to the repository root
   - Select `Exercise-App.code-workspace`
   - Click "Open"
   
   **Method B: From GitHub Desktop**
   - Open the repository in GitHub Desktop
   - Click "Repository → Open in Visual Studio Code"
   - VS Code opens the root folder
   - Press `Ctrl+Shift+P` / `Cmd+Shift+P` to open Command Palette
   - Type "Tasks: Run Task"
   - Select "Open Multi-Root Workspace"
   - VS Code will reopen with the workspace loaded
   
   **Method C: Quick Task (after opening from GitHub Desktop)**
   - After GitHub Desktop opens VS Code
   - Press `Ctrl+Shift+P` / `Cmd+Shift+P`
   - Type "task" and select "Tasks: Run Task"
   - Choose "Open Multi-Root Workspace"

### What You'll See

After opening the workspace, you'll have two folders in the Explorer:

1. **Exercise App (Root)** - The entire repository
   - Mobile app code (React Native)
   - iOS project
   - Configuration files
   
2. **Firmware (PlatformIO)** - The Firmware subdirectory
   - ESP32 firmware code
   - PlatformIO will automatically detect this folder
   - PlatformIO toolbar will appear at the bottom

### Working with the Workspace

**For Mobile App Development:**
- Navigate to files in "Exercise App (Root)"
- Run npm commands in the terminal as usual
- Work with iOS/Android projects normally

**For Firmware Development:**
- Navigate to files in "Firmware (PlatformIO)"
- Use PlatformIO toolbar at the bottom to build/upload
- PlatformIO features work automatically for this folder

**Terminal:**
- The terminal starts in the first folder (repository root)
- Use `cd Firmware` to navigate to firmware directory when needed

## Benefits vs Opening Single Folders

### With Workspace File:
✅ One VS Code window for everything  
✅ PlatformIO automatically detects Firmware  
✅ Easy switching between app and firmware  
✅ Unified search across both projects  
✅ Better Git integration  

### Opening Root Folder Only:
❌ PlatformIO won't detect Firmware subfolder  
❌ Need to manually navigate to Firmware folder  
❌ PlatformIO features won't work  

### Opening Firmware Folder Only:
❌ Can't see or edit mobile app code  
❌ Need separate VS Code window for app development  
❌ Less convenient for full-stack work  

## GitHub Desktop Integration

### The Challenge

When you use **"Repository → Open in Visual Studio Code"** from GitHub Desktop, it opens the repository root as a **folder**, not as a **workspace**. This means PlatformIO won't automatically detect the Firmware subfolder.

### The Solution

We've added a VS Code task that makes switching to the workspace easy:

1. **Open from GitHub Desktop** (opens as folder)
2. **Switch to workspace:**
   - Press `Ctrl+Shift+P` / `Cmd+Shift+P`
   - Type: `task` or `Tasks: Run Task`
   - Select: **"Open Multi-Root Workspace"**
3. **VS Code reopens** with the workspace loaded
4. **PlatformIO activates** automatically for the Firmware folder

### Why This Works

- The repository root now has a `.vscode/tasks.json` file
- This file defines a task that opens the workspace file
- The task can be run from the Command Palette
- VS Code reopens with the proper workspace configuration
- PlatformIO detects the Firmware folder automatically

### Quick Reference

**After opening from GitHub Desktop:**

```
Ctrl+Shift+P (Cmd+Shift+P on Mac)
→ "Tasks: Run Task"
→ "Open Multi-Root Workspace"
```

That's it! VS Code will reload with both the app and firmware accessible, and PlatformIO will work.

## Customizing the Workspace

The workspace file is located at `Exercise-App.code-workspace` and can be customized:

```json
{
  "folders": [
    {
      "name": "Exercise App (Root)",
      "path": "."
    },
    {
      "name": "Firmware (PlatformIO)",
      "path": "Firmware"
    }
  ],
  "settings": {
    // Add workspace-level settings here
  },
  "extensions": {
    "recommendations": [
      // Extensions recommended for this workspace
    ]
  }
}
```

You can add more folders, adjust settings, or configure extensions as needed.

## Troubleshooting

### PlatformIO Not Detecting Firmware
- Ensure PlatformIO IDE extension is installed
- Check that you opened the workspace file (not just the root folder)
- The Firmware folder should appear as a separate workspace folder
- Restart VS Code if needed

### Can't Find Workspace File
- The file is in the repository root: `Exercise-App.code-workspace`
- Use File → Open Workspace from File (not Open Folder)

### Want to Open Just One Project
- You can still open folders individually if preferred
- Firmware folder: Open `Firmware/` for PlatformIO-only work
- Root folder: Open repository root for app-only work (PlatformIO won't work)

## Recommended Workflow

1. **Full-Stack Development:** Use the workspace file
2. **Firmware Only:** Open `Firmware/` folder directly
3. **App Only:** Open repository root (or use workspace and ignore Firmware folder)

Choose the method that best fits your current development needs!
