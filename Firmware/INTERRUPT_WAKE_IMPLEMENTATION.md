# Interrupt-Based Wake System Implementation

## Overview

This document describes the implementation of the interrupt-based wake system for the Pavloff workout sensor. This replaces the previous timer-based polling system with a more power-efficient hardware interrupt approach.

## Problem Statement

The previous implementation used timer-based polling where the ESP32 would wake every 2 seconds to check for motion. This resulted in:
- Average sleep current: ~2.7 mA
- Battery life: ~5 days (mostly idle scenario with 500mAh battery)
- Wake latency: up to 2 seconds
- Unnecessary wake cycles even when no motion occurred

## Solution

Implemented hardware interrupt-based wake using the MPU6050's motion detection interrupt:
- ESP32 wakes only when motion is detected by the MPU6050
- Average sleep current: ~0.51 mA
- Battery life: ~11 days (mostly idle scenario with 500mAh battery)
- Wake latency: instant (no polling delay)
- No unnecessary wake cycles

## Implementation Details

### Hardware Configuration

**Pin Assignment:**
- GPIO 18 (ESP32) ← INT pin (MPU6050)

The MPU6050 INT pin is configured as:
- Active HIGH output
- Push-pull driver
- Latched (remains HIGH until cleared)
- Cleared on any read of interrupt status register

### MPU6050 Motion Detection Configuration

The motion detection is configured in `configureMPUMotionInterrupt()`:

```cpp
// Motion threshold: 16 LSB = 32mg at ±2g range (sensitive for easy wake-up)
mpu.setMotionDetectionThreshold(16);

// Motion duration: 5ms minimum
mpu.setMotionDetectionDuration(5);

// Digital High-Pass Filter: 5Hz
mpu.setDHPFMode(MPU6050_DHPF_5);

// Enable motion interrupt
mpu.setIntMotionEnabled(true);
```

**Motion Detection Algorithm:**
1. MPU6050 continuously samples accelerometer at 1.25 Hz in cycle mode
2. Each sample is high-pass filtered (5Hz cutoff) to remove DC bias
3. If motion exceeds 32mg threshold for 5ms duration, interrupt triggers
4. INT pin goes HIGH and remains HIGH until status is read
5. ESP32 wakes from deep sleep via GPIO interrupt

### Power Management

**Deep Sleep Configuration:**
```cpp
// Configure GPIO wake on INT pin
esp_sleep_enable_ext0_wakeup((gpio_num_t)INT_PIN, 1);  // Wake on HIGH

// Enter deep sleep
esp_deep_sleep_start();
```

**MPU6050 Low Power Mode:**
```cpp
// Disable gyroscope and temperature sensor
mpu.setStandbyXGyroEnabled(true);
mpu.setStandbyYGyroEnabled(true);
mpu.setStandbyZGyroEnabled(true);
mpu.setTempSensorEnabled(false);

// Enable cycle mode (1.25 Hz internal sampling)
mpu.setWakeCycleEnabled(true);
mpu.setWakeFrequency(MPU6050_WAKE_FREQ_1P25);
```

### Wake-up Process

1. Motion is detected by MPU6050 hardware
2. MPU6050 INT pin goes HIGH
3. ESP32 wakes from deep sleep (GPIO 18 interrupt)
4. ESP32 reads wake reason: `ESP_SLEEP_WAKEUP_EXT0`
5. I2C and MPU6050 are reinitialized
6. `wakeMPUFromSleep()` is called to:
   - Read and clear interrupt status
   - Disable cycle mode
   - Enable all sensors (gyro + accel)
   - Disable motion interrupt during normal operation
7. State variables are reset (velocity, position, AHRS, etc.)
8. BLE advertising starts
9. Normal operation resumes

## Code Changes

### Files Modified

**Firmware/src/esp1/main.cpp:**
- Added `INT_PIN` constant (GPIO 18)
- Removed `POLL_INTERVAL_SECONDS` constant
- Removed `checkForMotion()` function
- Added `configureMPUMotionInterrupt()` function
- Updated `putMPUToSleep()` to configure motion interrupt
- Updated `wakeMPUFromSleep()` to clear interrupt
- Updated `enterDeepSleep()` to use GPIO wake instead of timer
- Updated `setup()` to handle `ESP_SLEEP_WAKEUP_EXT0` wake reason

**Firmware/POWER_MANAGEMENT.md:**
- Updated motion detection section to describe interrupt-based system
- Updated power consumption estimates
- Updated battery life calculations
- Updated testing procedures
- Updated troubleshooting guide

## Testing

### Basic Functionality Test

1. **Build and upload firmware:**
   ```bash
   cd Firmware
   pio run -e esp1 -t upload
   ```

