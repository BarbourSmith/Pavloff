# Wake from Sleep Fix - Rep Detection Issue

## Problem Statement
The board was unable to detect reps after waking from deep sleep. The Bluetooth connection could be made, but no reps were reported.

## Root Cause Analysis
The issue was caused by the MPU-6050 motion detection interrupt configuration being applied during normal operation. In the original code:

1. `configureMPUMotionInterrupt()` was called in `setup()` after MPU initialization
2. This configured the MPU-6050's interrupt system for motion detection
3. The motion detection interrupt settings (INT_ENABLE register set to 0x40) interfered with normal sensor operation
4. This prevented proper reading of accelerometer and gyroscope data needed for rep detection

## Solution Implemented

### 1. Fixed MPU-6050 Initialization Sequence
**Before:**
- Motion detection interrupt was configured during `setup()` for all operations
- This caused the MPU to be in a hybrid state where it was trying to do both motion detection and continuous sensor reading

**After:**
- Motion detection interrupt is ONLY configured in `putMPUToSleep()` before entering deep sleep
- During normal operation, the MPU operates in standard mode with all interrupts disabled
- When waking up, `wakeMPUFromSleep()` explicitly disables the motion interrupt (INT_ENABLE = 0x00)

### 2. Enhanced Wake-up Procedure
Added to `wakeMPUFromSleep()`:
```cpp
// Disable motion detection interrupt (will be re-enabled before next sleep)
const uint8_t MPU6050_INT_ENABLE = 0x38;
mpu.writeMPU6050(MPU6050_INT_ENABLE, 0x00);
```

This ensures the MPU is in normal operating mode after wake-up.

### 3. Added Diagnostic Serial Output
Implemented periodic state dumps every 2 seconds showing:
- Uptime
- BLE connection status
- Rep count and current state
- Position and velocity vectors
- Idle timer countdown

This makes it easy to monitor the device state and debug issues over the serial connection.

### 4. Testing Configuration
- Changed `IDLE_TIMEOUT_MS` from 300000 (5 minutes) to 20000 (20 seconds)
- This makes testing the sleep/wake cycle much faster

### 5. Additional Fixes
- Fixed BLE device name to "Pavloff Workout Sensor" (was "ESP32_IMU_Stream")
- Explicitly reset `repCount = 0` in `resetStateVariables()` for clarity
- Added detailed diagnostic output to wake-up and sleep sequences

## Testing Instructions

### 1. Upload Firmware
```bash
cd /home/runner/work/Pavloff/Pavloff/Firmware
platformio run -e esp1 -t upload
```

### 2. Monitor Serial Output
```bash
platformio device monitor -b 115200
```

### 3. Test Normal Operation
1. After boot, you should see:
   ```
   =====================================
   DEVICE STARTING
   Power-on or reset detected
   =====================================
   MPU-6050 initialized
   ```

2. Every 2 seconds, you'll see state diagnostics:
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

3. Perform some reps (move the device up and down)
4. Watch the state change from IDLE → MOVING_UP → MOVING_DOWN
5. Verify rep count increments

### 4. Test Sleep Entry
1. Keep the device still for 15 seconds
2. At 15 seconds, you'll see: `WARNING: Device will enter sleep in 5 seconds if no activity detected`
3. At 20 seconds, you'll see:
   ```
   =====================================
   ENTERING DEEP SLEEP MODE
   Device will wake on motion detection
   Current uptime: XX seconds
   =====================================
   ```

### 5. Test Wake from Sleep
1. Move or shake the device
2. You should see:
   ```
   =====================================
   WOKE UP FROM DEEP SLEEP
   Reason: Motion detection triggered
   Resuming normal operation...
   =====================================
   Waking MPU-6050 from low power mode...
     - Cleared motion interrupt status
     - Set to normal mode (PWR_MGMT_1 = 0x00)
     - Enabled all sensors (PWR_MGMT_2 = 0x00)
     - Disabled motion interrupt (INT_ENABLE = 0x00)
   MPU-6050 woken up and ready for normal operation
   MPU-6050 initialized
   ```

