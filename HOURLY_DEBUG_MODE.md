# Hourly Debug Mode Configuration

## Overview

The DeviceActivityMonitor extension has been configured to trigger every hour (instead of only at midnight) to make debugging significantly easier.

## Current Configuration

### Schedule
- **Interval**: Every hour
- **Start**: Minute 0 (XX:00)
- **End**: Minute 59 (XX:59)
- **Repeats**: Yes

### Trigger Times
The extension will trigger at:
- 12:00 AM
- 1:00 AM
- 2:00 AM
- ... every hour ...
- 10:00 PM
- 11:00 PM

### Event Log Messages
When the extension triggers, you'll see:
- "Hourly interval started for activity: workoutSchedule [Debug Mode]"
- "Hourly check triggered - checking workout completion status [Debug Mode]"

All debug mode messages include the `[Debug Mode]` tag for clarity.

## Benefits for Debugging

### 1. Faster Testing Cycle
**Before** (midnight only):
- Make a change
- Wait until midnight (potentially 23+ hours)
- Check if it works
- If not, wait another 24 hours

**After** (hourly):
- Make a change
- Wait up to 1 hour for next trigger
- Check if it works
- Can iterate multiple times per day

### 2. Easier Verification
- Can verify extension is working within an hour of installation
- Can test multiple scenarios in a single day
- Don't need to stay up until midnight to see results

### 3. Better Log History
- More data points in the Event Log
- Can see pattern of extension behavior over time
- Easier to spot if extension stops working

## How to Test

### Basic Verification

1. **Install the app**:
   - Clean build in Xcode
   - Install on physical device
   - Grant all permissions

2. **Check registration**:
   - Open app → Event Log
   - Look for: "Hourly monitoring schedule registered successfully"

3. **Wait for trigger**:
   - Note the current time (e.g., 2:45 PM)
   - Calculate next hour (3:00 PM)
   - Wait for that time
   - Check Event Log for new events

4. **Verify events**:
   ```
   [3:00 PM] Hourly Trigger
      "Hourly interval started for activity: workoutSchedule [Debug Mode]"
      Source: Extension
   
   [3:00 PM] Info
      "Hourly check triggered - checking workout completion status [Debug Mode]"
      Source: Extension
   
   [3:00 PM] Apps Blocked (if workout not done)
      "Successfully reapplied shields for X apps"
      Source: Extension
   ```

### Testing Scenarios

#### Scenario 1: No Workout Completed
1. Install app (e.g., at 2:00 PM)
2. Select apps to block
3. Don't complete workout
4. Wait for next hour (3:00 PM)
5. **Expected**: Extension triggers and reapplies shields
6. **Event Log should show**: Hourly trigger → Apps blocked

#### Scenario 2: Workout Completed
1. Install app (e.g., at 2:00 PM)
2. Complete workout (apps unlock)
3. Wait for next hour (3:00 PM)
4. **Expected**: Extension triggers but doesn't block (workout done today)
5. **Event Log should show**: Hourly trigger → "Workout already completed today"

#### Scenario 3: Multiple Hours
1. Install app at 2:00 PM
2. Complete workout at 2:30 PM
3. Check Event Log at 5:00 PM
4. **Expected**: Should see triggers at 3:00 PM, 4:00 PM, and 5:00 PM
5. All showing workout already completed

## Production Configuration

### When to Change Back

Change back to midnight-only schedule when:
- ✅ Extension is confirmed working
- ✅ All debugging is complete
- ✅ Ready for production release
- ✅ Want to optimize battery usage

### How to Change Back

In `ios/esp32Connect/ScreenTimeManager.swift`, change the `setupDailyMonitoring()` function:

**Current (Debug - Hourly)**:
```swift
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(minute: 0),
    intervalEnd: DateComponents(minute: 59),
    repeats: true
)
```

**Production (Daily - Midnight)**:
```swift
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)
```

Also update the log messages:
- "Hourly monitoring schedule" → "Daily monitoring schedule"
- "extension should trigger every hour" → "extension should trigger at midnight"

In `ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`:
- "Hourly interval started" → "Midnight interval started"
- "Hourly check triggered" → "Midnight reset triggered"
- Remove "[Debug Mode]" tags

### Battery Impact

**Hourly Schedule**:
- Extension wakes 24 times per day
- More battery usage
- Acceptable for debugging/testing
- **Not recommended for production**

**Daily Schedule**:
- Extension wakes 1 time per day (midnight)
- Minimal battery impact
- Standard production configuration
- **Recommended for release**

## Troubleshooting

### Extension Not Triggering Hourly

1. **Check Event Log**:
   - Look for "Hourly monitoring schedule registered successfully"
   - If missing, schedule wasn't registered

2. **Verify Time**:
   - Extension triggers at XX:00 (top of hour)
   - If you check at 3:15 PM, next trigger is 4:00 PM
   - Be patient and wait

3. **Check Device State**:
   - Device must be unlocked at least once after the hour
   - Low Power Mode may delay triggers
   - Device must have network/time sync

4. **Check Console Logs**:
   - Connect device to Xcode
   - Open Console (Window → Devices and Simulators)
   - Filter for "DeviceActivityMonitor"
   - Look for extension messages

5. **Reinstall Fresh**:
   - Sometimes helps to clean build
   - Delete app completely
   - Restart device
   - Reinstall and test

### Events Not Appearing

If hourly triggers aren't showing in Event Log:

1. **Extension Not Running**:
   - Verify Info.plist has correct identifier
   - Check extension is in app bundle
   - Review EXTENSION_TROUBLESHOOTING.md

2. **Event Log Not Updating**:
   - Close and reopen Event Log view
   - Events persist even if app is closed
   - Restart app if needed

3. **Permissions Issue**:
   - Verify Screen Time permission granted
   - Verify Family Controls permission granted
   - Check App Groups entitlement

## Timeline Comparison

### Debug Mode (Hourly) - Current Configuration

```
12:00 PM - Install app
12:15 PM - Select apps
1:00 PM  - ✅ Extension triggers (15 min wait)
2:00 PM  - ✅ Extension triggers
3:00 PM  - ✅ Extension triggers
4:00 PM  - ✅ Extension triggers

Result: 4 triggers in 4 hours, can verify quickly
```

### Production Mode (Midnight Only)

```
12:00 PM - Install app
12:15 PM - Select apps
...
12:00 AM - ✅ Extension triggers (11:45 wait)

Result: 1 trigger in ~12 hours, must wait overnight
```

## Best Practices

### During Development
1. ✅ Use hourly schedule
2. ✅ Test multiple scenarios quickly
3. ✅ Export logs frequently
4. ✅ Document any issues found

### Before Release
1. ✅ Change back to daily schedule
2. ✅ Test overnight to confirm midnight trigger
3. ✅ Update documentation
4. ✅ Remove debug mode tags from messages

### For Users
1. ✅ Daily schedule (midnight only)
2. ✅ Minimal battery impact
3. ✅ Clear messaging about midnight behavior
4. ✅ Event Log still available for troubleshooting

## Files Modified

- `ios/esp32Connect/ScreenTimeManager.swift` - Changed schedule to hourly
- `ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` - Updated messages for debug mode

## Commit

- **8eb528c** - Change extension to trigger hourly for easier debugging

## Related Documentation

- **EXTENSION_TROUBLESHOOTING.md** - General extension debugging
- **INFO_PLIST_FIX.md** - Extension configuration fix
- **EVENT_LOG_EXPORT.md** - How to export logs for sharing