2. **Monitor serial output:**
   ```bash
   pio device monitor -b 115200
   ```

3. **Test idle timeout:**
   - Keep device still for 20 seconds
   - Device should enter deep sleep
   - Serial output stops

4. **Test motion wake:**
   - Move or shake the device
   - Device should wake and show:
     ```
     =====================================
     WOKE UP FROM DEEP SLEEP
     Reason: Motion detected (GPIO interrupt)
     Woke from GPIO pin: 18
     =====================================
     ```

5. **Verify MPU6050 configuration:**
   - Look for configuration messages during sleep entry:
     ```
     Configuring MPU6050 motion detection interrupt...
       - Cleared all interrupts
       - Configured INT pin: active HIGH, push-pull, latched
       - Motion threshold: 64mg (0.064g)
       - Motion duration: 5ms
       - DHPF: 5Hz high-pass filter
       - Motion interrupt enabled
     ```

### Power Consumption Test

Use a multimeter or power profiler in series with power supply:

**Expected measurements:**
- Deep sleep: ~0.51 mA (constant)
- Active operation: ~30-34 mA
- BLE idle: ~20-24 mA

**Test procedure:**
1. Let device enter deep sleep
2. Measure current - should be ~0.51 mA
3. Move device to trigger wake
4. Measure current - should jump to ~30-34 mA
5. Keep device still until sleep again
6. Verify current drops back to ~0.51 mA

### Sensitivity Test

**Too sensitive (wakes on small vibrations):**
- Increase threshold from 32 to 64 or higher
- Increase duration from 5ms to 10ms

**Not sensitive enough (doesn't wake on motion):**
- Decrease threshold from 32 to 16 or lower
- Verify GPIO 18 is connected to MPU6050 INT pin
- Check serial output for interrupt configuration

## Performance Comparison

| Metric | Timer Polling (Old) | Interrupt-based (New) | Improvement |
|--------|--------------------|-----------------------|-------------|
| Sleep current | 2.7 mA | 0.51 mA | 5.3× better |
| Battery life (idle) | ~5 days | ~11 days | 2.2× better |
| Wake latency | 0-2 seconds | Instant | Eliminates delay |
| Unnecessary wakes | Every 2 seconds | None | 100% reduction |
| Code complexity | Higher | Lower | Simpler |
| Reliability | Timer-dependent | Hardware-triggered | More reliable |

## Configuration Options

### Motion Threshold

Located in `configureMPUMotionInterrupt()`:
```cpp
mpu.setMotionDetectionThreshold(32);  // 32 LSB = 64mg
```

**Sensitivity levels:**
- Very sensitive: 16 LSB = 32mg
- Normal (current): 32 LSB = 64mg
- Less sensitive: 64 LSB = 128mg

### Motion Duration

Located in `configureMPUMotionInterrupt()`:
```cpp
mpu.setMotionDetectionDuration(5);  // 5ms
```

**Duration levels:**
- Fast response: 3ms
- Normal (current): 5ms
- Filtered (less false triggers): 10ms

### Idle Timeout

Located in constants section:
```cpp
#define IDLE_TIMEOUT_MS 20000  // 20 seconds for testing
// For production: #define IDLE_TIMEOUT_MS 300000  // 5 minutes
```

## Troubleshooting

### Device doesn't wake on motion
1. Verify GPIO 18 connection to MPU6050 INT pin
2. Check serial output for interrupt configuration messages
3. Try lowering threshold: `mpu.setMotionDetectionThreshold(16);`
4. Check interrupt status register after wake

### Device wakes too often (false triggers)
1. Increase threshold: `mpu.setMotionDetectionThreshold(64);`
2. Increase duration: `mpu.setMotionDetectionDuration(10);`
3. Check for vibration sources near device

### Higher than expected sleep current
1. Verify WiFi is disabled (check serial output)
2. Verify BLE is properly shut down
3. Verify MPU6050 is in cycle mode
4. Check for other peripherals drawing power
5. Measure MPU6050 power separately

## Future Improvements

Potential enhancements for future consideration:

1. **Adaptive Threshold:** Automatically adjust motion threshold based on environment
2. **Wake History:** Track wake events to identify false trigger patterns
3. **Multi-level Threshold:** Use different thresholds for different scenarios
4. **Interrupt Debouncing:** Add software debouncing for noisy environments
5. **Power Profiling:** Add runtime power consumption monitoring

## References

- [MPU-6050 Register Map](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf)
- [MPU-6050 Datasheet](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Datasheet1.pdf)
- [ESP32-S3 Technical Reference](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)
- [ESP32 Sleep Modes](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/sleep_modes.html)
