# Midnight Blocking Diagnostic Guide

## Issue
Apps remain unblocked in the morning until Pavloff app is opened, indicating the DeviceActivityMonitor extension is not firing at midnight.

## Diagnostic Checklist

### 1. Verify Extension is in App Bundle

After building, check if the extension is actually included:

```bash
# On Mac, after installing to device
# Find the .app in Xcode's Products folder
# Right-click esp32Connect.app → Show Package Contents
# Navigate to PlugIns/
# You should see: DeviceActivityMonitorExtension.appex
```

**Expected**: Extension file exists in PlugIns folder  
**If missing**: Extension is not being embedded - build configuration issue

### 2. Check Console Logs at Midnight

**CRITICAL**: Console logs are the only way to know if the extension is running.

**Setup**:
1. Connect iPhone to Mac via cable
2. Open Console.app on Mac
3. Select your iPhone in sidebar
4. In search bar, enter: `DeviceActivityMonitor`
5. Keep Console.app open through midnight

**What to look for**:

#### Scenario A: NO logs at all
```
[No messages containing "DeviceActivityMonitor"]
```
**Diagnosis**: Extension is not loading. Possible causes:
- Extension not embedded in bundle
- Wrong NSExtensionPointIdentifier (should be `com.apple.deviceactivity-monitor`)
- Extension target not building
- Code signing issue

#### Scenario B: Logs but no "Interval started"
```
[Earlier logs from setup, but nothing at midnight]
```
**Diagnosis**: Monitoring schedule not triggering. Possible causes:
- Device was locked/asleep
- Low Power Mode enabled
- Monitoring was stopped
- Schedule not properly set up

#### Scenario C: "Interval started" but no shield reapplication
```
[DeviceActivityMonitor] ⏰ Interval started for activity: workoutSchedule
[DeviceActivityMonitor] 🔄 Midnight reset triggered
[DeviceActivityMonitor] ❌ No saved selection data found
```
**Diagnosis**: Extension is firing but can't access data. Possible causes:
- App Group not configured correctly
- Token expiration
- Data not being saved properly

#### Scenario D: Everything logs correctly
```
[DeviceActivityMonitor] ⏰ Interval started for activity: workoutSchedule
[DeviceActivityMonitor] 🔄 Midnight reset triggered
[DeviceActivityMonitor] 📦 Found saved selection data (XXX bytes)
[DeviceActivityMonitor] 🛡️ Reapplied shields for X apps
```
**Diagnosis**: Extension is working. If apps still not blocked:
- Named ManagedSettingsStore mismatch
- Shields being cleared elsewhere
- iOS bug

### 3. Check Monitoring is Active

Add temporary debugging to ScreenTimeManager.swift:

```swift
// In setupDailyMonitoring(), after startMonitoring:
let activities = activityCenter.activities
print("[ScreenTime] 📋 Active activities: \(activities)")
```

This will show if monitoring is actually registered.

### 4. Verify App Group Configuration

Both app and extension must use same App Group:

**Main app entitlements** (`esp32Connect.entitlements`):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.maslowcnc.Tides</string>
</array>
```

**Extension entitlements** (`DeviceActivityMonitorExtension.entitlements`):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.maslowcnc.Tides</string>
</array>
```

### 5. Test Extension Loading with Forced Trigger

Instead of waiting for midnight, you can test if the extension loads by:

1. Set device time to 11:58 PM
2. Wait 2-3 minutes
3. Watch Console.app
4. Set device time to 12:01 AM

If extension is working, you'll see logs immediately.

### 6. Check for iOS Restrictions

DeviceActivity extensions have requirements:
- **Device must be unlocked** (not sleeping)
- **Low Power Mode must be off**
- **iOS 16.0+** required
- **Physical device only** (not simulator)
- **Screen Time enabled** in Settings

### 7. Verify Build Configuration

Check that extension target is building:

1. Open Xcode
2. Select "DeviceActivityMonitorExtension" scheme
3. Try to build (Cmd+B)
4. Should build without errors

### 8. Check Code Signing

Extension must be properly signed:

1. Select DeviceActivityMonitorExtension target
2. Go to "Signing & Capabilities"
3. Verify:
   - Team is selected
   - Signing certificate is valid
   - Provisioning profile exists

