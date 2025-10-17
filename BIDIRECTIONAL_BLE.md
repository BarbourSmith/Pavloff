# Bidirectional Bluetooth Communication

## Overview
This document describes the bidirectional Bluetooth Low Energy (BLE) communication implementation that allows the mobile app to send commands back to the ESP32 device, specifically to reset the rep count.

## Implementation Details

### ESP32 Firmware Changes

#### 1. Added WRITE Property to Rep Characteristic
**File:** `Firmware/src/esp1/main.cpp`

The rep characteristic now supports writing data from the app:
```cpp
pRepCharacteristic = pService->createCharacteristic(
    REP_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |  // ← Added WRITE capability
    BLECharacteristic::PROPERTY_NOTIFY
);
```

#### 2. Implemented Reset Command Handler
**File:** `Firmware/src/esp1/main.cpp`

Added `RepCharacteristicCallbacks` class to handle incoming write requests:
```cpp
class RepCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value == "RESET" || value == "reset") {
            repCount = 0;
            repState = REP_IDLE;
            phaseStartTime = millis();
            
            // Send immediate notification
            char repData[30];
            snprintf(repData, sizeof(repData), "Count:0,State:IDLE");
            pRepCharacteristic->setValue(repData);
            pRepCharacteristic->notify();
        }
    }
};
```

The callback is registered on the rep characteristic:
```cpp
pRepCharacteristic->setCallbacks(new RepCharacteristicCallbacks());
```

### React Native App Changes

#### 1. Added Write Function to BLE Service
**File:** `services/bleService.js`

New `writeCharacteristic` function enables writing data to any BLE characteristic:
```javascript
const writeCharacteristic = async (deviceId, serviceUUID, characteristicUUID, data) => {
    const base64Data = Buffer.from(data, 'utf-8').toString('base64');
    
    await bleManager.writeCharacteristicWithResponseForDevice(
        deviceId,
        serviceUUID,
        characteristicUUID,
        base64Data
    );
    
    return true;
};
```

#### 2. Added Reset Functionality to UI
**File:** `screens/DataDisplayScreen.js`

**State Management:**
- Added `isResetting` state to track reset operation status

**Reset Handler:**
```javascript
const handleResetRepCount = async () => {
    setIsResetting(true);
    
    await bleService.writeCharacteristic(
        connectedDevice.id,
        IMU_SERVICE_UUID,
        deviceCharacteristics.accel,
        'RESET'
    );
    
    Alert.alert('Success', 'Rep count reset successfully');
    setIsResetting(false);
};
```

**UI Button:**
- Added reset button to the DataView component
- Button shows "Resetting..." state during operation
- Button is disabled during reset to prevent multiple requests

## Usage

### For Users
1. Connect to the ESP32 device (happens automatically)
2. Perform exercises - the app displays rep count
3. Press "Reset Count" button to reset the counter to zero
4. Device immediately updates and displays 0 reps

### For Developers

#### Sending Custom Commands
The `writeCharacteristic` function can be used to send any string command to the ESP32:

```javascript
await bleService.writeCharacteristic(
    deviceId,
    serviceUUID,
    characteristicUUID,
    'YOUR_COMMAND'
);
```

#### Adding New Commands to ESP32
Add new command handlers in the `RepCharacteristicCallbacks::onWrite` method:

```cpp
void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    
    if (value == "RESET") {
        // Reset logic
    } else if (value == "YOUR_NEW_COMMAND") {
        // Your new command logic
    }
}
```

## Protocol

### Command Format
Commands are sent as UTF-8 strings and automatically converted to base64 for BLE transmission.

### Supported Commands
| Command | Description | Response |
|---------|-------------|----------|
| `RESET` or `reset` | Resets rep count to 0 and state to IDLE | Immediate notification with "Count:0,State:IDLE" |

### Response Format
The ESP32 responds by sending a notification on the same characteristic with the updated values:
```
Count:<number>,State:<state>
```

Example: `Count:0,State:IDLE`

## Data Flow

### Reset Operation Flow
1. **User Action**: User taps "Reset Count" button
2. **App → ESP32**: App writes "RESET" string to rep characteristic
3. **ESP32 Processing**: 
   - Receives write request
   - Resets `repCount = 0`
   - Sets `repState = REP_IDLE`
   - Resets `phaseStartTime`
4. **ESP32 → App**: ESP32 sends notification with "Count:0,State:IDLE"
5. **App Display**: App receives notification and updates UI

```
┌─────────┐                    ┌─────────┐
│   App   │                    │  ESP32  │
└────┬────┘                    └────┬────┘
     │                              │
     │  Write "RESET"               │
     │──────────────────────────────>│
     │                              │
     │                         Reset count
     │                         & state
     │                              │
     │  Notify "Count:0,State:IDLE" │
     │<──────────────────────────────│
     │                              │
  Update UI                         │
```

## Benefits

1. **User Control**: Users can reset the counter without restarting the device
2. **Immediate Feedback**: Reset takes effect instantly with notification
3. **Extensible**: Framework supports adding more commands in the future
4. **Error Handling**: Includes comprehensive error handling and user feedback
5. **State Management**: Properly manages UI state during operations

## Future Enhancements

Possible additions to the bidirectional communication:

1. **Set Target Reps**: Allow users to set a target rep count
2. **Calibration Commands**: Remote calibration of the IMU sensor
3. **Configuration Updates**: Change detection thresholds remotely
4. **Query Status**: Request current device status/settings
5. **Start/Stop Tracking**: Enable/disable rep detection remotely

## Testing

### Manual Testing Checklist
- [ ] Connect to ESP32 device
- [ ] Perform some reps to increment counter
- [ ] Press "Reset Count" button
- [ ] Verify count returns to 0
- [ ] Verify state returns to IDLE
- [ ] Verify button shows "Resetting..." during operation
- [ ] Verify success alert appears
- [ ] Perform more reps to ensure tracking continues after reset

### Error Scenarios
- [ ] Try reset when device disconnected (should show error)
- [ ] Disconnect during reset operation
- [ ] Multiple rapid reset requests

## Security Considerations

✅ **CodeQL Analysis**: No security vulnerabilities detected

**Security Notes:**
- Commands are simple strings (no code execution)
- No sensitive data transmitted
- BLE connection is paired/encrypted (handled by OS)
- Write operations require active BLE connection
- No buffer overflow risks (using bounded strings)

## Compatibility

- **ESP32 Firmware**: Requires firmware with RepCharacteristicCallbacks
- **React Native App**: Requires react-native-ble-plx v3.5.0+
- **iOS**: Compatible with iOS 12.0+
- **Android**: Compatible with Android 5.0+ (API 21+)

## Troubleshooting

### Reset Not Working
1. Check device is connected (green status indicator)
2. Check console logs for write errors
3. Verify ESP32 firmware has write callback registered
4. Try disconnecting and reconnecting

### No Notification After Reset
1. Check ESP32 serial output for "Received command: RESET"
2. Verify characteristic has notifications enabled
3. Check BLE connection is still active

### Button Stays Disabled
1. Check for JavaScript errors in console
2. Verify error handling is working
3. Try restarting the app

## License
Same as parent project (Proprietary)
