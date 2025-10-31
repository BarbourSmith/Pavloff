# Pavloff Workout - Native Swift iOS App

**Version:** 2.1 (Workout Tracking)  
**Platform:** iOS 16.0+  
**Language:** Swift 5.0+ with SwiftUI

## Overview

Pavloff Workout is a native Swift iOS application designed for workout tracking using free weights with ESP32-based motion sensors. The app automatically tracks your reps through multiple exercises, providing real-time feedback and progression through your workout routine.

This is a complete native Swift rewrite of the original React Native application, providing better performance, native iOS UI/UX, and simplified architecture.

## 🆕 Workout Tracking Features

- **🏋️ Multi-Exercise Workouts**: Track progress through multiple exercises in sequence
- **📊 Real-Time Rep Counting**: Automatic rep detection with large, easy-to-read display
- **🎯 Customizable Targets**: Set target reps for each exercise (1-50 range)
- **➡️ Auto-Progression**: Automatically advances to next exercise when target reached
- **📈 Visual Progress**: Progress dots and bar show workout completion
- **🎉 Celebration Screen**: Congratulations display when workout is complete
- **⚙️ Mid-Workout Adjustments**: Change targets without losing progress
- **🔄 Quick Reset**: Restart current exercise with one tap
- **🔥 Streak Tracking**: Duolingo-style streak feature tracks consecutive workout days with milestone celebrations
- **🔒 App Blocking**: Block distracting apps until you complete your daily workout (requires iOS 16.0+)

See [WORKOUT_FEATURE.md](WORKOUT_FEATURE.md) for complete feature guide.
See [STREAK_FEATURE.md](STREAK_FEATURE.md) for streak tracking details.
See [SCREEN_TIME_FEATURE.md](SCREEN_TIME_FEATURE.md) for app blocking details.
See [MIDNIGHT_RELOCK_SETUP.md](MIDNIGHT_RELOCK_SETUP.md) for setting up automatic midnight re-locking.

## Core Features

- **Native iOS Experience**: Built entirely with SwiftUI for a smooth, native iOS experience
- **BLE Auto-Connect**: Automatic discovery and connection to ESP32 devices
- **Real-Time Data Monitoring**: Live display of rep count and movement state
- **Connection Management**: Automatic connection handling with status feedback
- **Clean Architecture**: Separation of concerns with dedicated managers, models, and views

## Technology Stack

- **SwiftUI**: Modern declarative UI framework for iOS
- **CoreBluetooth**: Native iOS framework for Bluetooth LE communication
- **Combine**: Reactive framework for handling asynchronous events
- **Swift**: Type-safe, modern programming language

## App Architecture

### Files Structure

```
ios/esp32Connect/
├── ESP32ConnectApp.swift          # Main app entry point
├── AppDelegate.swift               # App lifecycle delegate
├── SceneDelegate.swift             # Scene lifecycle delegate
├── AppConfig.swift                 # Configuration constants
├── Models.swift                    # Data models (including Exercise & WorkoutSettings)
├── BLEManager.swift                # Bluetooth LE manager
├── WorkoutView.swift               # 🆕 Main workout tracking screen
├── SetupView.swift                 # 🆕 Exercise configuration screen
├── CongratulationsView.swift      # 🆕 Workout completion screen
├── AutoConnectDataDisplayView.swift # Legacy auto-connect view
├── HomeView.swift                  # Device scanning screen
├── ConnectionView.swift            # Connection status screen
└── DataDisplayView.swift           # Data display screen
```

### Key Components

#### 1. **Workout System** 🆕
Main workout tracking functionality:
- **WorkoutView**: Primary screen for workout tracking with auto-progression
- **SetupView**: Configuration screen for setting exercise targets
- **CongratulationsView**: Celebration screen on workout completion
- **Exercise Model**: Represents individual exercises with target reps
- **WorkoutSettings Model**: Manages workout configuration

#### 2. **BLEManager**
Central manager for all Bluetooth operations:
- Device scanning and discovery
- Connection management
- Service and characteristic discovery
- Real-time data parsing and updates
- Rep count tracking and reset functionality

