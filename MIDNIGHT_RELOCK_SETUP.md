# Midnight Re-Lock Setup Guide

> **Note**: References to `SharedConstants.swift` in this document are outdated. The implementation uses hardcoded string constants directly in the code instead of a separate SharedConstants file, as that file was not properly added to the Xcode project.

## Overview

This guide explains how to complete the setup for the midnight app re-locking feature. The code changes have been implemented, but the Xcode project requires manual configuration to add the DeviceActivityMonitor extension.

## Current Status

✅ **Implemented:**
- App Group support for data sharing (`group.com.barboursmith.pavloff`)
- Updated ScreenTimeManager to use App Group UserDefaults
- Updated WorkoutView to use App Group UserDefaults
- Created DeviceActivityMonitorExtension source files
- Improved logging and error handling
- DeviceActivity schedule setup for daily monitoring

⚠️ **Requires Manual Setup:**
- Adding the DeviceActivityMonitor extension target to Xcode project
- Configuring extension entitlements
- Setting up extension signing

## How It Works

### Without Extension (Current Behavior)
1. Apps lock when selected
2. Apps unlock after workout completion
3. **User must open app after midnight** for apps to re-lock
4. When app opens, it checks if it's a new day and re-enables blocking

### With Extension (Full Solution)
1. Apps lock when selected
2. Apps unlock after workout completion
3. **Apps automatically re-lock at midnight** even if app is closed
4. Extension runs in background and reapplies shields at midnight

## Manual Xcode Setup Steps

### Step 1: Add Extension Target

1. Open `ios/esp32Connect.xcodeproj` in Xcode
2. Click on the project in the Navigator
3. Click the "+" button at the bottom of the targets list
4. Select "App Extension" → "Device Activity Monitor Extension"
5. Name it: `DeviceActivityMonitorExtension`
6. Language: Swift
7. Click "Finish"

### Step 2: Replace Extension Files

1. Delete the auto-generated extension files
2. Copy the extension files from `ios/DeviceActivityMonitorExtension/`:
   - `DeviceActivityMonitorExtension.swift`
   - `Info.plist`

### Step 3: Configure Extension Entitlements

1. Select the extension target
2. Go to "Signing & Capabilities"
3. Add capability: "App Groups"
4. Enable: `group.com.barboursmith.pavloff`
5. Add capability: "Family Controls"

### Step 4: Configure Extension Info.plist

Ensure the `Info.plist` contains:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.monitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

### Step 5: Update Extension Dependencies

1. Select the extension target
2. Go to "Build Phases" → "Link Binary With Libraries"
3. Add:
   - `DeviceActivity.framework`
   - `FamilyControls.framework`
   - `ManagedSettings.framework`

### Step 6: Set Deployment Target

1. Select the extension target
2. Go to "General"
3. Set "Minimum Deployments" to iOS 16.0 or higher

### Step 7: Configure Extension Signing

1. Select the extension target
2. Go to "Signing & Capabilities"
3. Select your development team
4. Ensure "Automatically manage signing" is checked

## Testing the Extension

### Test Midnight Re-Lock

1. Build and run the app on a physical device
2. Select apps to block in Workout Settings
3. Complete a workout (apps should unlock)
4. Keep the app closed
5. Wait until midnight or change device time to test
6. Extension should automatically reapply shields
7. Verify apps are blocked without opening the main app

### Debug Extension

To see extension logs:
1. Open Console app on Mac
2. Connect iOS device
3. Filter by "DeviceActivityMonitor"
4. Trigger midnight event
5. Check for log messages

## Fallback Behavior

If the extension is not set up, the app will still work but with limitations:

- ✅ Apps lock when selected
- ✅ Apps unlock after workout
- ⚠️ User must open app after midnight for re-lock to occur
- ✅ When app opens, it automatically checks and re-enables blocking

## Troubleshooting

### Extension Not Loading
- Verify extension is added to project
- Check entitlements are correctly configured
- Ensure App Group identifier matches in both targets
- Verify extension has Family Controls capability

### Shields Not Reapplying
- Check extension logs in Console app
- Verify App Group UserDefaults contains selection data
- Ensure workout completion date is being saved
- Check that DeviceActivity schedule is active

### Token Persistence Issues

If FamilyActivitySelection tokens don't persist:
1. User will see a warning in logs
2. User must reselect apps in Workout Settings
3. This is a limitation of the Screen Time API
4. Extension helps but doesn't completely solve this

## Alternative: Using ManagedSettingsStore Persistence

An alternative approach (not currently implemented) would be to:

1. Never clear shields from ManagedSettingsStore
2. Use a different mechanism to grant access after workout
3. Let shields persist naturally
4. This eliminates the need for token management

However, this changes the UX significantly as apps wouldn't be immediately unlocked after workout completion.

## Development Notes

### App Group

The App Group `group.com.barboursmith.pavloff` is used to share:
- `hasAppSelection`: Boolean flag indicating if user has selected apps
- `savedAppSelection`: Encoded FamilyActivitySelection data
- `lastWorkoutCompletion`: Date of last workout completion

### DeviceActivity Schedule

The schedule runs:
- **Start**: 00:00 (midnight)
- **End**: 23:59 (11:59 PM)
- **Repeats**: Daily

At the start of each interval (midnight), the extension's `intervalDidStart` method is called, which checks if workout was completed yesterday and reapplies shields if needed.

## Future Enhancements

1. **Customizable Schedule**: Allow users to set custom blocking hours
2. **Weekend Support**: Different schedules for weekdays vs weekends
3. **Grace Periods**: Delay blocking by X minutes after midnight
4. **Multiple Schedules**: Different app sets for different times
5. **Push Notifications**: Notify user when apps re-lock at midnight

## References

- [Apple DeviceActivity Documentation](https://developer.apple.com/documentation/deviceactivity)
- [Family Controls Framework](https://developer.apple.com/documentation/familycontrols)
- [ManagedSettings Framework](https://developer.apple.com/documentation/managedsettings)
- [SCREEN_TIME_DEV_GUIDE.md](SCREEN_TIME_DEV_GUIDE.md)
