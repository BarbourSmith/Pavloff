# IMU Position Integration - Visual Guide

## Display Changes

### BEFORE (Raw IMU Data Display)
```
┌─────────────────────────────────────────┐
│         Device 1: ESP32-IMU             │
├─────────────────────────────────────────┤
│                                         │
│  Accelerometer      │    Gyroscope      │
│  ───────────────────┼──────────────────│
│  X: 0.12 m/s²      │  X: 0.05 rad/s   │
│  Y: -0.45 m/s²     │  Y: 0.12 rad/s   │
│  Z: 9.81 m/s²      │  Z: -0.03 rad/s  │
│                                         │
└─────────────────────────────────────────┘
```

### AFTER (Position + Acceleration Display)
```
┌─────────────────────────────────────────┐
│         Device 1: ESP32-IMU             │
├─────────────────────────────────────────┤
│                                         │
│  Position (XYZ)    │   Acceleration    │
│  ───────────────────┼──────────────────│
│  X: 0.125 m        │  X: 0.12 m/s²    │
│  Y: -0.234 m       │  Y: -0.45 m/s²   │
│  Z: 0.056 m        │  Z: 9.81 m/s²    │
│                                         │
└─────────────────────────────────────────┘
```

## Data Flow Architecture

### React Native App Flow
```
┌──────────────┐
│ BLE Service  │ → Receives raw accel data: "X:0.12,Y:-0.45,Z:9.81"
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ DataDisplayScreen.js │
├──────────────────────┤
│ 1. Parse raw data    │
│ 2. Pass to Integrator│
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  IMUIntegrator       │
├──────────────────────┤
│ • Compensate gravity │
│ • Integrate to vel   │
│ • Integrate to pos   │
│ • Apply dampening    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Display Position    │
│  X: 0.125 m         │
│  Y: -0.234 m        │
│  Z: 0.056 m         │
└──────────────────────┘
```

### Swift iOS App Flow
```
┌──────────────┐
│ CoreBluetooth│ → Receives characteristic value update
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│   BLEManager.swift   │
├──────────────────────┤
│ 1. Parse sensor data │
│ 2. Update accelData  │
│ 3. Call integrator   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  IMUIntegrator       │
├──────────────────────┤
│ • Compensate gravity │
│ • Integrate to vel   │
│ • Integrate to pos   │
│ • Apply dampening    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Update DeviceData    │
│  positionData: {     │
│    x: 0.125          │
│    y: -0.234         │
│    z: 0.056          │
│  }                   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ DataDisplayView.swift│
│  PositionDataView    │
│  displays position   │
└──────────────────────┘
```

## Integration Algorithm Visualization

```
Time ───────────────────────────────────────────►

Acceleration (input)
   │    ╱╲    ╱╲
   │   ╱  ╲  ╱  ╲
   │  ╱    ╲╱    ╲
   └────────────────────
         │
         │ (integrate with dampening)
         ▼
Velocity
   │      ╱‾‾╲      
   │    ╱     ╲___
   │  ╱          ‾‾╲
   └────────────────────
         │
         │ (integrate)
         ▼
Position
   │         ╱‾‾‾‾‾╲
   │      ╱          ╲
   │    ╱              ╲__
   └────────────────────────
```

## Key Features

### 1. Gravity Compensation
```
Raw Z acceleration: 9.81 m/s² (at rest)
                    ↓
            Subtract 9.81
                    ↓
Compensated Z: 0.00 m/s² (at rest)
```

### 2. Velocity Dampening
```
Before dampening: v = 0.100 m/s
                     ↓
            Multiply by 0.98
                     ↓
After dampening:  v = 0.098 m/s

Effect: Gradually reduces velocity to zero
Purpose: Prevents infinite drift from integration errors
```

### 3. Trapezoidal Integration
```
Standard:     v(t) = v(t-1) + a(t) * dt
              ↓
Trapezoidal:  v(t) = v(t-1) + (a(t-1) + a(t)) * dt / 2
              ↓
Result: More accurate, less sensitive to noise
```

## Color Coding (Swift iOS)

- **Position**: 🟣 Purple
- **Acceleration**: 🔵 Blue
- **Gyroscope**: 🟢 Green (not displayed but still captured)

## Usage Example

### Scenario: Moving device right 20cm then back to start

```
Movement: →→→ (20cm right) ←←← (back to start)

Position Display:
t=0s:   X: 0.000 m
t=1s:   X: 0.050 m  (moving right)
t=2s:   X: 0.120 m  (accelerating)
t=3s:   X: 0.200 m  (reached peak)
t=4s:   X: 0.180 m  (returning)
t=5s:   X: 0.080 m  (moving left)
t=6s:   X: 0.010 m  (near start, small drift)
```

Note: Small drift (±1cm) is normal due to sensor noise and integration errors.

## File Structure

```
Exercise-App/
├── utils/
│   └── imuIntegration.js        ← NEW: Integration logic
├── screens/
│   └── DataDisplayScreen.js      ← MODIFIED: Uses integrator
└── ios/
    └── esp32Connect/
        ├── Models.swift          ← MODIFIED: Added PositionData
        ├── BLEManager.swift      ← MODIFIED: Added IMUIntegrator
        └── DataDisplayView.swift ← MODIFIED: Shows position
```

## Testing Checklist

- [ ] App displays position in meters (3 decimal places)
- [ ] Position starts near (0, 0, 0) when device is stationary
- [ ] Position changes when device is moved
- [ ] Position returns close to origin after circular movement
- [ ] Acceleration still displayed for reference
- [ ] Multi-device support works (up to 2 devices)
- [ ] Both React Native and Swift iOS implementations work
