# Testing Guide for Auto-Connect Feature

## Prerequisites

Before testing, ensure you have:
1. A physical iOS or Android device (Bluetooth LE testing requires real hardware)
2. An ESP32 device with:
   - Device name set to exactly `ESP32_IMU_Stream`
   - BLE service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
   - At least one characteristic that sends rep counter data
   - Data format: `Count:X,State:Y` (e.g., `Count:5,State:UP`)

## Test Scenarios

### Test 1: Fresh App Launch with Device Available

**Setup:**
- ESP32 device is powered on and advertising
- App is not running

**Steps:**
1. Launch the app
2. Grant Bluetooth permissions when prompted

**Expected Result:**
- App displays "Scanning for ESP32_IMU_Stream..." message
- Loading indicator shows scanning is active
- Within 10 seconds, app finds device and shows "Connecting to ESP32_IMU_Stream..."
- Status changes to "Discovering services..."
- After successful connection, status shows "Connected to ESP32_IMU_Stream"
- Rep counter displays with current count and state

**Verification Points:**
- ✓ Auto-scan starts immediately
- ✓ Device is found automatically
- ✓ Connection happens without user interaction
- ✓ Rep counter displays data

---

### Test 2: App Launch with Device Not Available

**Setup:**
- ESP32 device is powered off or out of range
- App is not running

**Steps:**
1. Launch the app
2. Observe behavior for 30 seconds

**Expected Result:**
- App displays "Scanning for ESP32_IMU_Stream..." message
- After 10 seconds, status shows "ESP32_IMU_Stream not found. Will retry..."
- App continues scanning every 5 seconds
- Status alternates between "Scanning..." and "not found"
- Loading indicator continuously shows activity

**Verification Points:**
- ✓ App doesn't crash or freeze
- ✓ Periodic scanning occurs every ~5 seconds
- ✓ User-friendly error messages displayed
- ✓ No timeout or giving up

---

### Test 3: Device Becomes Available While App Running

**Setup:**
- App is running with ESP32 not found
- ESP32 is powered off

**Steps:**
1. Let app run with "not found" status
2. Power on ESP32 device
3. Wait for next scan cycle (up to 5 seconds)

**Expected Result:**
- Next scan cycle finds the device
- App automatically connects
- Rep counter appears and starts displaying data

**Verification Points:**
- ✓ No user interaction needed
- ✓ Connection happens automatically on next scan
- ✓ Transition is smooth

---

### Test 4: Connection Lost During Operation

**Setup:**
- App is connected and displaying data
- ESP32 is running

**Steps:**
1. Verify app is showing rep counter data
2. Power off or move ESP32 out of range
3. Observe app behavior

**Expected Result:**
- Connection error is detected
- Status changes to "Connection lost. Retrying..."
- App automatically starts scanning again
- Rep counter disappears
- Scanning status appears

**Verification Points:**
- ✓ Error is handled gracefully
- ✓ App automatically resumes scanning
- ✓ No crash or freeze
- ✓ Reconnection will happen when device returns

---

### Test 5: Reconnection After Connection Lost

**Setup:**
- App lost connection (from Test 4)
- App is scanning

**Steps:**
1. Power on ESP32 device again
2. Wait for scan to find device

**Expected Result:**
- Device is found in next scan cycle
- App automatically reconnects
- Rep counter reappears with current data
- No user interaction required

**Verification Points:**
- ✓ Automatic reconnection works
- ✓ Data monitoring resumes
- ✓ State is consistent

---

### Test 6: Multiple App Restarts

**Setup:**
- ESP32 is running and available

**Steps:**
1. Launch app - verify connection
2. Close app (swipe away)
3. Relaunch app - verify connection
4. Repeat 3-4 times

**Expected Result:**
- Each launch follows the same pattern
- Auto-scan and auto-connect work consistently
- No degradation or resource leaks
- Rep counter displays correctly each time

**Verification Points:**
- ✓ Consistent behavior across restarts
- ✓ No memory leaks or connection issues
- ✓ Clean startup each time

---

