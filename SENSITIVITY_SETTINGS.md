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
- **Use Cases**:
  - **Low Sensitivity (0.0-0.3)**: Intense activities with strong vibrations
  - **Medium Sensitivity (0.3-0.7)**: Standard cardio equipment
  - **High Sensitivity (0.7-1.0)**: Walking or low-impact activities with subtle vibrations

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

### Default Values

```swift
static let defaultRepSensitivity = 0.5
static let defaultVibrationSensitivity = 0.5
```

### Backward Compatibility

The implementation includes a custom `init(from decoder:)` that uses `decodeIfPresent` to handle old saved settings that don't have sensitivity values. Missing values default to 0.5 (medium sensitivity).

## Future Enhancements

Potential improvements for future versions:

1. **Firmware Integration**: Send sensitivity values to the ESP32 device via BLE to adjust hardware thresholds in real-time
2. **Per-Exercise Sensitivity**: Allow different sensitivity settings for each exercise in the workout
3. **Auto-Calibration**: Automatically adjust sensitivity based on detected movement patterns
4. **Preset Profiles**: Provide pre-configured sensitivity profiles for common exercise types
5. **Advanced Tuning**: Expose individual threshold parameters for power users

## Related Files

- `ios/esp32Connect/Models.swift` - Data model with sensitivity properties
- `ios/esp32Connect/SetupView.swift` - UI controls for adjusting sensitivity
- `Firmware/src/esp1/main.cpp` - Firmware thresholds (currently hardcoded)

## See Also

- [REP_DETECTION.md](Firmware/REP_DETECTION.md) - Details on the rep detection algorithm
- [WORKOUT_FEATURE.md](WORKOUT_FEATURE.md) - Overview of the workout tracking feature
