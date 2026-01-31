# Quick Start: Adding Event Log and Extension to Xcode

## Problem
The extension and event log files exist but are not in the Xcode project, so they don't get compiled.

## Solution: Add Files to Xcode (5 minutes)

### Step 1: Add EventLog to Main App
1. Open `ios/esp32Connect.xcodeproj` in Xcode
2. Right-click on the `esp32Connect` folder in the Project Navigator
3. Select "Add Files to esp32Connect..."
4. Navigate to `ios/esp32Connect/` and select:
   - `EventLog.swift`
   - `EventLogView.swift`
5. Make sure "Copy items if needed" is **unchecked**
6. Make sure `esp32Connect` target is **checked**
7. Click "Add"

### Step 2: Add Extension Source Files
1. Right-click on the `DeviceActivityMonitorExtension` folder (or create it if it doesn't exist)
2. Select "Add Files to DeviceActivityMonitorExtension..."
3. Navigate to `ios/DeviceActivityMonitorExtension/` and select:
   - `DeviceActivityMonitorExtension.swift`
   - `EventLog.swift`
   - `Info.plist`
4. Make sure "Copy items if needed" is **unchecked**
5. Make sure `DeviceActivityMonitorExtension` target is **checked** (NOT the main app target)
6. Click "Add"

### Step 3: Verify Files Were Added
1. Select the project in the Navigator
2. Select the `esp32Connect` target
3. Go to "Build Phases" → "Compile Sources"
4. Verify you see:
   - `EventLog.swift`
   - `EventLogView.swift`
5. Select the `DeviceActivityMonitorExtension` target
6. Go to "Build Phases" → "Compile Sources"
7. Verify you see:
   - `DeviceActivityMonitorExtension.swift`
   - `EventLog.swift`

### Step 4: Build and Test
1. Select a physical iOS device (not simulator - extensions don't work in simulator)
2. Build the project (Cmd+B)
3. Fix any build errors that appear
4. Run the app (Cmd+R)
5. Look for the "Event Log" button
6. Tap it to verify the Event Log UI appears

## If Extension Target Doesn't Exist

If you don't see a `DeviceActivityMonitorExtension` target, you need to create it first:

1. Follow the complete guide in `MIDNIGHT_RELOCK_SETUP.md`
2. This includes:
   - Creating the extension target
   - Adding entitlements (App Groups, Family Controls)
   - Linking frameworks (DeviceActivity, FamilyControls, ManagedSettings)
   - Configuring signing

## Quick Verification Checklist

After adding files:
- [ ] EventLog.swift shows in main app target's Compile Sources
- [ ] EventLogView.swift shows in main app target's Compile Sources
- [ ] DeviceActivityMonitorExtension.swift shows in extension target's Compile Sources
- [ ] EventLog.swift shows in extension target's Compile Sources (separate copy)
- [ ] Project builds without errors (Cmd+B)
- [ ] Event Log button appears in app UI
- [ ] Event Log view opens when button tapped
- [ ] Events are logged when app launches

## Common Issues

### "No such module 'EventLog'"
- The EventLog.swift file wasn't added to the target
- Check Build Phases → Compile Sources

### "Duplicate symbol '_$s8EventLogAAC...'"
- EventLog.swift was added to both targets instead of separate copies
- Remove EventLog.swift from the wrong target
- Each target should have its own copy from its own directory

### "Extension not launching"
- Extension target not properly configured
- See `MIDNIGHT_RELOCK_SETUP.md` for complete extension setup
- Extensions require physical device, not simulator

### Build errors about missing identifiers
- Files not added to correct target
- Check that each file is only in the target it should be in
- Main app files: esp32Connect target only
- Extension files: DeviceActivityMonitorExtension target only

## Result

After following these steps:
- ✅ Event Log feature will be available in the app
- ✅ Events from main app will be logged
- ✅ Extension will compile and be included in app bundle
- ✅ Extension will run at midnight (after proper entitlements setup)
- ✅ Extension events will be logged
- ✅ You can debug midnight blocking issues via Event Log

## Next Steps

1. Test Event Log in the app
2. Complete extension entitlements setup (if not done)
3. Test overnight for midnight blocking
4. Use Event Log to verify extension is running
