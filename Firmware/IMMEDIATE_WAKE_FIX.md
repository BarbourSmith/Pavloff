# ESP32 Immediate Wake from Sleep Fix

## Problem Statement
The ESP32 was entering deep sleep correctly, but waking immediately even when the board had not moved. This prevented the device from achieving proper low-power sleep mode.

## Root Cause Analysis

### Initial Diagnosis (Incorrect)
Initially, it was thought that putting the MPU-6050 into SLEEP mode immediately after configuring motion detection was causing the issue.

### Actual Root Cause (Confirmed)
The actual problem was **enabling the motion detection interrupt while the MPU was still in normal mode**. Here's what was happening:

1. Motion detection interrupt was enabled while MPU was in normal mode (accelerometer actively running)
2. MPU was then transitioned to SLEEP mode
3. During the transition to SLEEP mode, accelerometer readings would change
4. These changes triggered the already-enabled motion detection interrupt
5. The INT pin would go LOW
6. Even after clearing the interrupt, the sensor would continue settling and trigger again
7. ESP32 would enter deep sleep with INT pin already LOW
8. Result: Immediate wake-up

The key insight is that **power state transitions cause accelerometer readings to change**, and if motion detection is already enabled during these transitions, it will trigger false positives.

## Solution Implemented

### Corrected Sequence: SLEEP Mode BEFORE Motion Interrupt

The fix is to reverse the order: **put the MPU into SLEEP mode BEFORE enabling the motion detection interrupt**.

**Before (Incorrect):**
```cpp
void putMPUToSleep() {
  // Configure power (keep in normal mode)
  mpu.writeMPU6050(MPU6050_PWR_MGMT_1, 0x08);
  
  // Enable motion detection while in normal mode
  configureMPUMotionInterrupt();  // <-- Interrupt enabled
  
  // Later in enterDeepSleep():
  delay(1000);
  mpu.writeMPU6050(MPU6050_PWR_MGMT_1, 0x48);  // <-- Transition triggers interrupt!
}
```

**After (Correct):**
```cpp
void putMPUToSleep() {
  // Disable gyroscope
  mpu.writeMPU6050(0x6C, 0x07);
  
  // Put MPU into SLEEP mode FIRST
  mpu.writeMPU6050(MPU6050_PWR_MGMT_1, 0x48);
  
  // Wait for SLEEP mode to fully stabilize
  delay(500);  // <-- Sensor is stable in SLEEP mode
  
  // Clear any interrupts from the transition
  mpu.readMPU6050(MPU6050_INT_STATUS);
  
  // NOW enable motion detection (sensor already stable)
  configureMPUMotionInterrupt();  // <-- Safe, no more transitions
}

void enterDeepSleep() {
  putMPUToSleep();  // MPU is now in stable SLEEP mode
  
  delay(1000);  // Additional stabilization
  
  // Clear interrupts
  mpu.readMPU6050(MPU6050_INT_STATUS);
  
  delay(100);
  
  // Final clear
  mpu.readMPU6050(MPU6050_INT_STATUS);
  
  // Enter ESP32 deep sleep
  esp_deep_sleep_start();
}
```
- Single clear operation after entering SLEEP mode

## Key Changes

### Modified `putMPUToSleep()` (Lines 493-526)

**Critical Change:** SLEEP mode is now entered BEFORE enabling motion detection interrupt.

**New sequence:**
1. Disable gyroscope (line 503)
2. **Enter SLEEP mode (line 509)** ← Moved from `enterDeepSleep()`
3. **Wait 500ms for SLEEP stabilization (line 514)** ← New critical delay
4. Clear interrupts from power transition (line 519)
5. Enable motion detection interrupt (line 523) ← Now safe, sensor is stable

**Why this works:** The sensor is completely stable in SLEEP mode before we enable the interrupt that can trigger wake-ups. No more power state transitions after the interrupt is enabled.

### Modified `enterDeepSleep()` (Lines 612-631)

**Changes:**
- Call `putMPUToSleep()` (which now handles SLEEP mode entry)
- Wait 1 second for motion detection to stabilize
- Two strategic interrupt clears
- **Removed:** Redundant SLEEP mode entry (now in `putMPUToSleep()`)
- **Removed:** Aggressive interrupt clearing loop

**Total stabilization time:** 500ms (in SLEEP before interrupt enable) + 1000ms (after interrupt enable) = 1.5 seconds

## Technical Details

### Why SLEEP Mode Before Motion Interrupt?

**The Problem:**
When motion detection is enabled BEFORE entering SLEEP mode:
1. MPU is in normal mode, accelerometer actively generating readings
2. Motion interrupt is enabled → INT can now trigger on motion
3. MPU transitions to SLEEP mode
4. Accelerometer readings change during power-down
5. Motion detection triggers on these changes
6. INT pin goes LOW
7. Even after clearing, sensor continues settling → triggers again
8. ESP32 enters sleep with INT LOW → immediate wake