## Common Issues and Solutions

### Issue: "No logs at all in Console"

**Solution 1**: Check extension is embedded
```bash
# After building, verify extension is in app bundle
# If missing, check project.pbxproj Embed Foundation Extensions phase
```

**Solution 2**: Rebuild extension
```bash
# In Xcode:
# 1. Clean Build Folder (Shift+Cmd+K)
# 2. Delete Derived Data
# 3. Rebuild
```

### Issue: "Interval started but no shield reapplication"

**Solution**: Check App Group data
```swift
// Add to extension temporarily:
NSLog("[DeviceActivityMonitor] 🔍 hasAppSelection: \(userDefaults.bool(forKey: "hasAppSelection"))")
if let data = userDefaults.data(forKey: "savedAppSelection") {
    NSLog("[DeviceActivityMonitor] 🔍 Selection data size: \(data.count) bytes")
}
```

### Issue: "Device was asleep at midnight"

**Solution**: Keep device unlocked
- Plug in device (charging)
- Set Auto-Lock to "Never" (temporarily)
- Keep screen on during test

### Issue: "Tokens expired"

If you see: `⚠️ Selection loaded but no tokens found`

**Solution**: Reselect apps
1. Open Pavloff
2. Go to Workout Settings
3. Select apps again
4. Tokens will be refreshed

## Debugging Code to Add

### In DeviceActivityMonitorExtension.swift

Add at the very beginning of `intervalDidStart`:

```swift
override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    
    // Log EVERYTHING for debugging
    NSLog("[DeviceActivityMonitor] ========== INTERVAL START ==========")
    NSLog("[DeviceActivityMonitor] ⏰ Time: \(Date())")
    NSLog("[DeviceActivityMonitor] 🎯 Activity: \(activity)")
    NSLog("[DeviceActivityMonitor] 📱 Device: \(UIDevice.current.name)")
    
    // ... rest of code
}
```

### In ScreenTimeManager.swift

Add logging when monitoring is set up:

```swift
private func setupDailyMonitoring() {
    activityCenter.stopMonitoring([scheduleId])
    
    NSLog("[ScreenTime] ========== SETUP MONITORING ==========")
    NSLog("[ScreenTime] ⏰ Time: \(Date())")
    
    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
    )
    
    do {
        try activityCenter.startMonitoring(scheduleId, during: schedule)
        NSLog("[ScreenTime] ✅ Monitoring started successfully")
        NSLog("[ScreenTime] 📋 Next trigger: Tomorrow at 00:00")
    } catch {
        NSLog("[ScreenTime] ❌ Failed: \(error)")
    }
}
```

## Expected Console Output

### When app launches and sets up monitoring:
```
[ScreenTime] ========== SETUP MONITORING ==========
[ScreenTime] ⏰ Time: 2026-01-17 20:30:00
[ScreenTime] ✅ Monitoring started successfully
[ScreenTime] 📋 Next trigger: Tomorrow at 00:00
```

### At midnight when extension fires:
```
[DeviceActivityMonitor] ========== INTERVAL START ==========
[DeviceActivityMonitor] ⏰ Time: 2026-01-18 00:00:05
[DeviceActivityMonitor] 🎯 Activity: workoutSchedule
[DeviceActivityMonitor] 🔄 Midnight reset triggered
[DeviceActivityMonitor] 📅 Last workout completion: 2026-01-17 18:45:30
[DeviceActivityMonitor] 📅 Today: 2026-01-18 00:00:00
[DeviceActivityMonitor] ✅ Workout not completed today yet - reapplying shields
[DeviceActivityMonitor] 📦 Found saved selection data (1234 bytes)
[DeviceActivityMonitor] 🛡️ Reapplied shields for 3 apps
```

## Next Steps

1. **First**: Check Console logs to see which scenario you're in
2. **If NO logs**: Extension isn't loading - check build/embedding
3. **If logs but not working**: Data or coordination issue
4. **Report findings**: Share Console output so we can diagnose further

## Alternative Workaround

If extension continues not working, we can implement a backup notification-based approach:
1. Schedule local notification for midnight
2. App handles notification in background
3. Reapply shields when notification fires

This is less reliable but better than nothing.
