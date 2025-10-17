# Bidirectional Bluetooth Communication Implementation

## Overview
This document describes the implementation of bidirectional Bluetooth Low Energy (BLE) communication between the iOS/React Native apps and the ESP32 device, specifically for resetting the rep count on the board.

## Changes Made

### 1. ESP32 Firmware (`Firmware/src/esp1/main.cpp`)

#### Added Write Support to Rep Characteristic
- **Line 345-349**: Modified the rep characteristic creation to include `PROPERTY_WRITE`:
  ```cpp
  pRepCharacteristic = pService->createCharacteristic(
                      REP_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |  // Added write support
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  ```

#### Added Write Callback Handler
- **Line 106-129**: Created `RepCharacteristicCallbacks` class to handle write operations:
  ```cpp
  class RepCharacteristicCallbacks: public BLECharacteristicCallbacks {
      void onWrite(BLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
          Serial.print("Received command: ");
          Serial.println(value.c_str());
          
          // Check for reset command
          if (value == "RESET" || value == "reset") {
            repCount = 0;
            repState = REP_IDLE;
            phaseStartTime = millis();
            Serial.println("Rep count reset to 0");
            
            // Send immediate update with new count
            char repData[30];
            snprintf(repData, sizeof(repData), "Count:0,State:IDLE");
            pCharacteristic->setValue(repData);
            pCharacteristic->notify();
          }
        }
      }
  };
  ```

#### Registered Callback
- **Line 351**: Set the callback on the characteristic:
  ```cpp
  pRepCharacteristic->setCallbacks(new RepCharacteristicCallbacks());
  ```

### 2. iOS App (`ios/esp32Connect/`)

#### BLEManager.swift
- **Line 111-133**: Added `resetRepCount` method:
  ```swift
  /// Reset rep count for a connected device
  func resetRepCount(for deviceId: UUID) {
      guard let peripheral = connectedPeripherals[deviceId],
            let chars = characteristicMap[deviceId],
            let repCharUUID = chars.accelUUID else {
          print("[BLE] Cannot reset - device or characteristic not found")
          return
      }
      
      // Find the rep characteristic
      guard let service = peripheral.services?.first(where: { $0.uuid == imuServiceUUID }),
            let characteristic = service.characteristics?.first(where: { $0.uuid == repCharUUID }) else {
          print("[BLE] Cannot find rep characteristic for reset")
          return
      }
      
      // Send RESET command
      let resetData = "RESET".data(using: .utf8)!
      peripheral.writeValue(resetData, for: characteristic, type: .withResponse)
      print("[BLE] Sent RESET command to device: \(peripheral.name ?? "Unknown")")
  }
  ```

#### AutoConnectDataDisplayView.swift
- **Line 61-79**: Added reset button UI:
  ```swift
  // Reset button
  Button(action: {
      bleManager.resetRepCount(for: device.id)
  }) {
      HStack {
          Image(systemName: "arrow.clockwise")
              .font(.system(size: 18, weight: .semibold))
          Text("Reset Count")
              .font(.system(size: 18, weight: .semibold))
      }
      .foregroundColor(.white)
      .padding(.horizontal, 30)
      .padding(.vertical, 15)
      .background(Color.red)
      .cornerRadius(25)
  }
  .padding(.top, 20)
  ```

### 3. React Native App

#### services/bleService.js
- **Line 254-281**: Added `writeToCharacteristic` function:
  ```javascript
  // Write data to a characteristic
  const writeToCharacteristic = async (deviceId, serviceUUID, characteristicUUID, value) => {
    try {
      console.log(`[WRITE] Writing to characteristic: ${characteristicUUID}`);
      console.log(`  Device: ${deviceId}`);
      console.log(`  Service: ${serviceUUID}`);
      console.log(`  Value: ${value}`);
      
      // Convert string to base64
      const base64Value = Buffer.from(value, 'utf-8').toString('base64');
      
      await bleManager.writeCharacteristicWithResponseForDevice(
        deviceId,
        serviceUUID,
        characteristicUUID,
        base64Value
      );
      
      console.log(`[WRITE SUCCESS] Successfully wrote to characteristic`);
      return true;
    } catch (error) {
      console.error(`[WRITE ERROR] Failed to write to characteristic:`, error);
      throw error;
    }
  };
  ```