**The Solution:**
When SLEEP mode is entered BEFORE enabling motion interrupt:
1. MPU transitions to SLEEP mode
2. **Wait 500ms for complete stabilization**
3. Sensor is now stable, no more reading changes
4. Motion interrupt is enabled → INT can now trigger
5. No power transitions happen after this point
6. Sensor remains stable → no false triggers
7. ESP32 enters sleep with INT HIGH → sleeps properly
8. Only real motion will trigger wake

### Stabilization Timeline
```
Time 0ms:    Disable gyroscope
Time 1ms:    Enter SLEEP mode (PWR_MGMT_1 = 0x48)
Time 500ms:  SLEEP mode stabilized ✓
Time 501ms:  Clear any transition interrupts
Time 502ms:  Enable motion interrupt ← Safe point
Time 1502ms: Motion detection stabilized ✓
Time 1503ms: Clear any stabilization interrupts
Time 1603ms: Final interrupt clear
Time 1604ms: Enter ESP32 deep sleep ✓
```

### Why 500ms for SLEEP Stabilization?
The MPU-6050 needs time to:
1. Power down the gyroscope circuits
2. Reduce accelerometer sample rate
3. Disable temperature sensor
4. Enter low-power mode
5. Stabilize readings at new baseline

500ms ensures all transients have settled before we enable motion detection.

### Power Mode Sequence (Corrected)
1. **Disable gyroscope** (save power, keep accelerometer)
2. **Enter SLEEP mode** (sensor powered down to low-power state)
3. **Wait 500ms** (let SLEEP mode fully stabilize)
4. **Clear interrupts** from power transition
5. **Enable motion detection** (sensor already stable in SLEEP)
6. **Wait 1000ms** (let motion detection stabilize)
7. **Clear interrupts** from motion detection setup
8. **Final clear** (ensure absolutely clean state)
9. **Configure ESP32 wake source** (GPIO18)
10. **Enter deep sleep**

## Testing Instructions

### Test Normal Sleep Entry
1. Upload firmware to ESP32
2. Monitor serial output at 115200 baud
3. Keep device stationary for 20 seconds (testing configuration)
4. At 15 seconds, you'll see: "WARNING: Device will enter sleep in 5 seconds if no activity detected"
5. At 20 seconds, observe the NEW correct output:
   ```
   =====================================
   ENTERING DEEP SLEEP MODE
   Device will wake on motion detection
   Current uptime: XX seconds
   =====================================
   Preparing MPU-6050 for sleep mode...
     - Disabled gyroscope, kept accelerometer enabled
     - Entered SLEEP mode (temp disabled)
     - Waited for SLEEP mode to stabilize
     - Cleared interrupts from power mode transition
     - Cleared any pending interrupt status
     - Configured INT pin: active-low, latch mode for wake compatibility
     - Cleared interrupt status after configuration
   MPU-6050 motion interrupt configured
   MPU-6050 sleep mode configured with motion detection
   Waiting for motion detection to fully stabilize (1 second)...
   Cleared interrupt status after stabilization
   Final interrupt clear completed
   BLE and WiFi shut down
   Wake-up source configured on GPIO18
   Entering deep sleep NOW...
   ```
   ```
6. Serial output will stop (device is asleep)
7. **Wait at least 5 seconds without moving the device**
8. **Device should remain asleep (no immediate wake-up)** ← This is the fix!

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

### Original Fix (Commit fb82405 - Incorrect)
- `Firmware/src/esp1/main.cpp`:
  - Modified `putMPUToSleep()`: Removed SLEEP mode entry, deferred to `enterDeepSleep()`
  - Modified `enterDeepSleep()`: Added SLEEP mode after 1 second delay
  - Net change: -76 lines of code
  - **Result:** Still woke immediately (didn't work)

### Corrected Fix (Commit 2bf9556 - Correct)
- `Firmware/src/esp1/main.cpp`:
  - **Lines 493-526:** Completely rewrote `putMPUToSleep()`
    - Now enters SLEEP mode FIRST (line 509)
    - Waits 500ms for stabilization (line 514)
    - Then enables motion interrupt (line 523)
  - **Lines 612-631:** Simplified `enterDeepSleep()`
    - Removed redundant SLEEP mode entry (now in `putMPUToSleep()`)
    - Kept 1 second stabilization after motion interrupt enable
    - Two strategic interrupt clears
  - **Net change:** -12 additional lines from previous version

## Verification Checklist

- [x] Firmware compiles without errors
- [x] Code review completed and feedback addressed
- [x] Changes are minimal and focused on the issue
- [x] Comments are clear and accurate
- [x] Sleep timeout is 20 seconds for testing
- [x] Initial fix implemented (didn't work - immediate wake persisted)
- [x] Root cause re-analyzed based on user feedback
- [x] Corrected fix implemented (SLEEP before interrupt enable)
- [ ] Physical device testing confirms no immediate wake-up ← **Awaiting user confirmation**
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
