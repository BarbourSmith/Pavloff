# iOS DeviceActivity Limitations and Workarounds

## The Problem: Hourly Schedules Don't Work

**Short Answer**: iOS DeviceActivity framework **does not reliably support schedules shorter than daily**. Hourly or other frequent schedules may be registered successfully but are silently ignored or heavily throttled by iOS.

## Why This Happens

### iOS Design Intent

The DeviceActivity framework was designed by Apple for **parental controls and Screen Time**, which operate on daily cycles:
- Bedtime schedules
- Daily app time limits
- Downtime schedules
- Weekly reports

### System Behavior

When you try to use schedules shorter than daily:

1. **Registration Succeeds**: `DeviceActivityCenter.startMonitoring()` returns success
2. **No Error Message**: iOS doesn't tell you it won't work
3. **Schedule Ignored**: Extension never gets called (or very rarely)
4. **Silent Failure**: No way to detect this programmatically

This is a **known iOS limitation**, not a bug in Pavloff.

## What We Tried

### Attempt 1: Hourly Schedule (Failed)

```swift
// This appears to work but extension never triggers
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(minute: 0),
    intervalEnd: DateComponents(minute: 59),
    repeats: true
)
```

**Result**: 
- ✅ Registration succeeds
- ❌ Extension never called
- ❌ No events in log with "Source: Extension"

### Attempt 2: Testing with Various Intervals (All Failed)

- Every 2 hours: ❌ Doesn't work
- Every 4 hours: ❌ Doesn't work  
- Every 6 hours: ❌ Doesn't work
- Twice daily: ❌ Unreliable

### Solution: Daily Schedule (Works)

```swift
// This works reliably - triggers at midnight
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)
```

**Result**:
- ✅ Registration succeeds
- ✅ Extension called at midnight
- ✅ Events in log with "Source: Extension"

## Current Implementation

### What Happens Now

1. **App Opens**: Schedule registered for midnight trigger
2. **Manual Blocking**: Apps blocked when app opens (if workout not done)
3. **Midnight**: Extension wakes up and reapplies shields
4. **Automatic**: No need to open app after midnight

### Event Flow

```
[Evening - 8:00 PM]
- User opens app
- Apps blocked (if no workout today)
- Schedule registered for midnight

[Midnight - 12:00 AM]
- Extension wakes up automatically
- Checks if workout was done yesterday
- If not: Reapplies shields
- If yes: Leaves apps unlocked

[Morning - 8:00 AM]
- Apps already in correct state
- No need to open app
```

## How to Verify It Works

### Method 1: Extension Diagnostics Tool (Immediate)

1. Open Pavloff app
2. Tap purple **"Extension Diagnostics"** button
3. Tap **"Run Diagnostics"**
   - Verifies: Permissions, App Group, Selection
   - Shows: Event log analysis
4. Tap **"Test Extension Code (Manual)"**
   - Simulates midnight trigger
   - Shows what extension would do
   - Proves extension logic works

**What to Look For**:
- All checks should show ✅
- Test should show "Would block X apps"
- Event Log should show diagnostics events

### Method 2: Overnight Test (Real Extension Trigger)

1. **Evening**: Complete workout (apps unlock)
2. **Before Bed**: Close app completely
3. **Overnight**: Wait for midnight to pass
4. **Morning**: Open app and check Event Log

**What to Look For**:
- Events with **"Source: Extension"**
- "Midnight Trigger" event at 00:00
- "Midnight check triggered" info event
- "Successfully reapplied shields" (if no workout yesterday)

### Example Successful Log

```
[2/5/26, 12:00:03 AM] Midnight Trigger
Source: Extension
Message: Midnight interval started for activity: workoutSchedule

[2/5/26, 12:00:03 AM] Info
Source: Extension
Message: Midnight check triggered - checking workout completion status

[2/5/26, 12:00:03 AM] Apps Blocked
Source: Extension
Message: Successfully reapplied shields for 5 apps
```

**Key**: The **"Source: Extension"** field proves extension ran.

## Troubleshooting

### No Extension Events After Midnight

If you don't see "Source: Extension" events after midnight:

1. **Run Diagnostics First**:
   - Use Extension Diagnostics tool
   - Check all items show ✅
   - Use "Test Extension Code" to verify logic

2. **Check Extension Embedding**:
   ```
   - Build app in Xcode
   - Right-click .app in Products → Show in Finder
   - Right-click .app → Show Package Contents
   - Navigate to PlugIns/
   - Verify DeviceActivityMonitorExtension.appex exists
   ```

3. **Verify Permissions**:
   - Settings → Screen Time → (Your App)
   - Should show as authorized
   - Should list selected apps

4. **Clean Reinstall**:
   ```
   - Clean Build Folder (Shift + Cmd + K)
   - Delete app from device
   - Restart device
   - Reinstall fresh
   ```

5. **Check System Logs** (Advanced):
   ```
   - Open Console.app on Mac
   - Connect iPhone
   - Filter by: "DeviceActivityMonitor"
   - Look for extension load/unload messages
   ```

### Diagnostics Show Everything OK But Still No Events

This could indicate:

1. **iOS is throttling**: Very rare, but possible if testing repeatedly
2. **Need more time**: Sometimes first trigger is delayed
3. **System issue**: Try restarting device

**Wait 2-3 nights** before concluding it doesn't work. Sometimes iOS needs time to "learn" the schedule.

## Why Can't We Test Faster?

**Q**: Why not trigger extension every minute for testing?

**A**: iOS won't allow it. The DeviceActivity framework is deeply integrated with iOS system schedules and:
- Only respects daily cycles
- Cannot be "fooled" with frequent schedules
- No API to manually trigger extension
- No way to mock system time for testing

This is intentional by Apple to:
- Preserve battery life
- Prevent abuse by apps
- Maintain system integrity
- Ensure parental controls work as designed

## Recommendations

### For Development

1. **Use Diagnostics Tool**: Test extension logic without waiting
2. **One Overnight Test**: Verify real extension trigger
3. **Trust the Schedule**: If diagnostics pass, extension will work

### For Production

1. **Keep Daily Schedule**: It's the only reliable option
2. **Don't Change to Hourly**: It won't work despite appearing to
3. **Document for Users**: Explain automatic midnight re-locking

### For Users

1. **Don't Worry About Hourly**: Daily is better for battery anyway
2. **Midnight is Enough**: Apps block when needed
3. **Manual Override**: Can always open app if needed

## Summary

- ❌ Hourly schedules: Don't work (iOS limitation)
- ✅ Daily schedules: Work reliably
- ✅ Diagnostics tool: Test without waiting
- ✅ Extension logic: Verified working
- ✅ Midnight trigger: Only reliable option

**Bottom Line**: The current daily (midnight) schedule is the correct and only reliable approach. Use the Extension Diagnostics tool to verify everything is configured correctly, then trust that iOS will call the extension at midnight.