#### 3. **Views**
- **WorkoutView**: Main workout tracking interface (default screen)
- **SetupView**: Exercise configuration and target setting
- **CongratulationsView**: Workout completion celebration
- **HomeView**: Device scanning and selection interface (legacy)
- **ConnectionView**: Shows connection progress for selected devices (legacy)
- **DataDisplayView**: Real-time display of IMU sensor data (legacy)

#### 4. **Models**
- **Exercise**: Represents a workout exercise with name and target reps
- **WorkoutSettings**: Manages collection of exercises with defaults
- **BLEDevice**: Represents a discovered BLE device
- **SensorData**: Contains parsed sensor data (count and state)
- **DeviceData**: Aggregates all data for a connected device
- **ConnectionStatus**: Tracks device connection state

## ESP32 Requirements

Your ESP32 device must implement the following BLE service and characteristics for workout tracking:

### BLE Service UUID
```
4fafc201-1fb5-459e-8fcc-c5c9c331914b
```

### Characteristics
- **Rep Counter**: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`

The characteristic must support **notify** operations.

### Data Format
The app expects rep counting data in comma-separated format:
```
Count:value,State:value
```

Example: `Count:5,State:UP`

**States**:
- `UP`: Upward motion detected
- `DOWN`: Downward motion detected
- `IDLE`: No significant motion

## Building and Running

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- iOS device running iOS 16.0 or later (BLE requires a physical device)

### Build Instructions

1. **Open the project**:
   ```bash
   cd ios
   open esp32Connect.xcodeproj
   ```

2. **Select your target**:
   - In Xcode, select a physical iOS device (not simulator)
   - BLE functionality requires a physical device for testing

3. **Update signing**:
   - Select the esp32Connect target
   - Go to "Signing & Capabilities"
   - Select your development team

4. **Build and run**:
   - Press Cmd+R or click the Run button
   - The app will build and install on your device

### Configuration

Key configuration options are in `AppConfig.swift`:

```swift
struct BLE {
    static let scanTimeout: TimeInterval = 10.0
    static let connectionTimeout: TimeInterval = 15.0
    static let maxRetryAttempts = 3
}

