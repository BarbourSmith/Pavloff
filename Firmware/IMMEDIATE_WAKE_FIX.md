# ESP32 Immediate Wake from Sleep Fix

## Problem Statement
The ESP32 was entering deep sleep correctly, but waking immediately even when the board had not moved. This prevented the device from achieving proper low-power sleep mode.

## Root Cause Analysis

### Issue 1: Premature SLEEP Mode Entry
The MPU-6050 was being put into SLEEP mode (PWR_MGMT_1 = 0x48) immediately after configuring motion detection in the `putMPUToSleep()` function. When transitioning to SLEEP mode, transient sensor readings could trigger the motion detection interrupt immediately, causing the ESP32 to wake up right after entering sleep.

### Issue 2: Aggressive Interrupt Clearing Loop
The original code had an aggressive interrupt clearing loop (lines 648-671) that repeatedly read the MPU-6050's INT_STATUS register trying to clear all interrupt flags. This approach had several problems:

1. Reading MPU registers can trigger new DATA_RDY interrupts
2. The loop could prevent the interrupt status from stabilizing
3. Multiple register reads increased the chance of spurious interrupts
4. The abort-on-LOW-pin logic could prevent legitimate sleep attempts

## Solution Implemented

### 1. Delayed SLEEP Mode Entry
**Before:**
```cpp
void putMPUToSleep() {
  // ... configure motion detection ...
  configureMPUMotionInterrupt();
  
  // Put MPU into SLEEP mode immediately
  mpu.writeMPU6050(MPU6050_PWR_MGMT_1, 0x48);
}
```

**After:**
```cpp
void putMPUToSleep() {
  // ... configure motion detection ...
  configureMPUMotionInterrupt();
  
  // Do NOT enter SLEEP mode here
  // Let sensor stabilize in normal mode
}

void enterDeepSleep() {
  putMPUToSleep();  // Configure motion detection
  
  delay(1000);  // CRITICAL: 1 second stabilization delay
  
  // Clear interrupts after stabilization
  mpu.readMPU6050(MPU6050_INT_STATUS);
  
  delay(100);
  
  // NOW enter SLEEP mode after sensor is stable
  mpu.writeMPU6050(MPU6050_PWR_MGMT_1, 0x48);
  
  delay(50);
  
  // Final interrupt clear
  mpu.readMPU6050(MPU6050_INT_STATUS);
}
```

### 2. Simplified Interrupt Handling
**Before:**
- Aggressive loop trying to clear INT_STATUS to 0x00
- Multiple INT pin state checks
- Abort sleep if INT pin is LOW
- Could make up to 20 clearing attempts

**After:**
- Single interrupt clear after stabilization delay
- No repeated register reads
- No INT pin state checks
- Trust the stabilization delay to prevent spurious interrupts

### 3. Reduced Register Access
Minimized MPU register reads before sleep to avoid triggering DATA_RDY interrupts:
- Removed diagnostic register reads (MOT_THR, MOT_DUR, INT_ENABLE)
- Removed repeated INT_STATUS reads in clearing loop
- Single clear operation after stabilization
- Single clear operation after entering SLEEP mode

## Key Changes

### Modified `putMPUToSleep()` (Lines 494-527)
- Removed SLEEP mode entry (lines 525-537 in old code)
- Motion detection is configured while sensor remains in normal mode
- Added comment clarifying SLEEP mode will be entered later

### Modified `enterDeepSleep()` (Lines 614-676)
- Added 1 second stabilization delay after calling `putMPUToSleep()`
- Moved SLEEP mode entry to this function, after stabilization
- Removed aggressive interrupt clearing loop (48 lines reduced to 8 lines)
- Removed multiple INT pin checks
- Removed abort-on-LOW-pin logic
- Simplified to two strategic interrupt clears: one after stabilization, one after SLEEP mode entry

## Technical Details

### Why 1 Second Stabilization?
The 1 second delay allows:
1. Motion detection configuration to fully settle
2. Any transient readings from power mode changes to dissipate
3. Sensor to reach a stable baseline state
4. Motion detection thresholds to be established without false triggers

### Why Remove Aggressive Clearing?
1. Reading INT_STATUS can trigger new DATA_RDY interrupts if accelerometer is active
2. Loop could never clear INT_STATUS if accelerometer keeps generating data
3. Multiple reads increase chance of race conditions
4. The INT pin state is what matters for wake-up, not the INT_STATUS register value
5. SLEEP mode stops continuous data generation, so single clear after SLEEP is effective

