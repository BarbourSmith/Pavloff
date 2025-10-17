# ESP32 Connect - Native Swift iOS App

**Version:** 2.0  
**Platform:** iOS 15.0+  
**Language:** Swift 5.0+ with SwiftUI

## Overview

ESP32 Connect is a native Swift iOS application that enables real-time monitoring of IMU (Inertial Measurement Unit) sensor data from ESP32 devices via Bluetooth Low Energy (BLE). The app can simultaneously connect to and monitor data from up to 2 ESP32 devices, displaying accelerometer and gyroscope readings in real-time.

This is a complete native Swift rewrite of the original React Native application, providing better performance, native iOS UI/UX, and simplified architecture.

## Features

- **Native iOS Experience**: Built entirely with SwiftUI for a smooth, native iOS experience
- **BLE Device Scanning**: Automatic discovery of ESP32 BLE devices broadcasting IMU data
- **Multi-Device Support**: Connect and monitor up to 2 devices simultaneously
- **Real-Time Data Monitoring**: Live display of accelerometer and gyroscope readings
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
├── ESP32ConnectApp.swift      # Main app entry point
├── AppDelegate.swift           # App lifecycle delegate
├── SceneDelegate.swift         # Scene lifecycle delegate
├── AppConfig.swift             # Configuration constants
├── Models.swift                # Data models
├── BLEManager.swift            # Bluetooth LE manager
├── HomeView.swift              # Device scanning screen
├── ConnectionView.swift        # Connection status screen
└── DataDisplayView.swift       # Data display screen
```

### Key Components

#### 1. **BLEManager**
Central manager for all Bluetooth operations:
- Device scanning and discovery
- Connection management
- Service and characteristic discovery
- Real-time data parsing and updates

#### 2. **Views**
- **HomeView**: Device scanning and selection interface
- **ConnectionView**: Shows connection progress for selected devices
- **DataDisplayView**: Real-time display of IMU sensor data

#### 3. **Models**
- **BLEDevice**: Represents a discovered BLE device
- **SensorData**: Contains parsed accelerometer/gyroscope data
- **DeviceData**: Aggregates all data for a connected device
- **ConnectionStatus**: Tracks device connection state

## ESP32 Requirements

Your ESP32 devices must implement the following BLE service and characteristics:

### BLE Service UUID
```
4fafc201-1fb5-459e-8fcc-c5c9c331914b
```

### Characteristics
- **Accelerometer**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Gyroscope**: `beb5483e-36e1-4688-b7f5-ea07361b26a9`

Both characteristics must support **notify** operations.

### Data Format
The app expects sensor data in comma-separated format:
```
X:value,Y:value,Z:value
```

Example: `X:0.12,Y:-0.45,Z:9.81`

## Building and Running

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- iOS device running iOS 15.0 or later (BLE requires a physical device)

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
- Enable Bluetooth access for ESP32 Connect

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

## Requirements

- **Minimum iOS Version**: 15.0
- **Device**: Physical iOS device (BLE not available in simulator)
- **Bluetooth**: BLE 4.0 or later
- **Permissions**: Bluetooth usage must be granted

## License

Proprietary software developed for BarbourSmith.

---

ESP32 Connect v2.0 - Native Swift iOS App
