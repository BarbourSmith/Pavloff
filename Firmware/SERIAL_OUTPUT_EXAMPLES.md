# Expected Serial Output Examples

This document shows what the serial output will look like with the new diagnostic features.

**Serial Configuration**: 115200 baud, 8N1

## Enabling/Disabling Serial Debug Output

All serial debug output can be controlled with a single `#define` at the top of `main.cpp`:

```cpp
// Set to 1 to enable serial debug output, 0 to disable
#define ENABLE_SERIAL_DEBUG 1
```

**To disable all debug output:**
- Change `#define ENABLE_SERIAL_DEBUG 1` to `#define ENABLE_SERIAL_DEBUG 0`
- Recompile and upload the firmware
- This saves approximately 7.5KB of flash memory and eliminates all serial overhead

**Default setting:** Debug output is **enabled** (set to 1) to help with board bring-up and troubleshooting.

## Important Note About USB CDC Serial

The ESP32-S3 uses USB CDC (Communication Device Class) for serial output. This means:

1. **You must open the serial monitor BEFORE programming the board** or press the RESET button after opening the serial monitor
2. The firmware waits up to 3 seconds for a USB connection before continuing
3. If no serial monitor is connected, the device will still boot and operate normally after the 3-second timeout
4. Serial output will only be visible if the serial monitor is connected during boot

**Recommended workflow:**
1. Open serial monitor at 115200 baud
2. Press RESET button on the ESP32-S3
3. Watch for the startup sequence

## Boot Sequence

### Normal Boot (Power-on)
```

=== Pavloff Workout Sensor Starting ===
Firmware: ESP32-S3 Motion Tracking
CPU Frequency: 240 MHz

--- Disabling WiFi ---
WiFi was not initialized (expected)

--- Configuring Power Optimizations ---
CPU Frequency after optimization: 80 MHz

--- Checking Wake-Up Reason ---
Wake-up source: POWER ON or RESET

--- Initializing MPU-6050 ---
I2C SDA Pin: 8
I2C SCL Pin: 9
INT Pin: 18
I2C bus initialized
Calling mpu.initialize()...
MPU-6050 initialization complete
Testing MPU-6050 connection... SUCCESS! MPU-6050 connection verified
Configuring MPU-6050 ranges...
  Accelerometer: ±2g
  Gyroscope: ±500°/s
Disabling interrupts for normal operation
DHPF configured to HOLD mode

--- Loading Gyro Calibration ---
Loaded stored calibration offsets:
  X offset: 0.1234 °/s
  Y offset: -0.0987 °/s
  Z offset: 0.0543 °/s

--- Resetting State Variables ---
State variables reset
Activity timer initialized: 1234 ms

--- Initializing BLE ---
Creating BLE device: 'Pavloff Workout Sensor'
Setting BLE power level to 0 dBm
Creating BLE server
BLE server callbacks configured
Creating BLE service with UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
Creating Accelerometer characteristic
  Accelerometer characteristic configured
Creating Gyroscope characteristic
  Gyroscope characteristic configured
Creating Rep Counter characteristic
  Rep Counter characteristic configured
Starting BLE service
Starting BLE advertising
BLE advertising started

=== Setup Complete ===
Device is ready and advertising
Entering main loop...
```

### Wake from Sleep
```

=== Pavloff Workout Sensor Starting ===
Firmware: ESP32-S3 Motion Tracking
CPU Frequency: 240 MHz

--- Disabling WiFi ---
WiFi was not initialized (expected)

--- Configuring Power Optimizations ---
CPU Frequency after optimization: 80 MHz

--- Checking Wake-Up Reason ---
Wake-up source: MOTION INTERRUPT (GPIO 18)

--- Initializing MPU-6050 ---
I2C SDA Pin: 8
I2C SCL Pin: 9
INT Pin: 18
I2C bus initialized
Restoring MPU from low power mode...
Motion interrupt was pending
Calling mpu.initialize()...
MPU-6050 initialization complete
Testing MPU-6050 connection... SUCCESS! MPU-6050 connection verified
Configuring MPU-6050 ranges...
  Accelerometer: ±2g
  Gyroscope: ±500°/s
Disabling interrupts for normal operation
DHPF configured to HOLD mode

--- Loading Gyro Calibration ---
Loaded stored calibration offsets:
  X offset: 0.1234 °/s
  Y offset: -0.0987 °/s
  Z offset: 0.0543 °/s

--- Resetting State Variables ---
State variables reset
Activity timer initialized: 5678 ms

--- Initializing BLE ---
Creating BLE device: 'Pavloff Workout Sensor'
Setting BLE power level to 0 dBm
Creating BLE server
BLE server callbacks configured
Creating BLE service with UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
Creating Accelerometer characteristic
  Accelerometer characteristic configured
Creating Gyroscope characteristic
  Gyroscope characteristic configured
Creating Rep Counter characteristic
  Rep Counter characteristic configured
Starting BLE service
Starting BLE advertising
BLE advertising started

=== Setup Complete ===
Device is ready and advertising
Entering main loop...
```

## Normal Operation Diagnostics

### Idle State (every 2 seconds)
```
--- Status Update ---
Uptime: 5 seconds
BLE Connected: NO
Rep Count: 0
Rep State: IDLE
Time until sleep: 15 seconds
```

### After BLE Connection
```
*** BLE CLIENT CONNECTED ***

--- Status Update ---
Uptime: 8 seconds
BLE Connected: YES
Rep Count: 0
Rep State: IDLE
Time until sleep: 20 seconds
```

