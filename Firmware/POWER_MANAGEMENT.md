# Power Management

This document describes the power management features implemented in the ESP32 firmware.

## Overview

The firmware implements comprehensive power management to minimize energy consumption during operation and automatically enter deep sleep mode after periods of inactivity.

## Features

### 1. Active Power Optimization

Even during normal operation, the system uses minimal power through:

- **Reduced CPU Frequency**: CPU runs at 80 MHz instead of 240 MHz, sufficient for motion tracking while using significantly less power
- **Dynamic Frequency Scaling**: CPU can scale down to 10 MHz during idle periods
- **Automatic Light Sleep**: CPU enters light sleep between tasks automatically
- **Optimized BLE Power**: BLE transmit power set to minimum level (0 dBm) for energy efficiency while maintaining good connection within typical workout distances

### 2. Idle Detection and Deep Sleep

**Idle Timeout**: The system monitors activity and enters deep sleep after **5 minutes of inactivity**.

Activity is detected from:
- Motion (acceleration or rotation exceeding stationary thresholds)
- BLE connection state
- BLE data writes (e.g., rep count reset commands)

**Deep Sleep Mode**: When idle timeout is reached:
1. MPU-6050 is put into low-power mode (gyroscope and temperature sensor disabled)
2. BLE is powered down completely with adequate time for clean shutdown
3. WiFi radio is explicitly disabled to prevent power drain
4. Unused RTC peripherals and memory domains are powered off
5. ESP32 enters deep sleep (consuming only ~10 μA)
6. All state is lost; wake-up is like a fresh boot

### 3. Wake-on-Motion (Interrupt-based)

**Interrupt System**:
- ESP32 wakes from deep sleep via hardware interrupt from MPU-6050 INT pin (GPIO 18)
- MPU-6050 continuously monitors for motion using hardware motion detection
- Motion threshold: 64mg (0.064g) with 5ms duration to avoid false triggers
- When motion is detected, MPU-6050 triggers interrupt to wake ESP32
- Device stays awake and continues normal operation

**Wake-up Process**:
1. MPU-6050 detects motion exceeding threshold using hardware motion detection
2. MPU-6050 INT pin goes HIGH, triggering ESP32 wake from deep sleep
3. ESP32 wakes from GPIO interrupt
4. Motion tracking state variables are reset (velocity, position, AHRS quaternion, filters)
5. Rep detection state machine is reset to IDLE (rep count resets to 0)
6. System loads stored gyroscope calibration offsets
7. BLE advertising restarts
8. Normal operation resumes

## Hardware Configuration

### Pin Assignments
- **GPIO 8**: I2C SDA
- **GPIO 9**: I2C SCL
- **GPIO 18**: MPU-6050 INT pin (motion detection interrupt)

### MPU-6050 Configuration

**Motion Detection (Hardware Interrupt)**:
- Threshold: 64mg (0.064g) acceleration
- Duration: 5ms minimum to avoid false triggers from vibration
- Digital High-Pass Filter: 5Hz to remove DC bias
- Interrupt output: Active HIGH, push-pull, latched until cleared
- Wake-up: Instant response to motion (no polling delay)
- Power consumption during sleep: ~500 μA (accelerometer in cycle mode)

**Low Power Mode (Cycle Mode)**:
- Gyroscope disabled
- Temperature sensor disabled
- Accelerometer in cycle mode (wakes internally at 1.25 Hz to sample)
- Motion detection interrupt enabled
- Power consumption: ~500 μA (MPU6050 only)

**Active Mode**:
- Sample rate: 100 Hz
- All sensors enabled
- Power consumption: ~3.6 mA

## Power Consumption Estimates

| Mode | ESP32-S3 | MPU-6050 | Total | Notes |
|------|----------|----------|-------|-------|
| Deep Sleep (interrupt) | ~10 μA | ~500 μA | **~0.51 mA** | Waiting for interrupt |
| Active (BLE connected) | ~30 mA | ~3.6 mA | ~34 mA | 80 MHz, BLE active |
| Active (BLE idle) | ~20 mA | ~3.6 mA | ~24 mA | 80 MHz, no BLE TX |

## Configuration

### Idle Timeout

The idle timeout can be adjusted by modifying the constant in `main.cpp`:

```cpp
#define IDLE_TIMEOUT_MS 20000  // 20 seconds in milliseconds (for testing)
// For production use: #define IDLE_TIMEOUT_MS 300000  // 5 minutes
```

**Note**: The current configuration uses 20 seconds for testing purposes. For production deployment, change this to 300000 (5 minutes) or longer.

### Motion Detection Sensitivity

Adjust motion detection threshold in `configureMPUMotionInterrupt()`:

```cpp
// Motion threshold: 1-255 (1 LSB = 2mg @ 2g range)
// 32 = 64mg = 0.064g
mpu.setMotionDetectionThreshold(32);  // 64mg threshold
```

Lower threshold = more sensitive (may wake on small movements):
- 16 = 32mg (very sensitive)

Higher threshold = less sensitive (requires more motion to wake):
- 64 = 128mg (less sensitive)

### Motion Detection Duration

Adjust minimum motion duration to avoid false triggers:

```cpp
// Motion duration: 0-255 (1 LSB = 1ms)
mpu.setMotionDetectionDuration(5);  // 5ms duration
```

Increase this value to require longer sustained motion before triggering wake-up.

### CPU Frequency

