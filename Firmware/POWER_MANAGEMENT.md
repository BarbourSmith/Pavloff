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

### 3. Wake-on-Motion (Timer-based Polling)

**Polling System**:
- ESP32 wakes from deep sleep periodically using internal RTC timer (every 2 seconds by default)
- On wake, MPU-6050 accelerometer is read to check for motion
- Motion threshold: 0.15g deviation from gravity (1g)
- If motion detected, device stays awake and continues normal operation
- If no motion detected, device immediately returns to deep sleep

**Wake-up Process**:
1. ESP32 wakes from timer interrupt
2. MPU-6050 is briefly powered up and accelerometer is read
3. If motion detected:
   - Motion tracking state variables are reset (velocity, position, AHRS quaternion, filters)
   - Rep detection state machine is reset to IDLE (rep count resets to 0)
   - System loads stored gyroscope calibration offsets
   - BLE advertising restarts
   - Normal operation resumes
4. If no motion detected:
   - Device immediately returns to deep sleep without full initialization

## Hardware Configuration

### Pin Assignments
- **GPIO 8**: I2C SDA
- **GPIO 9**: I2C SCL

### MPU-6050 Configuration

**Motion Detection (Polling)**:
- Threshold: 0.15g deviation from gravity
- Polling interval: 2 seconds (configurable)
- On wake: Accelerometer is read and checked for motion
- Power consumption during sleep: ~500 μA (accelerometer in standby mode)

**Low Power Mode**:
- Gyroscope disabled
- Temperature sensor disabled
- Accelerometer in standby mode for quick wake
- Power consumption: ~500 μA

**Active Mode**:
- Sample rate: 100 Hz
- All sensors enabled
- Power consumption: ~3.6 mA

## Power Consumption Estimates

| Mode | ESP32-S3 | MPU-6050 | Total | Notes |
|------|----------|----------|-------|-------|
| Deep Sleep (polling) | ~10 μA | ~500 μA | ~0.51 mA | Between wake cycles |
| Wake cycle (polling) | ~30 mA | ~3.6 mA | ~34 mA | 100-200ms per cycle |
| Average (2s polling) | - | - | **~2.7 mA** | See POWER_COMPARISON.md |
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

### Polling Interval

The polling interval can be adjusted by modifying the constant in `main.cpp`:

```cpp
#define POLL_INTERVAL_SECONDS 2  // Wake up every 2 seconds to check for motion
```

**Power vs Responsiveness Trade-off**:
- 2 seconds: ~2.7 mA average, max 2s motion detection delay
- 5 seconds: ~1.2 mA average, max 5s motion detection delay
- 10 seconds: ~0.65 mA average, max 10s motion detection delay

See `POWER_COMPARISON.md` for detailed analysis.

### Motion Detection Sensitivity

Adjust motion detection threshold in `checkForMotion()`:

```cpp
// Motion threshold: deviation from 1g gravity
bool motionDetected = abs(accelMag - 1.0f) > 0.15f;  // 0.15g threshold
```

Lower threshold = more sensitive (may wake on small movements)
Higher threshold = less sensitive (requires more motion to wake)

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

Assuming a 500 mAh battery with timer-based polling (2-second interval):

### Scenario 1: Mostly Idle (with polling)
- 23 hours/day in deep sleep: 2.7 mA × 23 = 62.1 mAh
- 1 hour/day active: 34 mA × 1 = 34 mAh
- **Total per day**: ~96 mAh
- **Battery life**: ~5 days

### Scenario 2: Active Use
- 8 hours/day in deep sleep: 2.7 mA × 8 = 21.6 mAh
- 16 hours/day active: 34 mA × 16 = 544 mAh
- **Total per day**: ~566 mAh
- **Battery life**: ~21 hours

### Scenario 3: Continuous Use
- 24 hours/day active: 34 mA × 24 = 816 mAh
- **Battery life**: ~15 hours (with 500 mAh battery)

**Note**: See `POWER_COMPARISON.md` for detailed comparison with interrupt-based wake system and optimization strategies.

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

### Test Wake-on-Motion (Timer-based Polling)
1. After device enters deep sleep
2. Device will wake every 2 seconds automatically
3. On wake without motion, you will see:
   ```
   =====================================
   WOKE UP FROM DEEP SLEEP
   Reason: Timer wake (motion polling)
   =====================================
   Motion check - Accel magnitude: 1.000g, Motion: NO
   No motion detected - returning to sleep
   ```
4. Move or shake the device and wait up to 2 seconds
5. Observe serial output showing motion detected:
   ```
   =====================================
   WOKE UP FROM DEEP SLEEP
   Reason: Timer wake (motion polling)
   =====================================
   Motion check - Accel magnitude: 1.350g, Motion: YES
   Motion detected - resuming normal operation...
   =====================================
   ```
6. Device returns to normal operation

**Note**: The current firmware is configured with a 20-second idle timeout for testing. For production use, change `IDLE_TIMEOUT_MS` to 300000 (5 minutes).

### Measure Current Consumption
- Use a multimeter or power profiler in series with power supply
- Monitor current during active operation, idle, and deep sleep
- Expected values with 2-second polling:
  - Deep sleep: ~0.5 mA between wake cycles
  - Wake cycle: ~30-34 mA for 100-200ms
  - Average: ~2.7 mA
- Verify values match estimates above

## Troubleshooting

### Device wakes too frequently
- This is expected with timer-based polling (every 2 seconds)
- Increase `POLL_INTERVAL_SECONDS` to reduce wake frequency
- Trade-off: Longer interval = slower motion detection response

### Motion detection too sensitive
- Adjust threshold in `checkForMotion()` function
- Increase threshold from 0.15g to 0.20g or higher
- Higher threshold requires more motion to wake

### Motion detection not sensitive enough
- Decrease threshold in `checkForMotion()` function
- Lower threshold from 0.15g to 0.10g or lower
- Be careful: too low may cause false wake-ups from vibrations

### Enters sleep too quickly
- Increase `IDLE_TIMEOUT_MS` value
- Check that activity detection is working (motion triggers activity timer)

### High power consumption in active mode
- Verify CPU frequency is set to 80 MHz
- Check BLE power level is set to minimum
- Ensure automatic light sleep is enabled
- WiFi radio is explicitly disabled, saving 20-100mA

### High power consumption in deep sleep (polling mode)
- Expected: ~2.7 mA average with 2-second polling interval
- This is normal for timer-based polling system
- To reduce power consumption:
  - Increase `POLL_INTERVAL_SECONDS` (e.g., 5 or 10 seconds)
  - See `POWER_COMPARISON.md` for optimization strategies
  - Consider fixing interrupt-based wake system for better efficiency
- Verify WiFi radio is disabled (check serial output at startup)
- Ensure BLE shutdown completes before entering sleep
- Check that unused RTC peripherals are powered off
- Use multimeter to measure actual current consumption

## References

- [ESP32-S3 Technical Reference Manual](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)
- [ESP32 Power Management](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/power_management.html)
- [MPU-6050 Register Map](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf)
- [MPU-6050 Datasheet](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Datasheet1.pdf)
