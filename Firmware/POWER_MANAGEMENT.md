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
1. MPU-6050 is put into low-power cycle mode (1.25 Hz wake frequency)
2. BLE is powered down
3. ESP32 enters deep sleep (consuming only ~10 μA)
4. All state is lost; wake-up is like a fresh boot

### 3. Wake-on-Motion

**Motion Detection Interrupt**:
- MPU-6050 is configured to generate an interrupt on GPIO 18 when motion is detected
- Motion threshold: 64mg (configurable)
- Motion duration: 10ms continuous motion required (configurable)
- ESP32 wakes from deep sleep on this interrupt

**Wake-up Process**:
1. ESP32 detects wake-up was from motion interrupt
2. MPU-6050 is restored to full power mode
3. System recalibrates gyroscope
4. BLE advertising restarts
5. Normal operation resumes

## Hardware Configuration

### Pin Assignments
- **GPIO 18**: MPU-6050 INT pin (motion detection interrupt)
- **GPIO 8**: I2C SDA
- **GPIO 9**: I2C SCL

### MPU-6050 Configuration

**Motion Detection**:
- Threshold: 32 (×2mg = 64mg)
- Duration: 10ms
- Interrupt: Active high, latched until cleared
- Motion detection logic enabled with decrement count of 1

**Low Power Mode**:
- Cycle mode enabled
- Wake frequency: 1.25 Hz
- Accelerometer only (gyroscope disabled)
- Power consumption: ~40 μA

**Active Mode**:
- Sample rate: 100 Hz
- All sensors enabled
- Power consumption: ~3.6 mA

## Power Consumption Estimates

| Mode | ESP32-S3 | MPU-6050 | Total | Notes |
|------|----------|----------|-------|-------|
| Deep Sleep | ~10 μA | ~40 μA | ~50 μA | Wake on motion |
| Active (BLE connected) | ~30 mA | ~3.6 mA | ~34 mA | 80 MHz, BLE active |
| Active (BLE idle) | ~20 mA | ~3.6 mA | ~24 mA | 80 MHz, no BLE TX |

## Configuration

### Idle Timeout

The idle timeout can be adjusted by modifying the constant in `main.cpp`:

```cpp
#define IDLE_TIMEOUT_MS 300000  // 5 minutes in milliseconds
```

### Motion Detection Sensitivity

Adjust MPU-6050 motion detection in `configureMPUMotionInterrupt()`:

```cpp
// Threshold: 0-255, LSB = 2mg
mpu.writeMPU6050(MPU6050_MOT_THR, 32);  // 32 = 64mg

// Duration: 1-255, LSB = 1ms
mpu.writeMPU6050(MPU6050_MOT_DUR, 10);  // 10ms

// Motion detection logic control
// Bits 7-6 control decrement count (01 = 1 count)
// Bits 5-4 control accelerometer startup delay (01 = 4ms)
mpu.writeMPU6050(MPU6050_MOT_DETECT_CTRL, 0x50);
```

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

## Battery Life Estimates

Assuming a 500 mAh battery:

### Scenario 1: Mostly Idle
- 23 hours/day in deep sleep: 50 μA × 23 = 1.15 mAh
- 1 hour/day active: 34 mA × 1 = 34 mAh
- **Total per day**: ~35 mAh
- **Battery life**: ~14 days

### Scenario 2: Active Use
- 8 hours/day in deep sleep: 50 μA × 8 = 0.4 mAh
- 16 hours/day active: 34 mA × 16 = 544 mAh
- **Total per day**: ~544 mAh
- **Battery life**: ~22 hours

### Scenario 3: Continuous Use
- 24 hours/day active: 34 mA × 24 = 816 mAh
- **Battery life**: ~15 hours (with 500 mAh battery)

## Testing

### Test Deep Sleep Entry
1. Upload firmware to ESP32
2. Monitor serial output
3. Wait 5 minutes without moving device
4. Observe "Entering deep sleep mode..." message
5. Serial output will stop (device is asleep)

### Test Wake-on-Motion
1. After device enters deep sleep
2. Move or shake the device
3. Observe serial output resumes with "Woke up from deep sleep..."
4. Device returns to normal operation

### Measure Current Consumption
- Use a multimeter or power profiler in series with power supply
- Monitor current during active operation, idle, and deep sleep
- Verify values match estimates above

## Troubleshooting

### Device doesn't wake from sleep
- Check GPIO 18 connection to MPU-6050 INT pin
- Verify MPU-6050 motion detection configuration
- Test with lower motion threshold
- **Fixed in latest version**: The motion detection logic (MOT_DETECT_CTRL register) is now properly configured to enable wake-on-motion
- **Fixed in latest version**: Interrupt status is cleared on wake-up to prevent stuck interrupts

### Enters sleep too quickly
- Increase `IDLE_TIMEOUT_MS` value
- Check that activity detection is working (motion triggers activity timer)

### High power consumption in active mode
- Verify CPU frequency is set to 80 MHz
- Check BLE power level is set to minimum
- Ensure automatic light sleep is enabled

## References

- [ESP32-S3 Technical Reference Manual](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)
- [ESP32 Power Management](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/power_management.html)
- [MPU-6050 Register Map](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf)
- [MPU-6050 Datasheet](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Datasheet1.pdf)
