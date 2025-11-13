# Battery Voltage Detection

## Overview

The firmware now includes battery voltage detection functionality using a voltage divider circuit. This allows the ESP32 to monitor the battery voltage and report it via BLE to connected devices.

## Hardware Configuration

### Voltage Divider Circuit

The battery voltage is measured through a voltage divider circuit:
- **R1 (Top resistor)**: 27kΩ
- **R2 (Bottom resistor)**: 68kΩ
- **Total resistance**: 95kΩ

The voltage divider reduces the battery voltage to a safe range for the ESP32's ADC:
```
V_ADC = V_Battery × (R2 / (R1 + R2))
V_ADC = V_Battery × (68k / 95k) ≈ V_Battery × 0.7158
```

To calculate the actual battery voltage:
```
V_Battery = V_ADC × ((R1 + R2) / R2)
V_Battery = V_ADC × 1.3971
```

### ADC Pin Configuration

**⚠️ Important Pin Note**: The issue mentions GPIO 36, but this pin doesn't exist on ESP32-S3. The firmware currently uses **GPIO 4** as the default battery voltage pin (ADC1_CH3).

**Please verify your hardware schematic** and update the `BATTERY_PIN` definition in `main.cpp` if your voltage divider is connected to a different GPIO pin.

#### Available ADC Pins on ESP32-S3:
- **ADC1**: GPIO 1-10 (channels 0-9)
- **ADC2**: GPIO 11-20 (channels 0-9)

Note: ADC2 pins cannot be used when WiFi is active, so ADC1 pins are preferred.

## Software Implementation

### Functions

#### `float readBatteryVoltage()`
Reads the battery voltage directly from the ADC.
- Takes 10 samples and averages them for stability
- Applies voltage divider compensation
- Returns battery voltage in volts

#### `float getBatteryVoltage()`
Gets the battery voltage with caching.
- Returns cached value if read within the last 5 seconds
- Otherwise, reads a fresh value
- Returns battery voltage in volts

#### `int getBatteryPercentage()`
Calculates estimated battery percentage.
- Assumes Li-ion battery chemistry (4.2V full, 3.0V empty)
- Returns percentage (0-100%)

### BLE Characteristic

**UUID**: `7c8a8e7a-4c5d-11ef-9f27-0242ac120002`

**Properties**:
- READ
- NOTIFY

**Data Format**:
```
<voltage>V,<percentage>%
```

**Example**:
```
3.85V,68%
```

### Configuration Constants

Located in `main.cpp`:

```cpp
#define BATTERY_PIN 4  // ADC pin (update based on hardware)
#define BATTERY_R1 27000.0f  // Top resistor (ohms)
#define BATTERY_R2 68000.0f  // Bottom resistor (ohms)
#define BATTERY_ADC_SAMPLES 10  // Number of samples to average
#define BATTERY_READ_INTERVAL_MS 5000  // Read interval (5 seconds)
```

## Usage

### In Firmware

The battery voltage is automatically read and reported every 5 seconds when a BLE client is connected. No additional code is needed.

To manually read battery voltage in your code:
```cpp
float voltage = getBatteryVoltage();
int percentage = getBatteryPercentage();
```

### From iOS App

Subscribe to the battery voltage characteristic to receive updates:

```swift
let batteryUUID = CBUUID(string: "7c8a8e7a-4c5d-11ef-9f27-0242ac120002")
peripheral.setNotifyValue(true, for: batteryCharacteristic)
```

Parse the received data:
```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value,
          let string = String(data: data, encoding: .utf8) else { return }
    
    // Parse format: "3.85V,68%"
    let components = string.components(separatedBy: ",")
    if components.count == 2 {
        let voltage = components[0].replacingOccurrences(of: "V", with: "")
        let percentage = components[1].replacingOccurrences(of: "%", with: "")
        // Use voltage and percentage values
    }
}
```

## ADC Configuration

The firmware configures the ADC with:
- **Resolution**: 12-bit (0-4095)
- **Attenuation**: 11dB (0-3.3V range)
- **Reference voltage**: 3.3V

## Battery Chemistry Assumptions

The battery percentage calculation assumes a Li-ion battery:
- **Full charge**: 4.2V (100%)
- **Safe minimum**: 3.0V (0%)
- **Typical nominal**: 3.7V

If using a different battery chemistry, adjust the voltage thresholds in `getBatteryPercentage()`.

## Hardware Setup Checklist

1. ✅ Verify voltage divider resistor values (27kΩ and 68kΩ)
2. ⚠️ **Identify the actual GPIO pin** connected to the voltage divider
3. ⚠️ **Update `BATTERY_PIN`** in `main.cpp` if not GPIO 4
4. ✅ Ensure the voltage divider output doesn't exceed 3.3V
5. ✅ Connect the voltage divider between battery positive and ground
6. ✅ Connect the divider midpoint to the ADC pin

## Troubleshooting

### Issue: Incorrect voltage readings

**Solution**: 
- Verify the GPIO pin number in the schematic
- Update `BATTERY_PIN` in `main.cpp`
- Check resistor values (should be 27kΩ and 68kΩ)

### Issue: Voltage reads as 0.00V

**Solution**:
- Check physical connections to the ADC pin
- Verify the battery is connected
- Check if the ADC pin is configured correctly

### Issue: Voltage is too high/low

**Solution**:
- Verify the voltage divider resistor values
- Update `BATTERY_R1` and `BATTERY_R2` constants if different
- Check ADC calibration (ESP32-S3 ADC may need calibration)

## Testing

To test battery voltage detection:

1. Build and upload the firmware
2. Connect via BLE from the iOS app
3. Subscribe to the battery voltage characteristic
4. Verify voltage readings make sense for your battery
5. Test with different battery charge levels

Expected voltage ranges:
- Full Li-ion battery: ~4.1-4.2V
- Half charged: ~3.7-3.8V
- Nearly empty: ~3.2-3.3V

## Future Enhancements

Potential improvements:
- ADC calibration for more accurate readings
- Low battery warning alerts
- Battery voltage trend analysis
- Support for different battery chemistries
- Power consumption based on voltage