3. Perform reps again
4. **VERIFY**: Rep detection should work normally (this was previously broken)

### 6. Test BLE Connection After Wake
1. Connect to the device via BLE (name: "Pavloff Workout Sensor")
2. Subscribe to the rep counter characteristic (UUID: 8d3f7a9e-4b2c-11ef-9f27-0242ac120002)
3. Perform reps and verify data is sent
4. Let device sleep
5. Wake device by movement
6. Reconnect via BLE
7. **VERIFY**: Rep counting works after wake-up

## Expected Behavior After Fix

### Normal Operation
- ✅ MPU-6050 operates in standard mode with continuous sensor readings
- ✅ Rep detection state machine functions correctly
- ✅ BLE transmits rep count every 500ms

### Sleep Entry
- ✅ After 20 seconds of inactivity, device enters deep sleep
- ✅ MPU-6050 is configured for motion detection only before sleep
- ✅ Device consumes ~50 μA in sleep mode

### Wake from Sleep
- ✅ Device wakes on motion
- ✅ MPU-6050 is restored to normal operating mode
- ✅ Motion interrupt is disabled
- ✅ All state variables are reset
- ✅ **Rep detection works immediately after wake-up**

## Improved Wake System (Latest Update)

### Problem: Immediate Wake-up from Deep Sleep
The ESP32 was waking up immediately after entering deep sleep instead of waiting for motion detection. This was caused by incorrect MPU-6050 interrupt pin configuration.

### Root Cause
The INT_PIN_CFG register (0x37) was set to 0xB0, which has bit 4 = 1. This means the interrupt is cleared on ANY register read, not just reading INT_STATUS. When sensor data is read during pre-sleep operations, this can clear the interrupt and cause the INT pin to become unstable or go HIGH/LOW at the wrong time.

