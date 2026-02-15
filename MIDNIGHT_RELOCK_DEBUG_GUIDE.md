# Midnight Re-Lock Debugging Guide

## Quick Fixes Applied

I've identified and fixed several critical issues:

### 1. ✅ Fixed Extension Point Identifier
- **Issue**: Info.plist used `com.apple.deviceactivity-monitor` 
- **Fix**: Changed to `com.apple.deviceactivity-monitor.extension`
- **File**: `DeviceActivityMonitorExtension/Info.plist`

### 2. ✅ Fixed Schedule Gap
- **Issue**: Schedule ended at 23:00, creating 1-hour gap
- **Fix**: Changed to 23:59 to minimize gap
- **File**: `ScreenTimeManager.swift`

### 3. ✅ Fixed Event Threshold
- **Issue**: Event had 1-minute delay
- **Fix**: Changed to 0 minutes for immediate trigger
- **File**: `ScreenTimeManager.swift`

### 4. ✅ Added Comprehensive Logging
- Enhanced all log statements with timestamps and details
- Added state debugging in the extension

## Testing Steps

### Step 1: Check Extension Installation
1. Build and run the app on a physical device
2. Open iOS Console app on Mac, connect device
3. Filter logs by "DeviceActivityMonitor"
4. Look for: `Extension initialized` log message

### Step 2: Verify App Selection Storage
In the main app, when selecting apps, look for these logs:
```
[ScreenTime] Selection saved successfully to App Group
[ScreenTime] Daily monitoring schedule established for midnight re-lock
```

### Step 3: Test Midnight Trigger (Manual)
**Method 1: Change Device Time**
1. Complete workout to unlock apps
2. Close the main app completely
3. Go to Settings > General > Date & Time
4. Turn off "Set Automatically"
5. Set time to 11:58 PM
6. Wait 2 minutes for midnight to pass
7. Check Console logs for extension activity

**Method 2: Use Xcode Debugger**
1. In Xcode, go to Debug > Attach to Process
2. Search for your app's extension process
3. Set breakpoints in `intervalDidStart` method
4. Change device time to trigger midnight

### Step 4: Check Extension Logs
Look for these log patterns in Console:

**✅ Success Pattern:**
```
[DeviceActivityMonitor] 2026-02-15 00:00:01: Extension initialized
[DeviceActivityMonitor] 2026-02-15 00:00:01: ⭐ Interval started for activity: workoutSchedule
[DeviceActivityMonitor] 2026-02-15 00:00:01: Midnight reset triggered
[DeviceActivityMonitor] Successfully accessed App Group UserDefaults
[DeviceActivityMonitor] Workout not completed today yet - reapplying shields
[DeviceActivityMonitor] ✅ Reapplied shields for X apps
```

**❌ Problem Patterns:**
```
# Extension not loading:
(No logs with "Extension initialized")

# App Group access issue:
ERROR: Failed to access App Group UserDefaults

# No app selection:
No apps selected, skipping shield application

# Token decode failure:
❌ Failed to decode selection: [error]
```

## Common Issues & Solutions

### Issue 1: Extension Not Triggering
**Symptoms**: No extension logs in Console
**Causes**: 
- Extension not properly embedded in main app
- Device Activity permissions not granted
- Extension target not properly configured

**Solutions**:
1. In Xcode, select main app target
2. Go to "Build Phases" > "Embed App Extensions"  
3. Ensure DeviceActivityMonitorExtension is listed
4. Clean build folder and rebuild

### Issue 2: App Group Access Fails
**Symptoms**: "Failed to access App Group UserDefaults"
**Solution**: Verify both targets have identical App Group identifier:
- Main app: `group.com.maslowcnc.Tides`
- Extension: `group.com.maslowcnc.Tides`

### Issue 3: No App Selection Data
**Symptoms**: "No saved selection data found"
**Causes**: 
- User hasn't selected apps yet
- Data not properly saved to App Group
- App Group storage cleared

**Solution**:
1. Go to app's Workout Settings
2. Re-select apps to block
3. Verify you see "Selection saved successfully" log

### Issue 4: Token Decode Failure
**Symptoms**: "Failed to decode selection"
**Causes**: FamilyActivitySelection tokens expired
**Solution**: FamilyControls tokens have limited lifetime. User must:
1. Re-authorize Family Controls permission
2. Re-select apps in Workout Settings

### Issue 5: Shields Not Applied
**Symptoms**: Extension runs but apps not blocked
**Causes**: 
- Empty token selection
- ManagedSettingsStore API failure
**Solution**: Check for "⚠️ Warning: Selection decoded but contains no tokens"

## Advanced Debugging

### Enable Extension Debugging
1. In Xcode, go to Product > Scheme > Edit Scheme
2. Select "Run" tab
3. Set executable to DeviceActivityMonitorExtension.appex
4. Run to attach debugger to extension

### Check App Group Storage Manually
Add this debugging code to main app:
```swift
// In ScreenTimeManager or WorkoutView
func debugAppGroupStorage() {
    guard let userDefaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
        print("❌ Cannot access App Group")
        return
    }
    
    print("🔍 App Group Debug:")
    print("hasAppSelection: \(userDefaults.bool(forKey: "hasAppSelection"))")
    print("savedAppSelection size: \(userDefaults.data(forKey: "savedAppSelection")?.count ?? 0)")
    print("lastWorkoutCompletion: \(userDefaults.object(forKey: "lastWorkoutCompletion") ?? "nil")")
}
```

### Monitor ManagedSettingsStore
Unfortunately, you can't directly read shield state, but you can test:
1. Apply shields manually in main app
2. Check if blocked apps show shield screen
3. Remove shields and verify apps unlock

## Testing Checklist

- [ ] Extension shows "initialized" log
- [ ] App selection saves successfully  
- [ ] Monitoring schedule starts without errors
- [ ] Extension triggers at midnight (use manual time change)
- [ ] App Group data accessible in extension
- [ ] Shields successfully reapplied
- [ ] Blocked apps show shield screen after midnight

## Fallback Mode Testing

If extension doesn't work, the app has fallback mode:
1. Complete workout (apps unlock)
2. Close app completely
3. Wait until next day (or change date)
4. Open app
5. Should see: "Workout not completed today yet - reapplying shields"
6. Apps should be blocked again

## Device Requirements

- iOS 15.0+ (Family Controls requirement)
- Physical device (extensions don't work in Simulator)
- Family Controls permission granted
- Screen Time enabled in Settings

## Next Steps If Issue Persists

1. Try the fixes provided above
2. Run through the testing checklist
3. Check Console logs during testing
4. If extension still doesn't trigger, the issue might be:
   - Xcode project configuration problem
   - iOS system-level DeviceActivity service issue
   - App signing/provisioning problem

The fallback mode should still work even if the extension doesn't trigger, so apps should re-lock when you open the app the next morning.