### Power Mode Sequence
1. **Configure motion detection** (sensor in normal mode)
2. **Wait 1 second** for stabilization
3. **Clear interrupts** from stabilization period
4. **Enter SLEEP mode** to stop continuous sensor readings
5. **Final interrupt clear** to ensure clean state
6. **Configure ESP32 wake source**
7. **Enter deep sleep**

## Testing Instructions

### Test Normal Sleep Entry
1. Upload firmware to ESP32
2. Monitor serial output at 115200 baud
3. Keep device stationary for 20 seconds (testing configuration)
4. At 15 seconds, you'll see: "WARNING: Device will enter sleep in 5 seconds if no activity detected"
5. At 20 seconds, observe:
   ```
   =====================================
   ENTERING DEEP SLEEP MODE
   Device will wake on motion detection
   Current uptime: XX seconds
   =====================================
   Preparing MPU-6050 for sleep mode...
     - Set to normal mode with temp disabled
     - Disabled gyroscope, kept accelerometer enabled
     - Waited for sensor to stabilize after power changes
     - Cleared interrupts from power mode transition
   MPU-6050 motion detection configured and ready
   (SLEEP mode will be entered after stabilization delay in enterDeepSleep())
   Waiting for MPU-6050 to fully stabilize (1 second)...
   Cleared interrupt status after stabilization
   MPU-6050 entered SLEEP mode (motion detection remains active)
   Final interrupt clear completed
   BLE and WiFi shut down
   Wake-up source configured on GPIO18
   Entering deep sleep NOW...
   ```
6. Serial output will stop (device is asleep)
7. **Wait at least 5 seconds without moving the device**
8. Device should remain asleep (no immediate wake-up)

### Test Wake from Sleep
1. After device has been asleep for at least 5 seconds
2. Move or shake the device
3. Observe serial output resumes with:
   ```
   =====================================
   WOKE UP FROM DEEP SLEEP
   Reason: EXT0 (GPIO interrupt)
   Resuming normal operation...
   =====================================
   Reading MPU interrupt status after wake...
   INT_STATUS register: 0xXX
     - Motion interrupt flag is SET
   GPIO18 state on wake: LOW
   Waking MPU-6050 from low power mode...
     - Cleared motion interrupt status
     - Set to normal mode (PWR_MGMT_1 = 0x00)
     - Enabled all sensors (PWR_MGMT_2 = 0x00)
     - Disabled motion interrupt (INT_ENABLE = 0x00)
   MPU-6050 woken up and ready for normal operation
   MPU-6050 initialized
   ```
4. Device returns to normal operation
5. Rep detection should work immediately

### Expected Behavior
- ✅ Device enters sleep after 20 seconds of inactivity
- ✅ Device stays asleep (no immediate wake-up)
- ✅ Device wakes on intentional movement
- ✅ Rep detection works after wake-up
- ✅ Can enter sleep again after wake-up

## Production Configuration

For production deployment, change the idle timeout back to 5 minutes:

```cpp
#define IDLE_TIMEOUT_MS 300000  // 5 minutes in milliseconds
```

The current 20-second timeout is only for easier testing.

## Files Modified
- `Firmware/src/esp1/main.cpp`:
  - Line 525-526: Updated comment in `putMPUToSleep()`
  - Lines 494-527: Removed SLEEP mode entry from `putMPUToSleep()`
  - Lines 614-676: Complete rewrite of sleep preparation in `enterDeepSleep()`
  - Net change: -76 lines of code (simplified from 139 lines to 63 lines)

## Verification Checklist

- [x] Firmware compiles without errors
- [x] Code review completed and feedback addressed
- [x] Changes are minimal and focused on the issue
- [x] Comments are clear and accurate
- [x] Sleep timeout is 20 seconds for testing
- [ ] Physical device testing confirms no immediate wake-up
- [ ] Physical device testing confirms wake on motion works
- [ ] Physical device testing confirms rep detection works after wake
- [ ] Sleep current consumption verified (~50 μA)

## Related Issues
- Original wake-from-sleep fix (rep detection after wake): See `WAKE_FROM_SLEEP_FIX.md`
- Power management documentation: See `POWER_MANAGEMENT.md`

## Summary

This fix addresses the immediate wake-up issue by ensuring the MPU-6050 sensor has adequate time to stabilize after motion detection configuration before entering SLEEP mode. The 1-second stabilization delay prevents transient sensor readings from triggering spurious wake-ups. The simplified interrupt handling reduces unnecessary register reads that could cause new interrupts.

The result is a reliable sleep/wake cycle where the device:
1. Enters sleep correctly after idle timeout
2. Stays asleep until intentional movement
3. Wakes reliably on motion
4. Resumes normal operation with working rep detection
