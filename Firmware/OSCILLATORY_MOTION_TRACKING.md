# Oscillatory Motion Tracking Implementation

This document describes the advanced oscillatory motion tracking algorithm implemented in the ESP1 firmware.

## Overview

The implementation is based on the algorithm from [xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU](https://github.com/xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU), designed to track cyclic/oscillatory motion while eliminating drift.

## Algorithm Pipeline

The motion tracking follows these steps:

### 1. Accelerometer Low-Pass Filtering and Clamping
- **Purpose**: Eliminate noise from quick rotations and bumps, suitable for slow exercise motions
- **Method**: Exponential moving average (EMA) filter
- **Filter Equation**: `filtered = α × raw + (1 - α) × previous_filtered`
- **Alpha Value**: 0.2 (lower values provide more smoothing, suitable for slow motions)
- **Clamping**: Raw acceleration values are limited to ±2G before filtering
- **Benefit**: Reduces noise from sudden impacts while preserving slow, large motions typical of exercise

### 2. AHRS (Attitude and Heading Reference System)
- **Algorithm**: Mahony AHRS (IMU version without magnetometer)
- **Purpose**: Calculate the orientation of the sensor relative to Earth using gyroscope and accelerometer data
- **Output**: Quaternion (q0, q1, q2, q3) representing sensor orientation
- **Key Parameters**:
  - `MAHONY_KP = 1.0`: Proportional gain for feedback correction
  - `MAHONY_KI = 0.0`: Integral gain (set to 0 for faster convergence)

### 3. Tilt-Compensated Acceleration
- **Purpose**: Transform acceleration from sensor frame to Earth frame
- **Method**: Rotate acceleration vector using the rotation matrix derived from the quaternion
- **Result**: Acceleration measurements aligned with Earth's reference frame (X=East, Y=North, Z=Up)

### 4. Linear Acceleration Calculation
- **Purpose**: Remove gravity component to obtain linear acceleration
- **Method**: Subtract gravity vector (0, 0, 1g) from tilt-compensated acceleration
- **Conversion**: Multiply by 9.81 to convert from g's to m/s²
- **Stationary Detection**: When board is stationary (acceleration magnitude ≈ 1g and gyroscope ≈ 0), linear acceleration is zeroed to prevent drift from sensor bias

### 5. Velocity Integration with Damping
- **Integration**: `velocity = velocity + acceleration × dt`
- **Drift Removal**: Multiplicative damping factor (0.95) + threshold zeroing
- **Purpose**: Remove DC drift accumulated during integration
- **Effect**: Reduces velocity by 5% each iteration, preventing unbounded drift
- **Threshold**: Velocities below 0.01 m/s are zeroed out to eliminate noise

### 6. Position Integration with Damping
- **Integration**: `position = position + velocity × dt`
- **Drift Removal**: Multiplicative damping factor (0.99)
- **Purpose**: Remove DC drift from position estimates
- **Effect**: Reduces position by 1% each iteration, pulling toward zero when stationary

## Key Differences from Previous Implementation

### Previous Implementation:
- Simple low-pass filtering for gravity estimation
- Simple damping factors for drift correction
- No proper orientation tracking
- Gravity removal based on filtered acceleration (not true gravity direction)

### New Implementation:
- Full AHRS algorithm for accurate orientation tracking
- Proper tilt-compensation using rotation matrices
- Multiplicative damping for real-time drift correction
- Suitable for oscillatory/cyclic motion tracking (e.g., hand gestures, vibrations, pendulum motion)

**Note on High-Pass Filtering**: The reference MATLAB implementation uses batch `filtfilt` (zero-phase forward-backward filtering) on the entire dataset. This cannot be directly replicated in real-time processing without introducing instability. Therefore, we use multiplicative damping factors which provide similar drift correction without the oscillation issues that arise from real-time IIR filtering in a feedback loop.

## Technical Details

### Mahony AHRS Algorithm
The Mahony algorithm is a computationally efficient AHRS that uses a complementary filter approach:
1. Predicts gravity direction from current quaternion
2. Compares with measured acceleration (normalized)
3. Computes error as cross product
4. Corrects gyroscope measurements using proportional feedback
5. Integrates corrected gyroscope to update quaternion

### Quaternion to Rotation Matrix
The quaternion (q0, q1, q2, q3) is converted to a 3×3 rotation matrix:
```
R = [q0² + q1² - q2² - q3²,  2(q1q2 - q0q3),        2(q1q3 + q0q2)      ]
    [2(q1q2 + q0q3),        q0² - q1² + q2² - q3²,  2(q2q3 - q0q1)      ]
    [2(q1q3 - q0q2),        2(q2q3 + q0q1),        q0² - q1² - q2² + q3²]
```

### Multiplicative Damping with Thresholding
Instead of high-pass filtering (which works in MATLAB batch processing but causes instability in real-time), we use multiplicative damping with velocity thresholding:
```
velocity = velocity × 0.95
if (|velocity| < 0.01) velocity = 0
position = position × 0.99
```
This achieves drift correction without oscillation issues. The velocity threshold eliminates sensor noise that would otherwise accumulate into position drift.

## Performance Characteristics

### Advantages:
- **Accurate orientation tracking** even during rapid movements
- **Proper gravity removal** regardless of sensor tilt
- **Scientific drift removal** using proper signal processing
- **Oscillatory motion support** for cyclic movements
- **Real-time processing** on ESP32 (all computation on-device)

### Limitations:
- High-pass filter causes slow "pull to origin" for stationary positions
- Not suitable for tracking absolute position over long periods
- Best for oscillatory/cyclic motions where mean position is zero

## Configuration Parameters

All parameters are defined as constants in the code:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `INTEGRATION_INTERVAL_MS` | 10 | Update rate (100 Hz) |
| `REPORT_INTERVAL_MS` | 500 | BLE reporting rate |
| `SAMPLE_FREQ` | 100.0 | Sample frequency (Hz) |
| `MAHONY_KP` | 1.0 | AHRS proportional gain |
| `MAHONY_KI` | 0.0 | AHRS integral gain |
| `VELOCITY_DAMPING` | 0.95 | Velocity damping factor |
| `POSITION_DAMPING` | 0.99 | Position damping factor |
| `VELOCITY_THRESHOLD` | 0.01 | Velocity noise threshold (m/s) |
| `ACCEL_STATIONARY_THRESHOLD` | 0.1 | Acceleration deviation for stationary detection (g's) |
| `GYRO_STATIONARY_THRESHOLD` | 0.1 | Gyroscope threshold for stationary detection (rad/s) |

## Usage Scenarios

This algorithm is ideal for:
- Gesture recognition systems
- Cyclic motion analysis (chewing, walking, etc.)
- Vibration monitoring
- Pendulum motion tracking
- Any application where mean position/velocity = 0 over short periods

## References

- [Oscillatory Motion Tracking with x-IMU](https://github.com/xioTechnologies/Oscillatory-Motion-Tracking-With-x-IMU)
- [Mahony AHRS Algorithm](http://www.x-io.co.uk/open-source-imu-and-ahrs-algorithms/)
- [Butterworth Filter Design](https://en.wikipedia.org/wiki/Butterworth_filter)
