# IMU Position Integration Summary

## Overview
This document describes the implementation of IMU data integration to calculate and display XYZ position in space from accelerometer data.

## Changes Made

### 1. React Native App (JavaScript)

#### New File: `utils/imuIntegration.js`
- **IMUIntegrator class**: Integrates accelerometer data to calculate position
- **Key Features**:
  - Double integration: acceleration → velocity → position
  - Gravity compensation (removes 9.81 m/s² from Z-axis)
  - Trapezoidal integration for better accuracy
  - Velocity dampening (0.98 factor) to reduce drift
  - Time delta validation to prevent integration errors

#### Modified: `screens/DataDisplayScreen.js`
- Added import for `IMUIntegrator`
- Created integrator instances for each connected device using `useRef`
- Modified `DataView` component to:
  - Accept `integrator` prop
  - Calculate position from acceleration data
  - Display position in the left column (instead of accelerometer)
  - Display acceleration in the right column (for reference)
- Position displayed in meters with 3 decimal places precision

### 2. Swift iOS App

#### Modified: `ios/esp32Connect/Models.swift`
- **New `PositionData` struct**: Stores calculated XYZ position
  - Properties: x, y, z (in meters)
  - Formatted properties for display with 3 decimal places
- **Updated `DeviceData` struct**: Added `positionData` field

#### Modified: `ios/esp32Connect/BLEManager.swift`
- **New `IMUIntegrator` class**: Swift implementation of position integration
  - Same algorithm as JavaScript version
  - Uses tuples for velocity, position, and previous acceleration
  - Integrates on each accelerometer data update
- **Updated `BLEManager` class**:
  - Added `integrators` dictionary to track integrator per device
  - Modified `didUpdateValueFor` to integrate acceleration data
  - Updates device's `positionData` on each accelerometer reading

#### Modified: `ios/esp32Connect/DataDisplayView.swift`
- **New `PositionDataView` struct**: Displays position data
  - Shows X, Y, Z position in meters
  - Purple color scheme to distinguish from acceleration
- **Updated `DeviceDataCard`**:
  - Replaced gyroscope display with position display
  - Now shows: Position (top), Acceleration (bottom)
  - Removed gyroscope data from display

## Technical Details

### Integration Algorithm

1. **Input**: Acceleration data in m/s² (X, Y, Z)
2. **Gravity Compensation**: Subtract 9.81 m/s² from Z-axis (assuming vertical orientation)
3. **Velocity Integration** (Trapezoidal rule):
   ```
   v(t) = v(t-1) + (a(t-1) + a(t)) * dt / 2
   ```
4. **Velocity Dampening**: Multiply by 0.98 to reduce drift
   ```
   v(t) = v(t) * 0.98
   ```
5. **Position Integration**:
   ```
   p(t) = p(t-1) + v(t) * dt
   ```

### Coordinate System
- **X-axis**: Lateral movement
- **Y-axis**: Forward/backward movement
- **Z-axis**: Vertical movement (gravity compensated)

### Limitations & Considerations

1. **Drift**: IMU-based position estimation accumulates error over time due to:
   - Sensor noise
   - Integration errors
   - Gravity compensation accuracy

2. **Mitigation Strategies**:
   - Velocity dampening reduces long-term drift
   - Time delta validation prevents integration spikes
   - Trapezoidal integration improves accuracy

3. **Use Cases**: Best suited for:
   - Short-duration motion tracking
   - Relative position changes
   - Exercise/movement monitoring
   - Not recommended for long-term absolute positioning

## Testing Recommendations

1. **Static Test**: Place device on table, verify position stays near (0, 0, 0)
2. **Linear Motion**: Move device in straight line, verify position increases
3. **Return to Start**: Move device and return to start, verify position returns close to (0, 0, 0)
4. **Multi-Device**: Test with 2 devices simultaneously

## Display Changes

### Before
- Left column: Accelerometer (X, Y, Z in m/s²)
- Right column: Gyroscope (X, Y, Z in rad/s)

### After
- Left column: **Position (X, Y, Z in meters)**
- Right column: **Acceleration (X, Y, Z in m/s²)**
- Gyroscope data: Not displayed (but still captured in Swift app)

## Files Modified

### React Native
1. `utils/imuIntegration.js` (NEW)
2. `screens/DataDisplayScreen.js`

### Swift iOS
1. `ios/esp32Connect/Models.swift`
2. `ios/esp32Connect/BLEManager.swift`
3. `ios/esp32Connect/DataDisplayView.swift`

## Future Enhancements

1. **Reset Button**: Allow users to reset position to (0, 0, 0)
2. **Kalman Filter**: Reduce noise and improve accuracy
3. **Gyroscope Integration**: Use rotation data for better position estimation
4. **Trajectory Visualization**: Plot 3D path of device movement
5. **Statistics**: Show total distance traveled, peak velocity, etc.
