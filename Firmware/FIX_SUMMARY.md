# Fix Summary: Rep Detection After Long Sleep

## Issue
After waking from a long deep sleep (multiple minutes), the device would connect via BLE but rep detection would fail - the rep count would stay at 0. Pressing the reset button would fix it temporarily.

## Root Cause
The MPU-6050 sensor initialization sequence was incorrect when waking from deep sleep:

1. Device enters deep sleep with MPU in low-power mode:
   - Motion detection interrupt enabled
   - Gyroscope disabled (standby mode)
   - Temperature sensor disabled
   - Cycle mode configured for motion detection

2. Device wakes from motion interrupt

3. **Original buggy sequence**:
   ```
   mpu.initialize()              // Called while MPU still in low-power state
   mpu.setFullScaleAccelRange()  // Set ranges while MPU partially configured
   mpu.setFullScaleGyroRange()   // Set ranges while MPU partially configured
   wakeMPUFromSleep()            // Try to restore normal operation (too late)
   ```

4. Result: MPU in inconsistent state, sensor readings fail, rep detection doesn't work

## Solution
Reordered the initialization sequence to restore normal operation BEFORE calling `mpu.initialize()`:

**Fixed sequence**:
```
if (waking from deep sleep):
    mpu.getIntStatus()           // Clear interrupt flag
    mpu.setIntMotionEnabled(false)  // Disable motion interrupt
    mpu.setWakeCycleEnabled(false)  // Disable cycle mode
    mpu.setSleepEnabled(false)      // Ensure device is awake
    Enable all sensors (gyro, accel, temp)
    delay(200)                      // Wait for stabilization

mpu.initialize()                 // Now initialize with MPU in normal state
mpu.setFullScaleAccelRange()    // Set ranges with MPU properly initialized
mpu.setFullScaleGyroRange()     // Set ranges with MPU properly initialized

// Additional cleanup for normal operation:
mpu.setIntEnabled(0x00)         // Disable all interrupts
mpu.setDHPFMode(MPU6050_DHPF_RESET)  // Reset high-pass filter
delay(10)
mpu.setDHPFMode(MPU6050_DHPF_HOLD)   // Hold mode (no filtering)
```

## Key Changes

### 1. Pre-initialization Wake-up (Lines 779-818)
Before calling `mpu.initialize()`, if waking from deep sleep:
- Clear motion interrupt status
- Disable motion detection interrupt
- Disable cycle and sleep modes
- Enable all sensors (gyroscope, accelerometer, temperature)
- Wait 200ms for stabilization

This ensures the MPU is in a known, normal operational state before initialization.

### 2. Post-initialization Cleanup (Lines 834-844)
After initialization and range configuration:
- Explicitly disable all interrupts
- Reset DHPF (Digital High-Pass Filter)
- Set DHPF to HOLD mode for normal operation

This ensures clean sensor readings without high-pass filtering interference.

### 3. Removed Redundant Wake Call
The original `wakeMPUFromSleep()` function call was removed from the post-initialization phase since wake-up is now done pre-initialization.

## Technical Details

### MPU-6050 States
- **Normal Operation**: All sensors enabled, no interrupts, standard sampling
- **Low Power (Sleep Mode)**: Motion interrupt enabled, gyro disabled, cycle mode
- **Inconsistent State (Bug)**: Partial initialization while in low-power mode

### Critical Timing
- 200ms stabilization delay after wake-up is critical
- 10ms delay between DHPF reset and HOLD mode is necessary
- These delays ensure register writes complete and sensors stabilize

### Register Configuration
| Register | Normal Operation | Sleep Mode | After Wake (Fixed) |
|----------|-----------------|------------|-------------------|
| INT_ENABLE | 0x00 | 0x40 (motion) | 0x00 |
| PWR_MGMT_1 | 0x00 | 0x08 (temp off) | 0x00 |
| PWR_MGMT_2 | 0x00 | 0x07 (gyro off) | 0x00 |
| MOT_THR | N/A | 32 (64mg) | N/A |
| DHPF | 0x07 (HOLD) | 0x01 (5Hz) | 0x07 (HOLD) |

## Testing
See `TESTING_FIX.md` for comprehensive testing procedures covering:
1. Normal operation (baseline)
2. Short sleep (20 seconds)
3. Long sleep (5+ minutes) - **Critical test**
4. BLE connection after wake
5. Multiple sleep/wake cycles

## Benefits
1. ✅ Rep detection works immediately after short sleep
2. ✅ Rep detection works immediately after long sleep (previously broken)
3. ✅ Consistent behavior across all sleep durations
4. ✅ No manual reset required
5. ✅ Proper sensor initialization guaranteed

## Files Modified
- `Firmware/src/esp1/main.cpp` - Fixed initialization sequence (59 lines changed)
- `Firmware/TESTING_FIX.md` - New comprehensive testing guide (183 lines)
- `Firmware/FIX_SUMMARY.md` - This summary document

## Related Documentation
- `Firmware/POWER_MANAGEMENT.md` - Deep sleep configuration
- `Firmware/WAKE_FROM_SLEEP_FIX.md` - Previous sleep/wake fixes
- `Firmware/REP_DETECTION.md` - Rep detection algorithm
