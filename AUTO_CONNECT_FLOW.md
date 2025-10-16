# Auto-Connect Flow Documentation

## Overview
The app now uses a simplified single-screen architecture with automatic device discovery and connection. No user interaction is required for scanning or connecting to the ESP32 device.

## App Flow

```
┌─────────────────────────────────────┐
│         App Launches                │
│  - Request BLE Permissions          │
│  - Initialize DataDisplayScreen     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│     Auto-Scan Begins                │
│  - Scan for "ESP32_IMU_Stream"      │
│  - Show "Scanning..." status        │
└──────────────┬──────────────────────┘
               │
               ▼
        ┌──────┴──────┐
        │             │
        ▼             ▼
   Device         Device Not
   Found          Found
        │             │
        │             ▼
        │      ┌──────────────────┐
        │      │ Wait 5 seconds   │
        │      │ Retry scan       │
        │      └────────┬─────────┘
        │               │
        │               └─────────┐
        ▼                         │
┌─────────────────────────────────┴───┐
│     Auto-Connect                    │
│  - Stop scanning                    │
│  - Connect to device                │
│  - Discover services                │
│  - Identify characteristics         │
└──────────────┬──────────────────────┘
               │
         ┌─────┴─────┐
         │           │
         ▼           ▼
    Success      Failure
         │           │
         │           ▼
         │    ┌──────────────────┐
         │    │ Show error       │
         │    │ Resume scanning  │
         │    └────────┬─────────┘
         │             │
         │             └─────────┐
         ▼                       │
┌─────────────────────────────────────┤
│     Monitor Data                    │
│  - Subscribe to characteristics     │
│  - Display rep count & state        │
│  - Show "Connected" status          │
└──────────────┬──────────────────────┘
               │
               ▼
     ┌─────────────────┐
     │ Connection Lost?│
     └────┬─────────┬──┘
          │         │
         NO        YES
          │         │
          │         ▼
          │  ┌──────────────────┐
          │  │ Disconnect       │
          │  │ Resume scanning  │
          │  └────────┬─────────┘
          │           │
          └───────────┘
```

## Key Components

### 1. Periodic Scanning
- **Trigger**: When app launches or connection is lost
- **Frequency**: Every 5 seconds
- **Target**: Device named exactly "ESP32_IMU_Stream"
- **Timeout**: 10 seconds per scan attempt

### 2. Auto-Connection
- **Trigger**: When target device is found during scan
- **Process**:
  1. Stop scanning
  2. Connect to device
  3. Discover IMU service (UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`)
  4. Identify characteristics (uses first characteristic for rep counter)
  5. Start monitoring

### 3. Data Monitoring
- **What**: Rep counter data in format `Count:X,State:Y`
- **Display**: Large rep counter with colored state indicator
- **States**: UP (green), DOWN (blue), IDLE (gray)

### 4. Error Handling
- **Connection Failed**: Automatically resumes scanning
- **Monitoring Error**: Disconnects and resumes scanning
- **Device Not Found**: Continuously retries every 5 seconds

## Configuration Constants

Located in `screens/DataDisplayScreen.js`:

```javascript
const TARGET_DEVICE_NAME = 'ESP32_IMU_Stream';  // Exact device name to look for
const SCAN_INTERVAL = 5000;                      // Milliseconds between scans
```

Located in `services/bleService.js`:

```javascript
CONFIG = {
  SCAN_TIMEOUT: 10000,           // Stop scan after 10 seconds
  CONNECTION_TIMEOUT: 15000,     // Connection timeout
  MAX_RETRY_ATTEMPTS: 3,         // Retry attempts for operations
  MONITORING_DELAY: 250,         // Delay before starting monitoring
}
```

## User Experience

1. **App Launch**: User sees "Scanning for ESP32_IMU_Stream..." message
2. **Scanning**: Loading indicator shows scanning is in progress
3. **Device Found**: Status changes to "Connecting to ESP32_IMU_Stream..."
4. **Connected**: Large rep counter appears with current count and state
5. **Disconnection**: Automatically starts scanning again

## No User Actions Required

The app is designed to require **zero user interaction** for:
- ✓ Scanning for devices
- ✓ Connecting to the target device
- ✓ Reconnecting if connection is lost
- ✓ Handling errors and retrying

Users simply launch the app and wait for the device to be found and connected.

## Removed Features

The following features from the previous version have been removed:
- ❌ Manual scan button
- ❌ Device selection screen
- ❌ Connection progress screen
- ❌ Stop monitoring button
- ❌ Navigation between screens
- ❌ Multi-device support

The app now operates as a **single-purpose, auto-connecting rep counter display**.
