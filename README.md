# ESP32 Connect - BLE IMU Data Monitor

**Version:** 1.0  
**Developed for:** bars50  

## Overview

ESP32 Connect is a React Native mobile application that enables real-time monitoring of IMU (Inertial Measurement Unit) sensor data from ESP32 devices via Bluetooth Low Energy (BLE). The app can simultaneously connect to and monitor data from up to 2 ESP32 devices, displaying accelerometer and gyroscope readings in real-time.

## Features

- Device scanning and discovery of ESP32 BLE devices
- Multi-device support (connect to up to 2 devices simultaneously)  
- Real-time accelerometer and gyroscope data monitoring
- Start/stop monitoring controls with proper cleanup
- Dynamic characteristic discovery for different ESP32 configurations
- Comprehensive error handling and user feedback
- Cross-platform Bluetooth permission management

## Technology Stack

### Core Framework
- **React Native** 0.79.5 - Cross-platform mobile development
- **Expo** ~53.0.17 - Development platform and toolchain
- **React** 19.0.0 - UI library

### Navigation
- **@react-navigation/native** ^7.1.14 - Navigation framework
- **@react-navigation/stack** ^7.4.2 - Stack navigation
- **react-native-screens** ^4.11.1 - Native screen management
- **react-native-safe-area-context** ^5.5.1 - Safe area handling

### Bluetooth & Permissions
- **react-native-ble-plx** ^3.5.0 - Bluetooth Low Energy communication
- **react-native-permissions** ^5.4.1 - Runtime permission management

### Gesture & Interaction
- **react-native-gesture-handler** ^2.27.1 - Touch gesture system

## App Architecture

### Screen Structure
1. **HomeScreen** - Device scanning and selection
2. **ConnectionScreen** - Device connection and service discovery  
3. **DataDisplayScreen** - Real-time sensor data monitoring

### Core Services
- **bleService.js** - Abstraction layer for all BLE operations
- **appConfig.js** - Centralized configuration and constants

### Key Components
- **Error Boundary** - App-level error handling
- **Platform-Specific Permissions** - iOS/Android permission management
- **Multi-Device Data Management** - Concurrent device monitoring

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
- Node.js 16+
- npm or yarn
- Expo CLI
- iOS: Xcode (for iOS development)
- Android: Android Studio (for Android development)

### Installation
```bash
# Install dependencies
npm install

# Install iOS pods (iOS only)
cd ios && pod install && cd ..
```

### Development
```bash

# Run on iOS
npx react-native run-ios

# Run on Android  
npx react-native run-android
```

## Platform Support

**iOS (15.1+)**
- Full BLE support
- Automatic permission handling via Info.plist
- Native iOS UI elements

**Android (API 21+)**
- Full BLE support  
- Runtime permission management
- Support for Android 12+ BLE permissions

## Configuration

Key configuration options in `config/appConfig.js`:

```javascript
BLE: {
  SCAN_TIMEOUT: 10000,      // Device scan timeout (ms)
  CONNECTION_TIMEOUT: 15000, // Connection timeout (ms)
  MONITORING_DELAY: 250,     // Monitoring start delay (ms)
}

DEVICES: {
  MAX_SELECTABLE_DEVICES: 2, // Maximum concurrent devices
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

The app uses React hooks for state management and includes comprehensive error handling for BLE operations. All BLE communication is abstracted through the bleService module for maintainability.

## License

Proprietary software developed for bars50.

---

ESP32 Connect v1.0
