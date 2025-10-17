# PlatformIO Detection Checklist

Use this checklist to verify your PlatformIO setup is correct.

## ✓ Pre-Opening Checks

- [ ] VS Code is installed
- [ ] PlatformIO IDE extension is installed in VS Code
  - Open Extensions panel (`Ctrl+Shift+X` / `Cmd+Shift+X`)
  - Search for "PlatformIO IDE"
  - Verify it shows "Installed" (not "Install")
- [ ] VS Code has been restarted after installing PlatformIO extension

## ✓ Opening the Project

- [ ] You are opening the `Firmware` folder specifically (NOT the repository root)
- [ ] The folder you opened contains `platformio.ini` at the top level
- [ ] In VS Code Explorer, `platformio.ini` appears at the workspace root

## ✓ After Opening - What You Should See

Within 30-60 seconds of opening the folder, you should see:

- [ ] **PlatformIO icon** (👽 alien head) in the left Activity Bar (sidebar)
- [ ] **PlatformIO toolbar** at the bottom with these icons:
  - ✓ Build
  - → Upload  
  - 🏠 Home
  - ✔️ Test
  - 🔌 Serial Monitor
- [ ] **Status messages** in bottom status bar about PlatformIO initialization
- [ ] **PlatformIO Core** section appears in the Explorer sidebar

## ✓ Verification Commands

Try these in Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`):

- [ ] Type "PlatformIO: Home" - should open PIO Home tab
- [ ] Type "PlatformIO: Build" - should show build options

## 🔧 If Nothing Appears

1. **Wait longer** - First initialization can take 1-2 minutes
2. **Check bottom status bar** - Look for error messages
3. **Reload window** - Command: "Developer: Reload Window"
4. **Completely restart VS Code** - Close all windows and reopen
5. **Check you opened the right folder** - Must be `Firmware/` not repository root
6. **Verify platformio.ini exists** - Should be at workspace root level

## 📁 Expected File Structure

When you open the Firmware folder, you should see:

```
Firmware/                        ← You opened this folder
├── platformio.ini               ← Must be at top level!
├── src/
│   └── esp1/
│       └── main.cpp
├── include/
├── lib/
├── test/
└── .vscode/
    ├── extensions.json
    ├── launch.json
    └── settings.json
```

## 🆘 Still Not Working?

If PlatformIO is still not being detected:

1. **Uninstall and reinstall PlatformIO IDE extension**
   - Go to Extensions
   - Click gear icon next to PlatformIO IDE
   - Select "Uninstall"
   - Restart VS Code
   - Reinstall PlatformIO IDE
   - Restart VS Code again

2. **Check VS Code Output panel**
   - View → Output
   - Select "PlatformIO" from dropdown
   - Look for error messages

3. **Try opening via PlatformIO Home**
   - Open VS Code (don't open any folder)
   - Click PlatformIO icon
   - Click "Open Project"
   - Navigate to Firmware folder

4. **Check system requirements**
   - Python should be auto-installed by PlatformIO
   - Internet connection required for first initialization
   - Sufficient disk space for platform packages (~1GB)

## ✅ Success Indicators

You'll know it's working when:

1. You see the PlatformIO icon (👽) in the left sidebar
2. The bottom toolbar shows PlatformIO build/upload buttons
3. Command Palette has PlatformIO commands
4. Opening `platformio.ini` shows syntax highlighting
5. You can click Build (✓) and it starts downloading packages
