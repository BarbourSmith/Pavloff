# Sensitivity Settings

This document describes the sensitivity configuration feature added to the Pavloff workout tracking app.

## Overview

The sensitivity settings allow users to customize how the workout sensor detects reps and vibrations. This feature helps accommodate different exercise types, movement speeds, and user preferences.

## Features

### 1. Rep Detection Sensitivity

Controls how sensitive the sensor is when counting workout repetitions (e.g., bicep curls, squats).

- **Range**: 0.0 (Low) to 1.0 (High)
- **Default**: 0.5 (Medium)
- **Effect**: Higher sensitivity detects smaller, slower movements as reps
- **Use Cases**:
  - **Low Sensitivity (0.0-0.3)**: Heavy weights with controlled, deliberate movements
  - **Medium Sensitivity (0.3-0.7)**: Standard exercises with moderate speed
  - **High Sensitivity (0.7-1.0)**: Light weights with quick movements or partial reps

### 2. Vibration Detection Sensitivity

Controls how sensitive the sensor is when detecting vibrations for duration-based activities (e.g., treadmill, cycling).

- **Range**: 0.0 (Low) to 1.0 (High)
- **Default**: 0.5 (Medium)
- **Effect**: Higher sensitivity detects smaller vibrations as active movement
- **Timeout**: Activity marked inactive after 5 seconds without vibration (allows brief pauses)
- **Use Cases**:
  - **Low Sensitivity (0.0-0.3)**: Intense activities with strong vibrations
  - **Medium Sensitivity (0.3-0.7)**: Standard cardio equipment
  - **High Sensitivity (0.7-1.0)**: Walking, gentle cycling, or low-impact activities with very subtle vibrations

## User Interface

### Location

The sensitivity settings are located in the Workout Setup screen, accessible via the settings button in the main workout view.

### Controls

Each sensitivity setting includes:
- A labeled slider control (0.0 to 1.0 in 0.1 increments)
- A visual indicator showing current level (Low/Medium/High)
- Descriptive text explaining what the setting controls

### Settings Persistence

- Settings are automatically saved when changed
- Settings are stored in the App Group UserDefaults
- Settings persist across app launches
- Backward compatible with older app versions (defaults to 0.5 if not set)

## Technical Details

### Data Model

The `WorkoutSettings` struct in `Models.swift` includes:

```swift
var repSensitivity: Double        // Rep detection sensitivity (0.0-1.0)
var vibrationSensitivity: Double  // Vibration detection sensitivity (0.0-1.0)
```

## Technical Details

### Data Model

The `WorkoutSettings` struct in `Models.swift` includes:

```swift
var repSensitivity: Double        // Rep detection sensitivity (0.0-1.0)
var vibrationSensitivity: Double  // Vibration detection sensitivity (0.0-1.0)
```

### Default Values

```swift
static let defaultRepSensitivity = 0.5
static let defaultVibrationSensitivity = 0.5
```

### Backward Compatibility

The implementation includes a custom `init(from decoder:)` that uses `decodeIfPresent` to handle old saved settings that don't have sensitivity values. Missing values default to 0.5 (medium sensitivity).

### Firmware Integration

**BLE Communication:**
- New characteristic UUID: `9c4a7f2e-5d3b-41a9-8f6e-2345678901bc`
- Message format: `"RepSens:0.5,VibSens:0.7"`
- Sent automatically on device connection and when settings change

**Threshold Calculation:**
The firmware maps 0.0-1.0 sensitivity values to actual detection thresholds:

```cpp
// Higher sensitivity (1.0) = lower thresholds (easier to detect)
// Lower sensitivity (0.0) = higher thresholds (harder to detect)

// Rep detection thresholds
repAccelThreshold = 0.5 - (sensitivity × 0.35)    // Range: 0.15g to 0.5g
repVelocityThreshold = 0.35 - (sensitivity × 0.25) // Range: 0.10m/s to 0.35m/s

// Vibration detection threshold
vibrationAccelThreshold = 0.25 - (sensitivity × 0.22) // Range: 0.03g to 0.25g
```

**Vibration Detection Timeout:**
- Time without detected vibration before marking activity as inactive: 5 seconds
- Helps accommodate brief pauses during continuous activities

**Real-time Updates:****
- Settings take effect immediately after BLE write
- No device restart required
- Previous detection state preserved

## Future Enhancements

Potential improvements for future versions:

1. **Per-Exercise Sensitivity**: Allow different sensitivity settings for each exercise in the workout
2. **Auto-Calibration**: Automatically adjust sensitivity based on detected movement patterns
3. **Preset Profiles**: Provide pre-configured sensitivity profiles for common exercise types
4. **Advanced Tuning**: Expose individual threshold parameters for power users
5. **Persistent Firmware Settings**: Save sensitivity to ESP32 flash memory to survive reboots

## Related Files

- `ios/esp32Connect/Models.swift` - Data model with sensitivity properties
- `ios/esp32Connect/SetupView.swift` - UI controls for adjusting sensitivity
- `ios/esp32Connect/BLEManager.swift` - BLE communication for sending settings
- `ios/esp32Connect/AppConfig.swift` - Characteristic UUID definitions
- `Firmware/src/esp1/main.cpp` - Firmware threshold handling and BLE callbacks

## See Also

- [REP_DETECTION.md](Firmware/REP_DETECTION.md) - Details on the rep detection algorithm
- [WORKOUT_FEATURE.md](WORKOUT_FEATURE.md) - Overview of the workout tracking feature
