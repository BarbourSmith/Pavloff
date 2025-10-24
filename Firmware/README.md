# Motion Control Board

ESP32-based motion tracking system using MPU-6050 IMU sensors with advanced oscillatory motion tracking algorithm.

The objective of this project is to detect if a user is exercising with a free weight and detect the number of repititions that they do.

## Overview

This project implements real-time motion tracking on ESP32 microcontrollers using MPU-6050 IMU sensors. The system features advanced oscillatory motion tracking with:

- **Mahony AHRS algorithm** for accurate orientation estimation
- **Quaternion-based rotation** for tilt compensation
- **High-pass Butterworth filters** for drift removal
- **BLE communication** for wireless data streaming

## Hardware

- **ESP32 Development Board**
- **MPU-6050 IMU Sensor** (gyroscope + accelerometer)
- I2C communication interface

### Pin Configuration

- SDA: GPIO 8
- SCL: GPIO 9
- MPU-6050 INT: GPIO 18 (motion detection interrupt for wake-up)

## Features

### Power Management
Comprehensive power optimization for battery operation:
- **Active Power Optimization**: Reduced CPU frequency (80 MHz), automatic light sleep, and optimized BLE power
- **Automatic Deep Sleep**: Enters ultra-low power mode (< 50 μA) after 5 minutes of inactivity
- **Wake-on-Motion**: MPU-6050 motion detection interrupt wakes device from deep sleep
- **Reliable Sleep/Wake Cycle**: Proper stabilization delays prevent spurious wake-ups
- **Extended Battery Life**: Up to 14 days on a 500 mAh battery with typical usage

See [POWER_MANAGEMENT.md](POWER_MANAGEMENT.md) for detailed information.
See [IMMEDIATE_WAKE_FIX.md](IMMEDIATE_WAKE_FIX.md) for details on the sleep stabilization fix.

### Workout Rep Detection
Automatically counts workout repetitions using orientation-independent motion analysis:

1. **Velocity-Based Detection**: Tracks velocity direction changes along dominant motion axis
2. **State Machine**: Three-state system (IDLE, MOVING_UP, MOVING_DOWN) for robust rep counting
3. **Orientation Independent**: Works regardless of sensor mounting orientation
4. **Configurable Thresholds**: Adjustable sensitivity for different exercise types
5. **False Positive Prevention**: Minimum phase duration requirement (300ms) prevents spurious counts
6. **Automatic Reset**: Resets after 3 seconds of inactivity

### Advanced Oscillatory Motion Tracking
Based on the algorithm from [xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU](https://github.com/xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU), this implementation provides:

1. **Low-Pass Filtering**: Exponential moving average filter smooths accelerometer data to eliminate noise from quick rotations and bumps
2. **Acceleration Clamping**: Limits acceleration readings to ±2G for slow exercise motions
3. **Orientation Tracking**: Mahony AHRS algorithm fuses gyroscope and accelerometer data to calculate sensor orientation
4. **Tilt Compensation**: Transforms acceleration measurements to Earth reference frame
5. **Linear Acceleration**: Removes gravity component to obtain true linear acceleration
6. **Drift-Free Velocity**: Integration with high-pass filtering prevents velocity drift
7. **Drift-Free Position**: Integration with high-pass filtering prevents position drift

### BLE Streaming
- Position data transmitted every 500ms
- Gyroscope data for rotation tracking
- Rep count and state information
- Wireless connectivity for real-time monitoring

## Algorithm Details

The tracking algorithm follows these steps:

```
Raw IMU Data → Low-Pass Filter & Clamp → AHRS → Tilt-Compensated Accel → Linear Accel → 
Velocity Integration → High-Pass Filter → Position Integration → High-Pass Filter → Output
                                                      ↓
                                           Rep Detection (State Machine)
```

See detailed documentation:
- [USAGE_GUIDE.md](USAGE_GUIDE.md) - Quick start guide for rep detection
- [REP_DETECTION.md](REP_DETECTION.md) - Workout rep detection algorithm
- [OSCILLATORY_MOTION_TRACKING.md](OSCILLATORY_MOTION_TRACKING.md) - Motion tracking algorithm

## Key Parameters

### Motion Tracking Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Sample Rate | 100 Hz | Position calculation frequency |
| Report Rate | 2 Hz | BLE transmission frequency |
| AHRS Gain (Kp) | 1.0 | Proportional feedback gain |
| Low-Pass Filter Alpha | 0.2 | Accelerometer smoothing coefficient |
| Max Acceleration | 2.0 g | Acceleration clamp limit |
| Filter Cutoff | 0.1 Hz | High-pass filter cutoff frequency |

### Rep Detection Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Acceleration Threshold | 0.3 g | Minimum acceleration for active motion |
| Velocity Threshold | 0.20 m/s | Minimum velocity to consider moving |
| Min Phase Duration | 500 ms | Minimum time for each rep phase |
| Rest Timeout | 3000 ms | Inactivity time before reset |

## Installation

1. Install [PlatformIO](https://platformio.org/install)
2. Clone this repository
3. Build and upload to ESP32:
   ```bash
   pio run -e esp1 -t upload
   ```

The project uses PlatformIO for dependency management. All required libraries (MPU6050_tockn and ESP32 BLE Arduino) are automatically installed.

## Usage

### Calibration
On startup, the device calibrates the gyroscope. **Keep the sensor stationary** during this process (indicated by serial output).

### BLE Connection
- ESP1 advertises as "Pavloff Workout Sensor"
- Connect using BLE client to receive position and gyroscope data

### Data Format
- Position data: `X:value,Y:value,Z:value` (in millimeters)
- Gyroscope data: `X:value,Y:value,Z:value` (in degrees/second)
- Rep count data: `Count:value,State:state` (count is integer, state is IDLE/UP/DOWN)

## Applications

This system is ideal for:
- **Workout rep counting** for free weights and resistance training (dynamic movements only, not isometric holds)
- Gesture recognition
- Cyclic motion analysis (walking, chewing, etc.)
- Vibration monitoring
- Pendulum motion tracking
- Any application requiring oscillatory motion tracking

## Limitations

- High-pass filtering causes slow "pull to origin" effect for stationary objects
- Not suitable for long-term absolute position tracking
- Best suited for cyclic/oscillatory motions where mean position is zero

## Technical Notes

### Why High-Pass Filtering?
Traditional double integration of accelerometer data suffers from severe drift. High-pass filtering removes DC components while preserving oscillatory motion, making it ideal for cyclic movements.

### Why Mahony AHRS?
The Mahony algorithm provides computationally efficient orientation estimation suitable for real-time processing on microcontrollers, with excellent accuracy when properly tuned.

## References

- [Oscillatory Motion Tracking with x-IMU](https://github.com/xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU)
- [Mahony AHRS Paper](https://hal.science/hal-00488376/document)
- [MPU-6050 Datasheet](https://invensense.tdk.com/products/motion-tracking/6-axis/mpu-6050/)

## License

See repository license file.

## Contributing

Contributions welcome! Please ensure any modifications maintain the minimal change principle and are well-documented.
