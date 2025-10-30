# Testing Fix for Rep Detection After Long Sleep

## Issue
Rep detection fails after waking from long sleep periods. Rep count stays at 0 even though device is connected via BLE.

## Fix Applied
Reordered MPU-6050 initialization sequence to restore from sleep mode BEFORE calling `mpu.initialize()`. This ensures the sensor is in a proper operational state when initialized.

## Testing Procedure

### Prerequisites
1. ESP32-S3 board with MPU-6050 sensor
2. PlatformIO installed
3. USB cable for serial monitoring

### Upload Firmware
```bash
cd /home/runner/work/Pavloff/Pavloff/Firmware
platformio run -e esp1 -t upload
```

### Test 1: Normal Operation (Baseline)
1. **Connect serial monitor**:
   ```bash
   platformio device monitor -b 115200
   ```

2. **Verify startup**:
   - Should see "DEVICE STARTING"
   - "MPU-6050 connection successful"
   - "MPU-6050 initialized and configured for normal operation"
   - "Using stored calibration offsets" (if device was calibrated before)

3. **Perform reps**:
   - Move device up and down repeatedly
   - Watch serial output for state changes:
     - IDLE → MOVING_UP → MOVING_DOWN → MOVING_UP
   - Verify rep count increments
   - Every 2 seconds, diagnostic output shows current state

4. **Expected output**:
   ```
   REP: Started - Moving UP
   REP: Direction change UP->DOWN | Total Reps: 1
   REP: Direction change DOWN->UP | Total Reps: 1
   REP: Direction change UP->DOWN | Total Reps: 2
   ...
   ```

### Test 2: Short Sleep (20 seconds)
1. **Let device go idle**:
   - Keep device still for 15 seconds
   - At 15 seconds: "WARNING: Device will enter sleep in 5 seconds"
   - At 20 seconds: "ENTERING DEEP SLEEP MODE"

2. **Wake device**:
   - Move or shake device
   - Should see:
     ```
     WOKE UP FROM DEEP SLEEP
     Reason: Motion detected (EXT1 GPIO interrupt)
     Restoring MPU-6050 from sleep mode before initialization...
       - Interrupt status on wake: 0xXX
       - Motion interrupt was triggered
       - Motion interrupt disabled
       - Wake cycle and sleep mode disabled
       - All sensors enabled
       - Temperature sensor enabled
     MPU-6050 pre-initialization complete
     MPU-6050 connection successful
     MPU-6050 initialized and configured for normal operation
     Using stored calibration offsets
     State variables reset
     ```

3. **Test rep detection**:
   - Perform reps immediately after wake
   - Verify rep count increments from 0
   - Watch for state transitions in diagnostic output

4. **Expected result**: ✅ Rep detection works correctly

### Test 3: Long Sleep (Multiple Minutes) - CRITICAL TEST
This is the test that previously failed.

1. **Trigger long sleep**:
   - Option A: Wait naturally (20+ seconds)
   - Option B: Temporarily modify code to extend timeout
   
2. **Wait for deep sleep entry**:
   - Device enters sleep after idle timeout
   - Serial output stops

3. **Wait extended period**:
   - Wait 5-10 minutes (or longer)
   - This simulates real-world scenario where device sits unused

4. **Wake device**:
   - Move or shake device vigorously
   - Should see same startup sequence as Test 2

5. **Test rep detection - CRITICAL**:
   - Immediately perform reps
   - Watch serial diagnostic output every 2 seconds
   - **VERIFY**: Rep count increments from 0
   - **VERIFY**: State transitions between IDLE/MOVING_UP/MOVING_DOWN
   - **VERIFY**: Position and velocity vectors change

6. **Expected result**: ✅ Rep detection works correctly after long sleep
   - This was previously broken, should now be fixed

### Test 4: BLE Connection After Long Sleep
1. **Setup**:
   - Use iOS app or BLE debugging tool
   - Subscribe to rep characteristic: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`

2. **Test sequence**:
   - Connect to device ("Pavloff Workout Sensor")
   - Perform reps and verify data transmission
   - Let device sleep (20+ seconds)
   - Wake device by movement
   - Wait for BLE reconnection (may take a few seconds)
   - Perform reps again

3. **Expected result**: ✅ Rep data transmitted correctly via BLE

### Test 5: Multiple Sleep/Wake Cycles
1. **Repeat cycle 5 times**:
   - Perform reps (verify working)
   - Let device sleep
   - Wake device
   - Immediately perform reps (verify working)

2. **Expected result**: ✅ Consistent behavior across all cycles

## Verification Checklist

- [ ] Test 1: Normal operation works (baseline)
- [ ] Test 2: Short sleep and wake works
- [ ] Test 3: Long sleep and wake works (CRITICAL - previously broken)
- [ ] Test 4: BLE connection after sleep works
- [ ] Test 5: Multiple cycles work consistently
- [ ] Serial diagnostics show correct state transitions
- [ ] Rep count increments properly after wake
- [ ] Position and velocity vectors update after wake
- [ ] No crashes or hangs observed

## Success Criteria

The fix is successful if:
1. ✅ Rep detection works immediately after waking from short sleep
2. ✅ Rep detection works immediately after waking from long sleep (5+ minutes)
3. ✅ State machine transitions correctly (IDLE → UP → DOWN → UP)
4. ✅ Rep count increments with each complete cycle
5. ✅ BLE data transmission works after wake
6. ✅ Behavior is consistent across multiple sleep/wake cycles
7. ✅ No error messages in serial output related to MPU initialization

## Failure Indicators

If the fix doesn't work, you'll see:
- ❌ Rep count stays at 0 after wake
- ❌ State stuck at IDLE despite movement
- ❌ "MPU-6050 connection failed" message
- ❌ Velocity vectors remain at 0 despite movement
- ❌ No state transitions in diagnostic output

## Additional Diagnostics

If problems persist, check:
1. **MPU-6050 connection**: Verify I2C wiring (GPIO 8=SDA, GPIO 9=SCL)
2. **Interrupt pin**: Verify GPIO 18 is connected to MPU INT pin
3. **Serial output**: Look for any error messages during wake sequence
4. **BLE**: Verify device advertises after wake ("Pavloff Workout Sensor")
5. **Calibration**: Ensure gyro offsets are loaded ("Using stored calibration offsets")

## Notes

- Current idle timeout is 20 seconds for testing
- For production, change `IDLE_TIMEOUT_MS` to 300000 (5 minutes)
- Diagnostic output appears every 2 seconds in main loop
- Rep count resets to 0 after each deep sleep (by design)
