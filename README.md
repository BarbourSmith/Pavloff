# ESP32 Connect - BLE IMU Data Monitor

**Version:** 2.0  
**Platform:** Native Swift iOS App

## Overview

ESP32 Connect is a **native Swift iOS application** that enables real-time monitoring of IMU (Inertial Measurement Unit) sensor data from ESP32 devices via Bluetooth Low Energy (BLE). The app can simultaneously connect to and monitor data from up to 2 ESP32 devices, displaying accelerometer and gyroscope readings in real-time.

> **Note**: This app has been completely rewritten as a native Swift iOS app using SwiftUI and CoreBluetooth. The previous React Native implementation has been replaced with pure Swift code for better performance and native iOS experience.

## Features

- Device scanning and discovery of ESP32 BLE devices
- Multi-device support (connect to up to 2 devices simultaneously)  
- Real-time accelerometer and gyroscope data monitoring
- Start/stop monitoring controls with proper cleanup
- Dynamic characteristic discovery for different ESP32 configurations
- Comprehensive error handling and user feedback
- Cross-platform Bluetooth permission management

## Technology Stack

- **Swift** 5.0+ - Modern, type-safe programming language
- **SwiftUI** - Declarative UI framework for native iOS
- **CoreBluetooth** - Native iOS Bluetooth LE framework
- **Combine** - Reactive framework for async operations

## App Architecture

### View Structure
1. **HomeView** - Device scanning and selection
2. **ConnectionView** - Device connection and service discovery  
3. **DataDisplayView** - Real-time sensor data monitoring

### Core Components
- **BLEManager.swift** - Central manager for all Bluetooth LE operations
- **AppConfig.swift** - Centralized configuration and constants
- **Models.swift** - Data models for devices and sensor data

### Key Features
- **Native SwiftUI Interface** - Modern, declarative UI with native iOS components
- **CoreBluetooth Integration** - Direct iOS BLE API for optimal performance
- **Reactive Data Flow** - Combine framework for real-time updates

## ESP32 Requirements

Your ESP32 devices should implement:

### BLE Service
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

### Characteristics  
- **Accelerometer**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Gyroscope**: `beb5483e-36e1-4688-b7f5-ea07361b26a9`

### Data Format
The app expects sensor data in comma-separated format:
```
X:value,Y:value,Z:value
```
Example: `X:0.12,Y:-0.45,Z:9.81`

## Installation & Setup

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- iOS device running iOS 15.0+ (physical device required for BLE)

### Building
```bash
# Open the Xcode project
cd ios
open esp32Connect.xcodeproj

# In Xcode:
# 1. Select a physical iOS device (not simulator)
# 2. Configure signing with your development team
# 3. Build and run (Cmd+R)
```

> **Important**: Bluetooth LE functionality requires a physical iOS device. The iOS simulator does not support CoreBluetooth.

## Platform Support

**iOS (15.0+)**
- Native Swift/SwiftUI application
- Full CoreBluetooth support
- Automatic permission handling via Info.plist
- Optimized for iPhone and iPad

## Configuration

Key configuration options in `ios/esp32Connect/AppConfig.swift`:

```swift
struct BLE {
    static let scanTimeout: TimeInterval = 10.0
    static let connectionTimeout: TimeInterval = 15.0
    static let maxRetryAttempts = 3
}

struct Devices {
    static let maxSelectableDevices = 2
}
```

## Usage

1. Launch app and grant Bluetooth permissions when prompted
2. Tap "Scan for Devices" to discover ESP32 devices
3. Select 1-2 devices from the list
4. Tap "Proceed to Connect" to establish connections
5. View real-time IMU data on the monitoring screen
6. Tap "Stop Monitoring" to disconnect and return to scanning

## Troubleshooting

**No devices found**: Ensure your ESP32 devices are powered on and advertising the BLE service.

**Connection failed**: Verify the ESP32 BLE service is running with the correct UUIDs.

**Permission denied**: Grant Bluetooth and location permissions in device settings.

**iOS testing**: BLE functionality requires testing on physical devices (not simulator).

## Development Notes

The app uses SwiftUI for the user interface with the Combine framework for reactive state management. All BLE communication is handled through the BLEManager class which implements CoreBluetooth delegates for device discovery, connection, and data monitoring.

For detailed information about the Swift implementation, see [SWIFT_APP_README.md](SWIFT_APP_README.md).

## Migration from React Native

This app was completely rewritten from React Native to native Swift:

### Benefits of Native Swift
- **Better Performance**: Native code with no JavaScript bridge overhead
- **Smaller App Size**: No React Native framework bundled
- **Native UI/UX**: True iOS look and feel with SwiftUI
- **Simpler Build Process**: No Node.js, npm, or Metro bundler required
- **Better Debugging**: Native Xcode debugging and profiling tools
- **Improved BLE Performance**: Direct CoreBluetooth API access

### What Changed
- Pure Swift/SwiftUI instead of React/JavaScript
- CoreBluetooth instead of react-native-ble-plx
- Native iOS navigation instead of React Navigation
- Xcode-only build (no npm dependencies)

## License

Proprietary software developed for BarbourSmith.

---

ESP32 Connect v2.0 - Native Swift iOS App
