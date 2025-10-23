# Quick Reference: Testing Rep Detection After Wake

## Quick Test Procedure

### 1. Upload Firmware
```bash
cd /home/runner/work/Pavloff/Pavloff/Firmware
platformio run -e esp1 -t upload
```

### 2. Monitor Serial Output
```bash
platformio device monitor -b 115200
```

### 3. Test Sequence

**Phase 1: Normal Operation (First 20 seconds)**
- Move the device up and down
- Watch for "REP: Direction change" messages
- Verify rep count increments
- Observe state changes in diagnostic output

**Phase 2: Sleep Entry (At 15 seconds)**
- Keep device still
- Watch for "WARNING: Device will enter sleep in 5 seconds"
- At 20 seconds, see "ENTERING DEEP SLEEP MODE"

**Phase 3: Wake from Sleep**
- Move or shake the device
- Watch for "WOKE UP FROM DEEP SLEEP"
- Verify "MPU-6050 woken up and ready for normal operation"

**Phase 4: Test Rep Detection After Wake** ⭐
- Move device up and down again
- **VERIFY**: Reps are now counted (this was broken before)
- Check diagnostic output shows rep count incrementing
- Confirm BLE can connect and receive rep data

## Expected Results

✅ Reps counted during normal operation  
✅ Device sleeps after 20 seconds of inactivity  
✅ Device wakes on motion  
✅ **Reps counted immediately after wake** (KEY FIX)  
✅ BLE name is "Pavloff Workout Sensor"  
✅ Diagnostic output appears every 2 seconds  

## Diagnostic Output to Watch For

Every 2 seconds you'll see:
```
======== STATE DIAGNOSTIC ========
Uptime: X seconds
BLE Connected: YES/NO
Rep Count: X | State: IDLE/MOVING_UP/MOVING_DOWN
Position (m): X=..., Y=..., Z=...
Velocity (m/s): X=..., Y=..., Z=...
Idle timer: X / 20 seconds
==================================
```

## Key Indicators of Success

1. **During Movement**: State changes from IDLE → MOVING_UP → MOVING_DOWN
2. **Rep Count**: Increments when direction changes
3. **After Wake**: Same as #1 and #2 above
4. **Velocity**: Shows > 0.20 m/s during active movement
5. **Idle Timer**: Resets to 0 when moving

## Troubleshooting

**No reps counted?**
- Check velocity magnitude in diagnostics
- Ensure sustained motion (>500ms per phase)
- Verify state changes from IDLE

**Device won't wake?**
- Try more vigorous motion
- Check GPIO 18 connection to MPU INT pin
- Verify motion interrupt messages before sleep

**BLE not connecting?**
- Verify device name is "Pavloff Workout Sensor"
- Check "Device connected" message appears
- Ensure BLE characteristic UUID is correct

## For Production

Before deploying to production, change in `main.cpp` line 24:
```cpp
#define IDLE_TIMEOUT_MS 300000  // Change back to 5 minutes
```

## Documentation

- `WAKE_FROM_SLEEP_FIX.md` - Complete technical details
- `SERIAL_OUTPUT_EXAMPLES.md` - Example outputs for all scenarios
- `POWER_MANAGEMENT.md` - Power management details
- `README.md` - General firmware overview
