# ESP32 Connect - BLE IMU Data Monitor

**Version:** 3.0  
**Platform:** React Native (iOS & Android)

## Overview

ESP32 Connect is a **React Native application** that enables real-time monitoring of exercise rep counts from an ESP32 device via Bluetooth Low Energy (BLE). The app automatically scans for and connects to a device named "ESP32_IMU_Stream" and displays rep counting data in real-time.

## Features

- **Automatic device discovery** - Continuously scans for ESP32_IMU_Stream device
- **Auto-connect** - Automatically connects when target device is found
- **Single screen interface** - Simplified UI with no manual navigation needed
- **Real-time rep counting** - Displays exercise rep counts and state (UP/DOWN/IDLE)
- **Bidirectional communication** - Reset rep count from the app
- **Auto-reconnect** - Automatically retries connection if device disconnects
- **Comprehensive error handling** - User-friendly feedback for connection issues
- **Cross-platform** - Works on both iOS and Android

## Technology Stack

- **React Native** - Cross-platform mobile framework
- **React** 19.0 - Modern UI library
- **react-native-ble-plx** - BLE library for device communication
- **Expo** - Development and build toolchain

## App Architecture

### Single Screen Design
The app uses a single screen that handles:
1. **Auto-scanning** - Periodic BLE scanning for target device
2. **Auto-connection** - Automatic connection when device is found
3. **Data Display** - Real-time rep counter with state indicator

### Core Components
- **App.js** - Main app entry with permissions handling
- **DataDisplayScreen.js** - Single screen with auto-connect and data display
- **bleService.js** - BLE manager for device operations
- **appConfig.js** - Centralized configuration and constants

### Key Features
- **Automatic Connection** - No user interaction needed for scanning/connecting
- **Periodic Scanning** - Scans every 5 seconds when not connected
- **Single Screen UI** - Entire app in one view for simplicity
- **Error Recovery** - Automatic retry on connection failure

## ESP32 Requirements

Your ESP32 device should:

### Device Name
- **Name**: `ESP32_IMU_Stream` (exact match required for auto-connect)

### BLE Service
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

### Characteristics  
- **Rep Counter Characteristic**: First characteristic in the service
  - Recommended UUID: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`
  - Must support notifications/indications

### Data Format
The app expects rep counter data in this format:
```
Count:value,State:value
```
Example: `Count:5,State:UP` or `Count:12,State:DOWN`

Supported states: `UP`, `DOWN`, `IDLE`

## Installation & Setup

### Prerequisites
- Node.js 18+ and npm
- Expo CLI (`npm install -g expo-cli`)
- iOS: Xcode and CocoaPods (for iOS development)
- Android: Android Studio and SDK (for Android development)

### Installation
```bash
# Install dependencies
npm install

# For iOS (Mac only)
cd ios && pod install && cd ..

# Start the development server
npm start

# Run on iOS
npm run ios

# Run on Android
npm run android
```

## Usage

1. Launch the app
2. Grant Bluetooth permissions when prompted
3. The app will automatically scan for "ESP32_IMU_Stream"
4. When found, the app will automatically connect
5. Rep count data will display in real-time
6. Press "Reset Count" button to reset the counter to zero
7. If connection is lost, the app will automatically retry

The app requires no user interaction for scanning or connecting - it handles everything automatically!

## Configuration

Key configuration options in `config/appConfig.js`:

```javascript
// Target device name
const TARGET_DEVICE_NAME = 'ESP32_IMU_Stream';

// Scan interval when not connected (milliseconds)
const SCAN_INTERVAL = 5000; // 5 seconds

// BLE Service UUID
UUIDS: {
  IMU_SERVICE: '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
}
```

You can modify these values in the code if needed:
- Change `TARGET_DEVICE_NAME` in `screens/DataDisplayScreen.js` to match your device name
- Adjust `SCAN_INTERVAL` to change how frequently the app scans when disconnected

## Troubleshooting

**Device not found**: 
- Ensure your ESP32 device is powered on and advertising
- Verify the device name is exactly "ESP32_IMU_Stream"
- Check that Bluetooth is enabled on your phone

**Connection failed**: 
- Verify the ESP32 BLE service UUID matches `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Ensure the characteristic supports notifications
- Check that the device is in range

**Permission denied**: 
- Grant Bluetooth and location permissions in device settings
- On Android 12+, ensure BLUETOOTH_SCAN and BLUETOOTH_CONNECT are granted
- On Android 11 and below, ensure ACCESS_FINE_LOCATION is granted

**No data displayed**:
- Verify the ESP32 is sending data in the correct format: `Count:X,State:Y`
- Check the console logs for data parsing errors
- Ensure the characteristic has notifications enabled

## Development Notes

The app uses a simplified single-screen architecture:
- No navigation stack needed
- Auto-scan runs periodically in the background
- Auto-connect triggers when target device is found
- Connection state is managed automatically

All BLE communication is handled through the `bleService.js` module which wraps the `react-native-ble-plx` library.

For details on bidirectional communication and reset functionality, see [BIDIRECTIONAL_BLE.md](BIDIRECTIONAL_BLE.md).

## License

Proprietary software developed for BarbourSmith.

---

ESP32 Connect v3.0 - React Native Auto-Connect App
