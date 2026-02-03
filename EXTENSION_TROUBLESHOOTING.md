# Troubleshooting: Extension Not Triggering at Midnight

## Problem

The event log shows no midnight events, meaning the DeviceActivityMonitorExtension is not being called by iOS at midnight.

## Root Causes and Solutions

### 1. Extension Point Identifier Error (FIXED)

**Issue**: The Info.plist had the wrong NSExtensionPointIdentifier.

**Was**: `com.apple.deviceactivity-monitor`
**Should be**: `com.apple.deviceactivity-monitor.extension`

**Fix Applied**: Updated Info.plist with correct extension point identifier.

### 2. Extension Not Embedded in App Bundle

**Check**: Is the extension actually being built and embedded?

1. Build the app in Xcode
2. Right-click on the `.app` file in Products
3. Select "Show in Finder"
4. Right-click the `.app` and select "Show Package Contents"
5. Navigate to `PlugIns/`
6. Verify `DeviceActivityMonitorExtension.appex` exists

**If missing**: The extension target might not be added as a dependency or embedded properly.

### 3. Extension Not Signed Properly

**Check**: Extension signing configuration

1. In Xcode, select the DeviceActivityMonitorExtension target
2. Go to "Signing & Capabilities"
3. Verify:
   - Signing certificate is valid
   - Team is selected
   - Bundle identifier is correct
   - App Groups capability includes: `group.com.maslowcnc.Tides`
   - Family Controls capability is enabled

### 4. Schedule Not Being Registered

**Check the Event Log for**:
- "Daily monitoring schedule registered successfully" message
- If you see this, the schedule was registered with iOS
- If not, there was an error (check for error messages)

**Common causes**:
- Family Controls authorization not granted
- App doesn't have Screen Time permission

### 5. iOS Not Calling Extension

Even with everything configured correctly, iOS may not call the extension if:

**Device Requirements**:
- Must be a physical iOS device (not simulator)
- Must have iOS 16.0 or later
- Device must NOT be in Low Power Mode (disables background activities)
- Device must be unlocked at least once after midnight

**App Requirements**:
- App must have been launched at least once
- Family Controls permission must be granted
- User must have selected apps to block

**System Restrictions**:
- If the user has disabled "Share Across Devices" in Screen Time settings
- If the device is supervised with restrictions
- If Screen Time is disabled system-wide

### 6. Testing the Extension

**Immediate Testing** (without waiting for midnight):

Unfortunately, you cannot manually trigger a DeviceActivityMonitor extension. You must:

1. **Wait for midnight** - The extension only triggers at the scheduled time
2. **Check Event Log next morning** - Events persist even when app is closed
3. **Simulate time change** (advanced):
   - Change device date/time to 11:59 PM
   - Wait one minute
   - Check event log
   - ⚠️ This may not work reliably as iOS is smart about time changes

**What to Look For in Event Log**:

If extension is working, you should see at midnight:
```
🔵 Midnight Trigger
   "Midnight interval started for activity: workoutSchedule"
   Source: Extension
   Time: 12:00 AM

🔵 Info
   "Workout not completed today - will reapply shields"
   Source: Extension
   Time: 12:00 AM

🔴 Apps Blocked
   "Successfully reapplied shields for X apps"
   Source: Extension
   Time: 12:00 AM
```

If you see NOTHING at midnight, the extension isn't being called.

## Diagnostic Steps

### Step 1: Verify Extension is in Project

```bash
# Check if extension files are in build phases
grep "DeviceActivityMonitorExtension.swift" ios/esp32Connect.xcodeproj/project.pbxproj
```

Should return multiple lines showing the file is referenced.

### Step 2: Check Event Log After App Launch

1. Open the app
2. Go to Event Log
3. Look for: "Daily monitoring schedule registered successfully"
4. If you see this, the schedule is registered with iOS

### Step 3: Verify Permissions

1. Open iOS Settings
2. Go to Screen Time
3. Tap your device name
4. Verify Screen Time is enabled
5. Go back to Settings → Privacy & Security → Family Controls
6. Verify the Pavloff app is listed and enabled

### Step 4: Check Bundle

1. Build the app
2. Locate the .app file in Products
3. Show Package Contents
4. Check PlugIns/ folder for DeviceActivityMonitorExtension.appex
5. If missing, the extension isn't being embedded

### Step 5: Check Console Logs (Xcode)

1. Connect device to Xcode
2. Open Window → Devices and Simulators
3. Select your device
4. Click "Open Console"
5. Filter for "DeviceActivityMonitor" or "Extension"
6. Leave console open overnight
7. Check at 12:01 AM for any extension messages

### Step 6: Rebuild and Reinstall

Sometimes Xcode doesn't properly update extensions:

1. Clean build folder (Shift + Cmd + K)
2. Delete app from device
3. Restart device
4. Build and install fresh
5. Grant permissions again
6. Wait for midnight

## Expected Behavior

### Successful Extension Operation

**Evening (e.g., 8:00 PM)**:
- User opens app
- Event: "App launched - workout not completed today, enabling blocking"
- Event: "Apps Blocked"
- Event: "Daily monitoring schedule registered successfully"

**User Completes Workout (e.g., 9:00 PM)**:
- Event: "Workout Completed"
- Event: "Apps Unlocked"

**Midnight (12:00 AM)**:
- Event: "Midnight Trigger - Midnight interval started"
- Event: "Workout not completed today - will reapply shields"
- Event: "Apps Blocked - Successfully reapplied shields for X apps"

**Next Morning (e.g., 8:00 AM)**:
- Apps are already blocked (extension did its job!)
- User opens app to check Event Log
- Sees midnight events from 12:00 AM

### Failed Extension (Current State)

**Evening**:
- User opens app
- Event: "App launched - workout not completed today, enabling blocking"
- Event: "Apps Blocked"
- Event: "Daily monitoring schedule registered successfully"

**Midnight**:
- **NO EVENTS** ❌

**Next Morning**:
- Apps might not be blocked (unless user opens app)
- Event Log shows no midnight activity

## Most Likely Cause

Given that:
1. ✅ Extension code exists and is added to project
2. ✅ Event log is working (can show events)
3. ❌ No midnight events appearing

The most likely causes are:

1. **Info.plist Extension Point Identifier was wrong** (NOW FIXED)
2. **Extension not properly embedded** in app bundle
3. **Extension target not properly configured** in Xcode project
4. **iOS restrictions** preventing background execution

## Next Steps

1. ✅ Info.plist fix has been applied (commit: TBD)
2. Rebuild the app completely (clean build)
3. Delete app from device and reinstall
4. Grant all permissions
5. Check Event Log for "Daily monitoring schedule registered successfully"
6. Wait for midnight
7. Check Event Log for midnight events

If still not working after these steps:
- Check bundle for embedded extension
- Verify signing and entitlements
- Check iOS console logs during midnight
- Consider device/iOS restrictions

## Additional Logging Added

The ScreenTimeManager now logs when:
- ✅ Schedule registration succeeds
- ❌ Schedule registration fails (with error details)

This will help diagnose if the schedule is even being registered with iOS.