### Test 7: Bluetooth Off/On Cycle

**Setup:**
- App is running
- ESP32 is available

**Steps:**
1. Turn off Bluetooth on phone
2. Observe app behavior
3. Turn Bluetooth back on
4. Observe recovery

**Expected Result:**
- When BT off: Status shows "Bluetooth is PoweredOff. Please enable Bluetooth."
- When BT on: App resumes scanning automatically
- Device is found and connected
- Rep counter reappears

**Verification Points:**
- ✓ Bluetooth state is detected
- ✓ Appropriate message shown
- ✓ Recovery is automatic

---

### Test 8: Wrong Device Name

**Setup:**
- ESP32 device name is NOT "ESP32_IMU_Stream"
- App is running

**Steps:**
1. Launch app
2. Wait for 30+ seconds

**Expected Result:**
- App continuously scans
- Shows "ESP32_IMU_Stream not found. Will retry..."
- Never connects to the wrong device
- Continues scanning indefinitely

**Verification Points:**
- ✓ Only connects to exact device name match
- ✓ Ignores other devices
- ✓ Clear messaging about target device

---

## Performance Checks

### Battery Usage
- Monitor battery consumption during extended scanning
- Scanning should not drain battery excessively

### CPU/Memory
- Check CPU usage - should be minimal during scanning
- Memory usage should remain stable (no leaks)

### Network/BLE
- Verify BLE scanning doesn't interfere with other apps
- Check that scan intervals are respected (not too frequent)

---

## Console Log Verification

When testing, monitor console logs for:

```
[AUTO-SCAN] Scanning for ESP32_IMU_Stream...
[AUTO-SCAN] Found device: ESP32_IMU_Stream (...)
[AUTO-SCAN] Target device found!
[AUTO-CONNECT] Attempting to connect to ESP32_IMU_Stream...
[AUTO-CONNECT] Connected, discovering services...
[AUTO-CONNECT] Successfully connected and configured
[MONITORING] Starting monitoring for ESP32_IMU_Stream
[DATA] ...accel: "Count:5,State:UP"
```

Error scenarios should show:
```
[AUTO-SCAN] Bluetooth is PoweredOff
[AUTO-CONNECT] Failed to connect: ...
[MONITORING ERROR] ...
```

---

## Expected Data Format

The ESP32 should send data like:
- `Count:0,State:IDLE`
- `Count:1,State:DOWN`
- `Count:2,State:UP`
- `Count:3,State:DOWN`
- etc.

The app parses this and displays:
- Large rep count number (e.g., "5")
- Colored state indicator:
  - UP = Green
  - DOWN = Blue
  - IDLE = Gray

---

## Known Limitations

1. **Single Device Only**: App only connects to one device at a time
2. **Exact Name Match**: Device MUST be named "ESP32_IMU_Stream" exactly
3. **No Manual Control**: Users cannot manually trigger scan or disconnect
4. **Service UUID Required**: Device must advertise the correct service UUID

---

## Troubleshooting

**Problem**: Device not found even though it's on
**Solution**: 
- Verify device name is exactly "ESP32_IMU_Stream"
- Check device is advertising (not just powered on)
- Ensure BLE is enabled on phone
- Check device is in range (< 10 meters typically)

**Problem**: Connection fails repeatedly
**Solution**:
- Verify service UUID matches: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Check characteristic supports notifications
- Restart both phone and ESP32
- Check ESP32 logs for connection errors

**Problem**: No data displayed after connection
**Solution**:
- Verify ESP32 is sending data in correct format
- Check characteristic has notifications enabled
- Monitor console logs for parsing errors
- Verify data is being sent frequently enough

---

## Success Criteria

The feature is working correctly if:
- ✓ App launches and starts scanning automatically
- ✓ Finds and connects to ESP32_IMU_Stream without user input
- ✓ Displays rep counter data in real-time
- ✓ Automatically reconnects if connection is lost
- ✓ Handles errors gracefully without crashing
- ✓ Works consistently across multiple launches
- ✓ Provides clear status messages to user
- ✓ Requires zero user interaction for normal operation