### During Rep Detection
```
--- Status Update ---
Uptime: 12 seconds
BLE Connected: YES
Rep Count: 2
Rep State: MOVING_UP
Time until sleep: 20 seconds

--- Status Update ---
Uptime: 14 seconds
BLE Connected: YES
Rep Count: 3
Rep State: MOVING_DOWN
Time until sleep: 20 seconds

--- Status Update ---
Uptime: 16 seconds
BLE Connected: YES
Rep Count: 3
Rep State: MOVING_UP
Time until sleep: 20 seconds
```

## Sleep Sequence

### Warning Before Sleep
```
--- Status Update ---
Uptime: 15 seconds
BLE Connected: NO
Rep Count: 3
Rep State: IDLE
Time until sleep: 5 seconds

*** WARNING: Deep sleep in 5 seconds ***
```

### Entering Sleep
```
--- Status Update ---
Uptime: 20 seconds
BLE Connected: NO
Rep Count: 3
Rep State: IDLE
Time until sleep: 0 seconds

*** IDLE TIMEOUT - ENTERING DEEP SLEEP ***

=== Entering Deep Sleep ===
Configuring MPU for motion wake-up
Putting MPU into low power mode
  Configuring motion detection interrupt
  Motion detection interrupt enabled
  Interrupt status: 0x00
  Disabling temperature sensor
  Disabling gyroscope, keeping accelerometer active
  Keeping MPU in normal mode (cycle mode disabled)
MPU low power mode configured
MPU interrupt status before sleep: 0x00
GPIO 18 level before sleep: 0
Shutting down BLE
Shutting down WiFi (if active)
Disabling unused peripherals
Configuring wake on GPIO 18 (motion interrupt)
*** ENTERING DEEP SLEEP NOW ***
Device will wake on motion detection
```

## BLE Interaction

### Connection Event
```
*** BLE CLIENT CONNECTED ***

--- Status Update ---
Uptime: 12 seconds
BLE Connected: YES
Rep Count: 2
Rep State: IDLE
Time until sleep: 20 seconds
```

### Reset Command Received
```
BLE Write received: RESET
Rep counter reset command received
Rep counter reset to 0

--- Status Update ---
Uptime: 35 seconds
BLE Connected: YES
Rep Count: 0
Rep State: IDLE
Time until sleep: 20 seconds
```

### Disconnection Event
```
*** BLE CLIENT DISCONNECTED ***
Restarting BLE advertising

--- Status Update ---
Uptime: 45 seconds
BLE Connected: NO
Rep Count: 5
Rep State: IDLE
Time until sleep: 15 seconds
```

## First Boot (No Calibration)

When the device is programmed for the first time with no stored calibration:

```
--- Loading Gyro Calibration ---
No stored calibration found
Starting calibration in 2 seconds...
*** KEEP DEVICE STATIONARY ***

=== Starting Gyro Calibration ===
Collecting 3000 samples...
  Sample 0...
  Sample 1000...
  Sample 2000...

Calibration complete!
Gyro offsets calculated:
  X: 0.1234 °/s
  Y: -0.0987 °/s
  Z: 0.0543 °/s
Offsets saved to persistent storage
Resuming normal operation in 3 seconds...
```

## Diagnostic Information Guide

### Reading the Diagnostics

**Uptime**: Time since boot or wake from sleep (in seconds)

**BLE Connected**: 
- YES = Client connected and receiving data
- NO = No active BLE connection

**Rep Count**: Total reps counted since last reset or wake from sleep

**Rep State**: Current rep detection state
- IDLE = No motion detected or insufficient motion for rep
- MOVING_UP = Upward motion phase detected
- MOVING_DOWN = Downward motion phase detected

**Time until sleep**: Seconds remaining before device enters deep sleep
- Resets to 20 seconds when motion is detected
- BLE connection does NOT prevent sleep
- Only motion activity extends the awake time

### Troubleshooting with Serial Output

**Problem**: No serial output at all
- Check baud rate is set to 115200
- Verify USB cable supports data (not just power)
- Ensure correct COM port is selected
- Check that ARDUINO_USB_CDC_ON_BOOT=1 in platformio.ini

**Problem**: MPU-6050 connection fails
- Look for "FAILED! MPU-6050 not responding"
- Check I2C wiring (SDA=GPIO8, SCL=GPIO9)
- Verify MPU-6050 has power (3.3V)
- Check for I2C pull-up resistors (typically on MPU board)

**Problem**: Device keeps resetting
- Look for multiple "Pavloff Workout Sensor Starting" messages
- Check wake-up reason for clues
- Verify power supply is stable (500mA minimum)
- Check for short circuits on GPIO pins

**Problem**: Rep count not incrementing
- Monitor "Rep State" in status updates
- State should change from IDLE to MOVING_UP/DOWN during exercise
- If state stays IDLE, motion may be too slow or too small
- Minimum velocity threshold is 0.20 m/s

**Problem**: Device enters sleep unexpectedly
- Watch "Time until sleep" counter
- Should reset to 20 seconds when motion detected
- If timer keeps counting down, device isn't detecting motion
- Check MPU-6050 is responding and providing data

**Problem**: BLE connection not working
- Verify "BLE advertising started" appears
- Look for "*** BLE CLIENT CONNECTED ***" when device connects
- Check that iOS app is scanning for "Pavloff Workout Sensor"
- Service UUID should be: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
