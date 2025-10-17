# Quick Start Guide: Opening in PlatformIO

This guide will help you open and work with this firmware project in PlatformIO IDE.

## What is PlatformIO?

PlatformIO is a professional collaborative platform for embedded development. It works as an extension for Visual Studio Code and provides an integrated development environment for ESP32 and other microcontrollers.

## Prerequisites

1. **Install Visual Studio Code**
   - Download from: https://code.visualstudio.com/
   - Install and launch VS Code

2. **Install PlatformIO IDE Extension**
   - Open VS Code
   - Click the Extensions icon (or press `Ctrl+Shift+X` / `Cmd+Shift+X`)
   - Search for "PlatformIO IDE"
   - Click "Install" on the official PlatformIO IDE extension
   - Wait for installation to complete (may take a few minutes)
   - Restart VS Code if prompted

## Opening the Project

### Method 1: Direct Folder Open
1. Launch Visual Studio Code
2. Go to **File → Open Folder** (or `Ctrl+K Ctrl+O` / `Cmd+K Cmd+O`)
3. Navigate to and select the **`Firmware`** directory
4. Click "Select Folder" / "Open"
5. PlatformIO will automatically detect the project and initialize it

### Method 2: Using PlatformIO Home
1. Launch Visual Studio Code
2. Click the PlatformIO icon (alien head) in the left sidebar
3. Click "Open" in the PIO Home tab
4. Click "Open Project"
5. Navigate to and select the **`Firmware`** directory

## First-Time Setup

When you first open the project, PlatformIO will:
1. Detect the `platformio.ini` file and recognize this as a PlatformIO project
2. Show a notification suggesting to install the PlatformIO IDE extension (if not already installed)
3. Download the ESP32 platform packages (espressif32@6.4.0)
4. Install the required libraries:
   - MPU6050_tockn
   - ESP32 BLE Arduino
5. Configure the toolchain for ESP32-S3

This process is automatic and may take 5-10 minutes depending on your internet connection.

### Verifying PlatformIO Detection

After opening the `Firmware` folder in VS Code, you should see:

1. **PlatformIO icon** (alien head) in the left Activity Bar
2. **PlatformIO toolbar** at the bottom with icons for:
   - Build (✓ checkmark)
   - Upload (→ arrow)
   - Clean
   - Test
   - Serial Monitor (🔌 plug)
3. **"PlatformIO" folder** in the VS Code Explorer sidebar (shows project tasks)

If you don't see these, try:
- Close and reopen VS Code
- Check that the PlatformIO IDE extension is installed and enabled
- Verify you opened the `Firmware` folder (not the repository root)
- Check the VS Code status bar (bottom) for PlatformIO initialization messages

## Project Structure

Once opened, you'll see:

```
Firmware/
├── platformio.ini       # Project configuration (board, libraries, build flags)
├── src/                 # Your source code
│   └── esp1/
│       └── main.cpp
├── include/             # Header files (currently empty)
├── lib/                 # Project-specific libraries (currently empty)
└── test/                # Unit tests (currently empty)
```

## Working with the Project

### Building the Firmware
- Click the checkmark (✓) icon in the bottom toolbar, or
- Open the PlatformIO sidebar → Project Tasks → esp1 → General → Build

### Uploading to ESP32
1. Connect your ESP32-S3 board via USB
2. Click the arrow (→) icon in the bottom toolbar, or
3. Open the PlatformIO sidebar → Project Tasks → esp1 → General → Upload

### Serial Monitor
- Click the plug icon in the bottom toolbar, or
- Open the PlatformIO sidebar → Project Tasks → esp1 → Monitor

### Clean Build
- Open the PlatformIO sidebar → Project Tasks → esp1 → General → Clean

## Troubleshooting

### PlatformIO Extension Not Detecting the Project

If VS Code doesn't show PlatformIO features after opening the Firmware folder:

**Step 1: Verify Extension is Installed**
1. Go to Extensions (`Ctrl+Shift+X` / `Cmd+Shift+X`)
2. Search for "PlatformIO IDE" 
3. Ensure it's installed (shows "Installed" not "Install")
4. Check it's enabled (no "Enable" button visible)
5. If you just installed it, **restart VS Code completely** (close all windows)

**Step 2: Verify You Opened the Correct Folder**
- You must open the **`Firmware` directory** specifically, NOT the repository root
- The folder you open should contain `platformio.ini` at the top level
- In VS Code Explorer, you should see `platformio.ini` directly in the workspace root

**Step 3: Force PlatformIO to Initialize**
1. Press `Ctrl+Shift+P` / `Cmd+Shift+P` to open Command Palette
2. Type "PlatformIO: Home"
3. Press Enter - this should open PIO Home tab
4. If this works, PlatformIO is active

**Step 4: Check VS Code Status Bar**
- Look at the bottom of VS Code
- You should see PlatformIO initialization messages appear
- Wait 30-60 seconds for initialization to complete on first open

**Step 5: Manual Reload**
1. Close the Firmware folder in VS Code
2. Completely quit VS Code (close all windows)
3. Reopen VS Code
4. Open Firmware folder again
5. Wait for PlatformIO to initialize (watch bottom status bar)

**Step 6: Check for Conflicting Extensions**
- C/C++ extension can sometimes interfere
- If installed, ensure it's updated to latest version
- PlatformIO should manage IntelliSense automatically

**Step 7: Verify platformio.ini is Valid**
- Open `platformio.ini` in the editor
- Check there are no syntax errors
- Should have `[platformio]` and `[env]` sections

### "PlatformIO: PIO Home" doesn't appear
- Close and reopen VS Code
- Check that the PlatformIO extension is properly installed and enabled

### Build errors about missing packages
- PlatformIO will automatically download required packages
- Check your internet connection
- Try: PlatformIO sidebar → Project Tasks → esp1 → Advanced → Clean All

### Upload fails
- Ensure the ESP32 is connected via USB
- Check that the correct COM port is detected
- Press and hold the BOOT button while clicking upload (for some ESP32 boards)

### IntelliSense not working
- Wait for PlatformIO to finish indexing (watch the bottom status bar)
- Try: `Ctrl+Shift+P` / `Cmd+Shift+P` → "Rebuild IntelliSense Index"

## Additional Resources

- [PlatformIO Documentation](https://docs.platformio.org/)
- [ESP32 Platform Documentation](https://docs.platformio.org/en/latest/platforms/espressif32.html)
- [PlatformIO VS Code Integration](https://docs.platformio.org/en/latest/integration/ide/vscode.html)

## Project Configuration

The `platformio.ini` file contains all project settings:
- **Platform**: espressif32@6.4.0
- **Board**: esp32-s3-devkitc-1
- **Framework**: Arduino
- **Monitor Speed**: 115200 baud
- **Libraries**: MPU6050_tockn

Build flags configure:
- ESP1 build identifier
- I2C pins (SDA=GPIO8, SCL=GPIO9)
- USB CDC mode for serial communication

## Next Steps

1. Read the main [README.md](README.md) for project details
2. Review the [USAGE_GUIDE.md](USAGE_GUIDE.md) for operational instructions
3. Explore [REP_DETECTION.md](REP_DETECTION.md) and [OSCILLATORY_MOTION_TRACKING.md](OSCILLATORY_MOTION_TRACKING.md) for algorithm details

Happy coding! 🚀