struct Devices {
    static let maxSelectableDevices = 2
    static let minSelectableDevices = 1
}
```

## Usage

### 🏋️ Workout Tracking Mode (Default)

1. **Launch the app**
   - App opens directly to the Workout Screen
   - Automatically scans for ESP32 device named "Pavloff Workout Sensor"

2. **Configure your workout (optional)**
   - Tap "Workout Settings" to adjust target reps
   - Set targets for each exercise (1-50 reps)
   - Tap "Start Workout" to return

3. **Perform your workout**
   - Exercise name and progress dots show your position
   - Large counter displays current/target reps (e.g., "5 / 10")
   - Progress bar fills as you complete reps
   - App automatically advances to next exercise when target reached

4. **Complete workout**
   - Congratulations screen appears after last exercise
   - View workout summary
   - Tap "Start New Workout" to do another set

5. **Mid-workout controls**
   - Tap "Reset Exercise" to restart current exercise
   - Tap "Workout Settings" to adjust targets

For detailed usage guide, see [WORKOUT_FEATURE.md](WORKOUT_FEATURE.md).

### 📱 Legacy Device Management Mode

1. **Launch the app**
   - Grant Bluetooth permissions when prompted

2. **Scan for devices**
   - Tap "Scan for Devices" to start discovering ESP32 devices
   - Scanning will automatically stop after 10 seconds

3. **Select devices**
   - Tap on 1 or 2 devices to select them
   - Selected devices are highlighted in blue

4. **Connect**
   - Tap "Proceed to Connect" to connect to selected devices
   - Connection progress is shown for each device

5. **View data**
   - Once connected, tap "Show Data" to see real-time IMU readings
   - Data updates automatically as it's received from devices

6. **Stop monitoring**
   - Tap "Stop Monitoring" to disconnect and return to scanning

## Troubleshooting

### No devices found
- Ensure your ESP32 devices are powered on
- Verify they're advertising the BLE service with correct UUID
- Make sure Bluetooth is enabled on your iOS device

### Connection fails
- Check that the ESP32 is still advertising
- Verify the IMU service UUID matches: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Try power cycling the ESP32 device

### No data displayed
- Ensure characteristics support notify operations
- Verify data format: `X:value,Y:value,Z:value`
- Check ESP32 logs for transmission errors

### Bluetooth permission denied
- Go to Settings > Privacy & Security > Bluetooth
- Enable Bluetooth access for Pavloff Workout

## Development Notes

### Adding More Devices
To support more than 2 devices, update in `AppConfig.swift`:
```swift
static let maxSelectableDevices = 4  // or your desired number
```

### Customizing UUIDs
If your ESP32 uses different UUIDs, update in `AppConfig.swift`:
```swift
struct UUIDs {
    static let imuService = "your-service-uuid"
    static let accelCharacteristic = "your-accel-uuid"
    static let gyroCharacteristic = "your-gyro-uuid"
}
```

### UI Customization
All views are built with SwiftUI and can be easily customized:
- Colors and styling in view files
- Layout in SwiftUI view structs
- Navigation flow in NavigationStack

## Migration from React Native

This app replaces the previous React Native implementation with a native Swift application:

### Benefits
- **Better Performance**: Native Swift code runs faster than JavaScript bridge
- **Smaller App Size**: No React Native framework bundled
- **Native UI**: True iOS look and feel with SwiftUI
- **Simpler Build**: No Node.js, npm, or Metro bundler required
- **Better Debugging**: Native Xcode debugging tools

### Key Differences
- Pure Swift/SwiftUI instead of React/JavaScript
- CoreBluetooth instead of react-native-ble-plx
- Native iOS navigation instead of React Navigation
- Xcode-only build process (no npm/node required)

## Documentation

### Workout Tracking Features
- **[WORKOUT_FEATURE.md](WORKOUT_FEATURE.md)**: Complete user guide with quick start, tips, and troubleshooting
- **[STREAK_FEATURE.md](STREAK_FEATURE.md)**: Streak tracking feature guide with logic and milestones
- **[TEST_PLAN.md](TEST_PLAN.md)**: Comprehensive testing guide with test cases and workflows
- **[WORKOUT_SCREENS.md](WORKOUT_SCREENS.md)**: Visual mockups and screen flow diagrams
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)**: Technical architecture and implementation details
- **[FEATURE_SUMMARY.md](FEATURE_SUMMARY.md)**: Executive summary and requirements fulfillment

### Screen Time & App Blocking
- **[SCREEN_TIME_FEATURE.md](SCREEN_TIME_FEATURE.md)**: App blocking feature overview
- **[SCREEN_TIME_DEV_GUIDE.md](SCREEN_TIME_DEV_GUIDE.md)**: Developer guide for Screen Time API
- **[SCREEN_TIME_UI.md](SCREEN_TIME_UI.md)**: UI design and implementation details
- **[MIDNIGHT_RELOCK_SETUP.md](MIDNIGHT_RELOCK_SETUP.md)**: 🆕 Setup guide for automatic midnight re-locking
- **[MIDNIGHT_RELOCK_SOLUTION_SUMMARY.md](MIDNIGHT_RELOCK_SOLUTION_SUMMARY.md)**: 🆕 Technical solution summary
- **[MIDNIGHT_RELOCK_ARCHITECTURE.md](MIDNIGHT_RELOCK_ARCHITECTURE.md)**: 🆕 Architecture diagrams and data flows

### Original Documentation
- **[SCREEN_LAYOUTS.md](SCREEN_LAYOUTS.md)**: Legacy screen designs for device management mode
- **Firmware docs**: See `/Firmware` directory for ESP32 implementation guides

## Requirements

- **Minimum iOS Version**: 16.0
- **Device**: Physical iOS device (BLE not available in simulator)
- **Bluetooth**: BLE 4.0 or later
- **Permissions**: Bluetooth usage must be granted
- **ESP32**: Device named "Pavloff Workout Sensor" for workout tracking

## License

Proprietary software developed for BarbourSmith.

---

Pavloff Workout v2.1 - Workout Tracking Edition - Native Swift iOS App