Adjust CPU frequency in `configurePowerOptimizations()`:

```cpp
setCpuFrequencyMhz(80);  // Options: 240, 160, 80, 40, 20, 10
```

### BLE Transmit Power

Adjust BLE power in `setup()`:

```cpp
// Range: ESP_PWR_LVL_N12 (-12 dBm) to ESP_PWR_LVL_P9 (+9 dBm)
BLEDevice::setPower(ESP_PWR_LVL_N0, ESP_BLE_PWR_TYPE_DEFAULT);
```

### WiFi Radio Management

The firmware explicitly disables the WiFi radio to prevent power drain:

```cpp
// In setup() - disable WiFi at startup (BLE-only mode)
esp_wifi_stop();

// In enterDeepSleep() - ensure WiFi is off before sleep
esp_wifi_stop();
esp_wifi_deinit();
```

**Note**: The WiFi radio can consume 20-100mA even when not actively transmitting. Since this device uses BLE exclusively, disabling WiFi provides significant power savings.

## Battery Life Estimates

Assuming a 500 mAh battery with interrupt-based wake:

### Scenario 1: Mostly Idle (interrupt-based)
- 23 hours/day in deep sleep: 0.51 mA × 23 = 11.7 mAh
- 1 hour/day active: 34 mA × 1 = 34 mAh
- **Total per day**: ~46 mAh
- **Battery life**: ~11 days

### Scenario 2: Active Use
- 8 hours/day in deep sleep: 0.51 mA × 8 = 4.1 mAh
- 16 hours/day active: 34 mA × 16 = 544 mAh
- **Total per day**: ~548 mAh
- **Battery life**: ~22 hours

### Scenario 3: Continuous Use
- 24 hours/day active: 34 mA × 24 = 816 mAh
- **Battery life**: ~15 hours (with 500 mAh battery)

**Note**: Interrupt-based wake system provides significantly better battery life compared to timer-based polling, especially for idle scenarios (11 days vs 5 days).

## Testing

### Test Deep Sleep Entry
1. Upload firmware to ESP32
2. Monitor serial output at 115200 baud
3. Wait 20 seconds without moving device (testing configuration)
4. You will see a warning: "WARNING: Device will enter sleep in 5 seconds if no activity detected"
5. After 5 more seconds, observe the sleep message:
   ```
   =====================================
   ENTERING DEEP SLEEP MODE
   Device will wake every 2 seconds to check for motion
   Current uptime: XX seconds
   =====================================
   ```
6. Serial output will stop (device is asleep)

### Test Wake-on-Motion (Interrupt-based)
1. After device enters deep sleep
2. Device remains asleep until motion is detected
3. Move or shake the device
4. Observe serial output showing motion detected:
   ```
   =====================================
   WOKE UP FROM DEEP SLEEP
   Reason: Motion detected (GPIO interrupt)
   Woke from GPIO pin: 18
   =====================================
   Motion detected - resuming normal operation...
   ```
5. Device returns to normal operation
6. No more output until motion stops and idle timeout is reached again

**Note**: The current firmware is configured with a 20-second idle timeout for testing. For production use, change `IDLE_TIMEOUT_MS` to 300000 (5 minutes).

### Measure Current Consumption
- Use a multimeter or power profiler in series with power supply
- Monitor current during active operation, idle, and deep sleep
- Expected values with interrupt-based wake:
  - Deep sleep: ~0.51 mA (constant while waiting for interrupt)
  - Active operation: ~30-34 mA
- Verify values match estimates above

## Troubleshooting

### Motion detection too sensitive
- Adjust threshold in `configureMPUMotionInterrupt()` function
- Increase threshold from 32 (64mg) to 64 (128mg) or higher
- Increase motion duration from 5ms to 10ms or more
- Higher threshold requires more motion to wake

### Motion detection not sensitive enough
- Decrease threshold in `configureMPUMotionInterrupt()` function
- Lower threshold from 32 (64mg) to 16 (32mg) or lower
- Be careful: too low may cause false wake-ups from vibrations
- Consider decreasing motion duration from 5ms to 3ms

### Device doesn't wake on motion
- Verify GPIO 18 is properly connected to MPU-6050 INT pin
- Check serial output for interrupt configuration messages
- Verify MPU-6050 interrupt status shows motion detection enabled
- Try increasing motion sensitivity (lower threshold)

### Enters sleep too quickly
- Increase `IDLE_TIMEOUT_MS` value
- Check that activity detection is working (motion triggers activity timer)

### High power consumption in active mode
- Verify CPU frequency is set to 80 MHz
- Check BLE power level is set to minimum
- Ensure automatic light sleep is enabled
- WiFi radio is explicitly disabled, saving 20-100mA

### High power consumption in deep sleep (interrupt mode)
- Expected: ~0.51 mA with interrupt-based wake
- If consumption is higher:
  - Verify WiFi radio is disabled (check serial output at startup)
  - Ensure BLE shutdown completes before entering sleep
  - Check that unused RTC peripherals are powered off
  - Verify MPU-6050 is in cycle mode (check serial output)
  - Use multimeter to measure actual current consumption
  - Check for any other peripherals drawing power

## References

- [ESP32-S3 Technical Reference Manual](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)
- [ESP32 Power Management](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/power_management.html)
- [MPU-6050 Register Map](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf)
- [MPU-6050 Datasheet](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Datasheet1.pdf)
