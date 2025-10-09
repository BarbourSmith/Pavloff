# Legacy React Native Files

This document lists the React Native files that remain in the repository for reference. These files are no longer used by the native Swift iOS app but are kept for historical purposes and potential future reference.

## React Native Files (No longer used)

### Root Files
- `App.js` - React Native root component
- `index.js` - React Native entry point
- `metro.config.js` - Metro bundler configuration
- `package.json` - npm dependencies
- `package-lock.json` - npm lock file

### Screen Components (JavaScript)
- `screens/HomeScreen.js` - Device scanning screen (React Native)
- `screens/ConnectionScreen.js` - Connection status screen (React Native)
- `screens/DataDisplayScreen.js` - Data display screen (React Native)
- `screens/DeviceDataScreen.js` - Legacy data screen

### Services
- `services/bleService.js` - BLE service abstraction (react-native-ble-plx)

### Configuration
- `config/appConfig.js` - JavaScript configuration

## Active Swift Files

The following Swift files in `ios/esp32Connect/` are now the active implementation:

- `ESP32ConnectApp.swift` - App entry point
- `AppDelegate.swift` - App lifecycle
- `SceneDelegate.swift` - Scene lifecycle
- `HomeView.swift` - Device scanning screen
- `ConnectionView.swift` - Connection status screen
- `DataDisplayView.swift` - Data display screen
- `BLEManager.swift` - Bluetooth LE manager
- `Models.swift` - Data models
- `AppConfig.swift` - Configuration constants

## Migration Notes

If you need to reference the old React Native implementation:
1. The JavaScript files contain the original logic and flow
2. The BLE service UUIDs and data formats remain unchanged
3. All functionality has been ported to the Swift version

## Future Considerations

These React Native files can be:
- Kept for reference
- Moved to a `legacy/` directory
- Removed entirely once the Swift app is validated

The Swift app is now the primary and only supported implementation.
