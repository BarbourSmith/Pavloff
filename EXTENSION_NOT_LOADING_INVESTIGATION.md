# Extension Not Loading - Investigation Guide

## Symptom
Monitoring setup logs appear in Xcode console, but **NO** `[DeviceActivityMonitor]` logs appear in Console.app at any time, including at midnight.

## What This Means
The DeviceActivityMonitor extension is not being loaded by iOS at all. This is different from:
- Extension loading but not triggering (would see initial logs)
- Extension triggering but failing (would see error logs)

No logs = iOS never loads the extension.

## Possible Causes

### 1. Extension Not in App Bundle

**Most likely cause if logs never appear**

The extension might not be getting embedded in the final app bundle despite being in the Xcode project.

**How to verify:**
```bash
# After building in Xcode:
# 1. Go to Products folder (Cmd+1, select esp32Connect.app)
# 2. Right-click → Show in Finder
# 3. Right-click esp32Connect.app → Show Package Contents
# 4. Navigate to PlugIns/
# 5. Look for DeviceActivityMonitorExtension.appex

# If file is missing, extension is not being embedded
```

**How to fix:**
- Clean build folder (Shift+Cmd+K)
- Delete derived data
- Rebuild BOTH targets:
  1. Select "esp32Connect" scheme → Build
  2. Select "DeviceActivityMonitorExtension" scheme → Build
  3. Select "esp32Connect" scheme again → Build

### 2. Extension Not Building

Check Xcode build log (Cmd+9 → Build tab):

**Look for:**
```
Building DeviceActivityMonitorExtension...
Compiling DeviceActivityMonitorExtension.swift
Linking DeviceActivityMonitorExtension
```

**If missing:**
- Extension target not building
- Check target dependencies
- Check build settings

### 3. Code Signing Issues

DeviceActivity extensions require proper signing.

**Check:**
1. Select DeviceActivityMonitorExtension target
2. Signing & Capabilities tab
3. Verify:
   - Team is selected (same as main app)
   - Signing certificate valid
   - Provisioning profile exists

**Common issue:** Extension using different team than main app

### 4. iOS Requirements Not Met

DeviceActivity extensions have strict requirements:

**Device State:**
- ✅ Device must be **UNLOCKED** when extension should fire
- ✅ Device must be **AWAKE** (not sleeping)
- ❌ Low Power Mode **disables** background extensions
- ❌ Do Not Disturb may affect extension loading

**iOS Version:**
- Requires iOS 16.0+
- Check: Settings → General → About → Software Version

**Screen Time:**
- Must be enabled: Settings → Screen Time
- Must have permission granted to app

### 5. Extension Not Registered with iOS

Even if embedded, iOS might not recognize it.

**Check entitlements match:**

Main app (`esp32Connect.entitlements`):
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.maslowcnc.Tides</string>
</array>
```

Extension (`DeviceActivityMonitorExtension.entitlements`):
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.maslowcnc.Tides</string>
</array>
```

**Must be IDENTICAL** App Group identifiers.

### 6. Extension Info.plist Issues

**Verify Info.plist:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity-monitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

**Critical:** Extension point identifier must be **exactly** `com.apple.deviceactivity-monitor` with hyphen.

### 7. Schedule Not Properly Registered

If monitoring setup succeeds but extension never fires:

**Add debug logging:**
```swift
// In setupDailyMonitoring(), after startMonitoring:
let activities = activityCenter.activities
print("[ScreenTime] Registered activities: \(activities)")
```

Should show the schedule is registered.

## Testing Methodology

### Test 1: Verify Extension in Bundle
```bash
# After build, check app contents
# If DeviceActivityMonitorExtension.appex is in PlugIns/, it's embedded
# If not, rebuild process is failing
```

### Test 2: Build Extension Directly
```bash
# In Xcode:
# 1. Select DeviceActivityMonitorExtension scheme
# 2. Build (Cmd+B)
# 3. Check for build errors
```

### Test 3: Test with Device Unlocked
```
1. Device plugged in (charging)
2. Auto-Lock set to "Never"
3. Screen brightness at 100%
4. Keep screen ON during test
5. Console.app filtering "DeviceActivity" OR "workoutSchedule"
6. Change time from 11:58 PM to 12:01 AM
7. Watch for logs immediately
```

### Test 4: Check iOS System Logs
In Console.app, also filter by:
- "extension" (look for loading errors)
- "SpringBoard" (iOS launcher, shows extension loading)
- Any error messages at midnight

## Known iOS Limitations

### Extensions May Not Fire If:
1. **Device locked** - Most common issue
2. **Low Power Mode enabled** - Extensions disabled
3. **Do Not Disturb active** - May affect scheduling
4. **Device asleep** - Screen must be on or device charging
5. **First 24 hours after install** - iOS may not trust extension yet
6. **After force-quit of app** - May need to open app once

### Extension Delay
Even when working, extension may fire 1-5 minutes after midnight, not exactly at 00:00:00.

## Diagnostic Commands

### Check if extension is in app
```bash
# After installing to device via Xcode
# Connect device
# Use Xcode → Window → Devices and Simulators
# Select your device → Installed Apps
# Find esp32Connect → Show Container
# Navigate to .app bundle
# Check PlugIns/ folder
```

### Check Console for any extension activity
```bash
# In Console.app, try broader filters:
# - "DeviceActivity" (no results = not loading)
# - "workoutSchedule" (no results = schedule not registered)
# - "extension" + process:SpringBoard (shows extension loading)
```

## Workaround: Notification-Based Approach

If extension continues not working, alternative approach:

```swift
// Schedule local notification for midnight
let content = UNMutableNotificationContent()
content.title = "Daily Reset"
content.body = "Time to re-lock apps"
content.sound = nil

var dateComponents = DateComponents()
dateComponents.hour = 0
dateComponents.minute = 0

let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
let request = UNNotificationRequest(identifier: "midnightReset", content: content, trigger: trigger)

// Handle notification in background
// Reapply shields when notification fires
```

This is less reliable but better than nothing.

## Next Steps

1. **Verify extension is in app bundle** - Most important
2. If in bundle but not loading → Check code signing
3. If still issues → Test with device unlocked and screen on
4. If still failing → iOS may require app to be opened once after midnight
5. Consider notification-based workaround as backup

## Expected Behavior When Working

**Console.app at midnight should show:**
```
[DeviceActivityMonitor] ========================================
[DeviceActivityMonitor] ⏰ INTERVAL START - Time: 2026-01-XX 00:00:XX
[DeviceActivityMonitor] 🎯 Activity name: workoutSchedule
[DeviceActivityMonitor] ========================================
[DeviceActivityMonitor] 🔄 Midnight reset triggered
```

If you see NOTHING, extension is not loading.