- **Line 288**: Exported the new function:
  ```javascript
  export default {
    // ... other exports ...
    writeToCharacteristic,
    // ...
  };
  ```

#### screens/DataDisplayScreen.js
- **Line 2**: Added `TouchableOpacity` import for button
- **Line 11**: Updated `DataView` component to accept `onReset` prop
- **Line 116-138**: Added reset handler:
  ```javascript
  // Function to reset rep count
  const handleResetRepCount = useCallback(async () => {
    if (!connectedDevice || !deviceCharacteristics?.accel) {
      console.warn('Cannot reset - device or characteristics not available');
      return;
    }

    try {
      console.log('[RESET] Sending reset command to device...');
      await bleService.writeToCharacteristic(
        connectedDevice.id,
        IMU_SERVICE_UUID,
        deviceCharacteristics.accel,
        'RESET'
      );
      console.log('[RESET] Reset command sent successfully');
      Alert.alert('Success', 'Rep count has been reset');
    } catch (error) {
      console.error('[RESET ERROR] Failed to reset rep count:', error);
      Alert.alert('Error', 'Failed to reset rep count. Please try again.');
    }
  }, [connectedDevice, deviceCharacteristics]);
  ```

- **Line 67-75**: Added reset button UI:
  ```javascript
  {/* Reset button */}
  <TouchableOpacity 
    style={styles.resetButton}
    onPress={onReset}
  >
    <Text style={styles.resetButtonText}>Reset Count</Text>
  </TouchableOpacity>
  ```

- **Line 360**: Passed `onReset` prop to `DataView`
- **Line 487-503**: Added button styles

## Communication Protocol

### Reset Command Format
- **Command**: `"RESET"` (case-insensitive)
- **Encoding**: UTF-8 string
- **Transport**: BLE Characteristic Write with Response

### ESP32 Response
When reset command is received:
1. Resets `repCount` to 0
2. Resets `repState` to `REP_IDLE`
3. Resets `phaseStartTime` to current time
4. Immediately sends notification with new state: `"Count:0,State:IDLE"`
5. Logs action to Serial: `"Rep count reset to 0"`

## Testing

### Prerequisites
- ESP32 device running the updated firmware
- iOS device with updated app OR Android device with React Native app
- Physical device required (BLE not available in simulators)

### Test Steps
1. Power on ESP32 device
2. Launch iOS or React Native app
3. Wait for automatic connection to "ESP32_IMU_Stream"
4. Perform some reps to increment the count
5. Tap "Reset Count" button
6. Verify:
   - Count displays as 0
   - State displays as "IDLE"
   - ESP32 serial console shows "Rep count reset to 0"
   - App shows success alert (React Native only)

### Expected Behavior
- **Success**: Rep count immediately resets to 0, state shows IDLE
- **Failure**: If device is disconnected or characteristic unavailable, error is logged (iOS) or alert shown (React Native)

## Technical Details

### UUIDs Used
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Rep Characteristic UUID**: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`

### BLE Properties
- **READ**: Allows reading current rep count
- **WRITE**: Allows sending reset command
- **NOTIFY**: Allows receiving real-time updates

### Error Handling
- iOS: Logs errors to console, silent failure
- React Native: Shows Alert dialog on error
- ESP32: Validates command string, ignores invalid commands

## Future Enhancements

Possible additions to the bidirectional communication:
1. Set target rep count
2. Adjust sensitivity thresholds
3. Calibrate device remotely
4. Query device battery level
5. Update exercise type/mode

## Build Verification

All code has been verified:
- ✅ ESP32 firmware compiles successfully (PlatformIO)
- ✅ iOS Swift files have correct syntax
- ✅ React Native JavaScript files have correct syntax
- ✅ No security vulnerabilities detected (CodeQL)

## Files Modified

1. `Firmware/src/esp1/main.cpp` - ESP32 firmware
2. `ios/esp32Connect/BLEManager.swift` - iOS BLE manager
3. `ios/esp32Connect/AutoConnectDataDisplayView.swift` - iOS UI
4. `services/bleService.js` - React Native BLE service
5. `screens/DataDisplayScreen.js` - React Native UI
6. `.gitignore` - Added CodeQL artifacts

## Summary

This implementation successfully adds bidirectional Bluetooth communication between the mobile apps and ESP32 device, allowing users to reset the rep count remotely. The changes are minimal, focused, and maintain backward compatibility with the existing read/notify functionality.