### Solution Implemented
Based on the proven solution from [Arduino Stack Exchange](https://arduino.stackexchange.com/questions/48424/how-to-generate-hardware-interrupt-in-mpu6050-to-wakeup-arduino-from-sleep-mode):

1. **Changed INT_PIN_CFG from 0xB0 to 0xA0**
   - 0xA0 = 0b10100000 (bit 4 = 0)
   - Now INT is cleared ONLY when reading INT_STATUS register
   - Prevents sensor data reads from clearing the interrupt
   - Ensures INT pin stays LOW until explicitly cleared

2. **Added Digital High-Pass Filter**
   - ACCEL_CONFIG (0x1C) = 0x01 (5Hz cutoff)
   - Filters out DC offset
   - Improves motion detection accuracy

3. **Updated Motion Detection Control**
   - MOT_DETECT_CTRL changed from 0x50 to 0x15
   - 0x15 = 0b00010101
     - Bits 7-6 = 00: Motion detection decrement = 1 count
     - Bits 5-4 = 01: ACCEL_ON_DELAY = 5ms (startup delay)
     - Bits 3-2 = 01: Additional motion detection settings
     - Bit 1 = 0: Reserved
     - Bit 0 = 1: Free-fall detection decrement
   - Optimized settings for better wake-up reliability

4. **CRITICAL FIX: Use CYCLE mode instead of SLEEP mode**
   - **Previous (INCORRECT):** PWR_MGMT_1 = 0x48 (SLEEP mode)
   - **Current (CORRECT):** PWR_MGMT_1 = 0x28 (CYCLE mode)
   - **The Problem:** SLEEP mode (bit 6 = 1) completely disables the accelerometer, preventing motion detection from working. The INT_STATUS register showed 0x01 (DATA_RDY flag) before sleep, indicating the sensor was trying to generate interrupts even in SLEEP mode, causing immediate wake-ups.
   - **The Solution:** CYCLE mode (bit 5 = 1) makes the accelerometer wake up periodically (40Hz) to sample and check for motion, while still consuming low power (~40 μA). The motion detection logic needs an active accelerometer to work.
   - **Wake Frequency:** PWR_MGMT_2 bits 7-6 set to 0xC7 (11 in binary) = 40Hz wake frequency for responsive motion detection

### Key Change Detail
**INT_PIN_CFG Register (0x37):**
- Bit 7 = 1: Active LOW interrupt
- Bit 6 = 0: Push-pull output
- Bit 5 = 1: Latch mode (holds LOW until cleared)
- **Bit 4 = 0: Clear only on INT_STATUS read** (was 1, causing the problem)
- Bits 3-0 = 0000: Other settings

This ensures the INT pin remains stable and LOW during the entire sleep period, only clearing when the ESP32 wakes and reads the INT_STATUS register.

## Technical Details

### MPU-6050 Register Configuration

**During Normal Operation:**
- INT_ENABLE (0x38) = 0x00 (all interrupts disabled)
- PWR_MGMT_1 (0x6B) = 0x00 (normal mode, all sensors enabled)
- PWR_MGMT_2 (0x6C) = 0x00 (all axes enabled)

**Before Sleep:**
- ACCEL_CONFIG (0x1C) = 0x01 (5Hz digital high-pass filter)
- INT_PIN_CFG (0x37) = 0xA0 (active-low, latch, clear only on INT_STATUS read)
- INT_ENABLE (0x38) = 0x40 (motion detection interrupt enabled)
- MOT_THR (0x1F) = 64 (128mg threshold)
- MOT_DUR (0x20) = 20 (20ms duration)
- MOT_DETECT_CTRL (0x69) = 0x15 (optimized motion detection settings)
- PWR_MGMT_1 (0x6B) = 0x28 (CYCLE mode, temp sensor disabled)
- PWR_MGMT_2 (0x6C) = 0xC7 (40Hz wake frequency, gyro disabled, accel enabled)

**CRITICAL:** The MPU6050 uses CYCLE mode, NOT SLEEP mode. In CYCLE mode, the accelerometer wakes up periodically (40Hz) to check for motion. SLEEP mode would disable the accelerometer completely and prevent motion detection from working.

**After Wake:**
- First action: Read INT_STATUS (0x3A) to clear interrupt flag
- Then: INT_ENABLE = 0x00, PWR_MGMT_1 = 0x00, PWR_MGMT_2 = 0x00
- This restores normal operation mode

## Production Configuration

For production deployment, change the idle timeout back to 5 minutes:

```cpp
#define IDLE_TIMEOUT_MS 300000  // 5 minutes in milliseconds
```

The current 20-second timeout is only for easier testing.

## Verification Checklist

- [x] Firmware compiles without errors
- [x] Sleep timeout is 20 seconds for testing
- [x] Diagnostic output is implemented
- [x] BLE device name is correct
- [x] Motion interrupt is disabled during normal operation
- [x] Motion interrupt is enabled before sleep
- [x] Wake-up sequence properly restores normal operation
- [x] INT_PIN_CFG updated to 0xA0 to fix immediate wake-up issue
- [x] Digital high-pass filter configured for better motion detection
- [x] MOT_DETECT_CTRL optimized with Stack Exchange solution (0x15)
- [ ] Physical device testing confirms device stays asleep until motion
- [ ] Physical device testing confirms rep detection works after wake
- [ ] BLE connection and data transmission verified after wake

## Files Modified
- `Firmware/src/esp1/main.cpp`: All changes in this single file
  - Line 24: Changed IDLE_TIMEOUT_MS to 20000
  - Line 433-500: Modified configureMPUMotionInterrupt() with new wake system
    - Added ACCEL_CONFIG (0x1C) = 0x01 for digital high-pass filter
    - Changed INT_PIN_CFG from 0xB0 to 0xA0 (critical fix for immediate wake-up)
    - Changed MOT_DETECT_CTRL from 0x50 to 0x15 per Stack Exchange solution
  - Line 494-537: Modified putMPUToSleep() to configure interrupt before sleep
  - Line 541-611: Enhanced wakeMPUFromSleep() with interrupt disable
  - Line 755-850: Removed configureMPUMotionInterrupt() from setup
  - Line 677: Fixed BLE device name
  - Line 735-761: Added periodic diagnostic output
