# Testing Midnight App Blocking

## Prerequisites
- Physical iOS device (iOS 16.6+) - **Extensions do NOT work in simulator**
- Device must have Screen Time enabled
- Xcode 14+ for building and deploying

## Setup

1. **Build and Install**
   ```bash
   # Open the project in Xcode
   open ios/esp32Connect.xcodeproj
   
   # Select your physical device as the target
   # Build and run (Cmd+R)
   ```

2. **Grant Permissions**
   - When prompted, grant Screen Time permissions
   - This allows the app to manage app blocking

3. **Select Apps to Block**
   - Open the app
   - Navigate to Workout Settings
   - Tap "Select Apps to Block"
   - Choose apps you want to block (e.g., Safari, Instagram, etc.)
   - Confirm selection

## Testing Scenarios

### Scenario 1: Verify Extension is Embedded

Check that the extension is included in the app bundle:

1. After building, check the Products folder in Xcode
2. Right-click on `esp32Connect.app` → Show in Finder
3. Right-click on the app → Show Package Contents
4. Navigate to `PlugIns/`
5. You should see `DeviceActivityMonitorExtension.appex`

**Expected**: Extension is present in the PlugIns folder

### Scenario 2: Verify Shields Apply Immediately

1. Select apps to block in Workout Settings
2. Exit Workout Settings
3. Try to open one of the blocked apps
4. You should see a shield screen

**Expected**: Apps are immediately blocked after selection

### Scenario 3: Verify Shields Unlock After Workout

1. Complete a workout (do the exercises)
2. Apps should unlock automatically
3. Try to open previously blocked apps

**Expected**: Apps are accessible after workout completion

### Scenario 4: Test Midnight Re-Locking (Method 1 - Change Time)

⚠️ **Warning**: Changing device time may affect other apps

1. Complete a workout (apps unlock)
2. Close the Pavloff app completely (swipe up from app switcher)
3. Go to Settings → General → Date & Time
4. Turn off "Set Automatically"
5. Change the time to 11:58 PM today
6. Wait 2-3 minutes (let time pass midnight)
7. Change time to 12:01 AM (next day)
8. **Without opening Pavloff**, try to open a blocked app

**Expected**: Apps are automatically blocked at midnight without opening the app

### Scenario 5: Test Midnight Re-Locking (Method 2 - Wait for Real Midnight)

The most reliable test:

1. Complete a workout before midnight (apps unlock)
2. Note the current time
3. Close the Pavloff app completely
4. Keep device unlocked and charging
5. Wait for actual midnight (00:00)
6. At 12:01 AM, try to open a blocked app **without opening Pavloff**

**Expected**: Apps are automatically blocked at midnight without user intervention

### Scenario 6: Verify Fallback Behavior

1. Complete workout (apps unlock)
2. Close app completely
3. Wait until next day (or change time to next day)
4. **Open the Pavloff app**
5. Apps should be blocked when app is opened

**Expected**: Even if extension doesn't fire, apps re-lock when app opens

## Debugging

### Check Extension Logs

The extension uses `NSLog()` which writes to the system log. To view:

1. **On Mac with Device Connected**:
   ```bash
   # Open Console.app
   # Connect your iPhone via cable
   # Select your device in the sidebar
   # Filter by: DeviceActivityMonitor
   ```

2. **Log Messages to Look For**:
   ```
   [DeviceActivityMonitor] ⏰ Interval started for activity: workoutSchedule
   [DeviceActivityMonitor] 🔄 Midnight reset triggered
   [DeviceActivityMonitor] 📅 Last workout completion: [date]
   [DeviceActivityMonitor] ✅ Workout not completed today yet - reapplying shields
   [DeviceActivityMonitor] 🛡️ Reapplied shields for X apps
   ```

3. **Check for Errors**:
   ```
   ❌ Failed to access App Group UserDefaults
   ❌ No saved selection data found
   ⚠️ Selection loaded but no tokens found - tokens may have expired
   ```

### Common Issues and Solutions

#### Issue: Extension Not Called at Midnight

**Possible Causes**:
1. Extension not embedded in app bundle
2. Device was locked/asleep
3. Low Power Mode enabled
4. App Group permissions not set

**Solutions**:
1. Verify extension is in `PlugIns/` folder (Scenario 1)
2. Keep device unlocked during test
3. Disable Low Power Mode
4. Rebuild and reinstall app

#### Issue: Shields Not Reapplying

**Possible Causes**:
1. Tokens expired (FamilyActivitySelection tokens expire after some time)
2. App Group data not accessible
3. Named store mismatch

**Solutions**:
1. Reselect apps in Workout Settings
2. Check Console logs for errors
3. Verify both app and extension use same store name ("workoutShields")

#### Issue: "Selection loaded but no tokens found"

This means the FamilyActivitySelection tokens have expired. This is a limitation of iOS Screen Time API.

**Solution**:
1. Open Pavloff app
2. Go to Workout Settings
3. Select apps again
4. The tokens will be refreshed

### Verify Named Store Configuration

Both the main app and extension must use the same named store:

**ScreenTimeManager.swift**:
```swift
private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("workoutShields"))
```

**DeviceActivityMonitorExtension.swift**:
```swift
let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("workoutShields"))
```

### Check Schedule is Active

Add temporary logging in `setupDailyMonitoring()`:

```swift
do {
    try activityCenter.startMonitoring(scheduleId, during: schedule)
    print("[ScreenTime] ✅ Daily monitoring schedule established for midnight re-lock")
    
    // Verify it's running
    let activities = activityCenter.activities
    print("[ScreenTime] Active schedules: \(activities)")
} catch {
    print("[ScreenTime] ❌ Failed to start monitoring: \(error)")
}
```

## Expected Behavior Summary

| Time | User Action | Expected Result |
|------|-------------|-----------------|
| Setup | Select apps | Apps blocked immediately |
| During day | Complete workout | Apps unlock immediately |
| Midnight | None (app closed) | Apps block automatically |
| Next morning | Open app | Apps blocked (if not already) |
| Next morning | Complete workout | Apps unlock |

## Notes

- **Device must be unlocked** for extension to run reliably (iOS limitation)
- **Changing system time** may not always trigger the extension
- **Real midnight test** is the most reliable
- **Console logs** are essential for debugging
- **Token expiration** is a known iOS limitation - users need to reselect apps periodically

## Reporting Issues

If midnight blocking still doesn't work, collect:

1. Console logs from around midnight
2. App Group UserDefaults contents (check in debugger)
3. Whether extension is in app bundle
4. iOS version and device model
5. Whether Low Power Mode was enabled
6. Whether device was locked at midnight
