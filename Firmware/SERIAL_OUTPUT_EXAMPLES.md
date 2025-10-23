# Expected Serial Output Examples

This document shows what the serial output will look like with the new diagnostic features.

## Boot Sequence

### Normal Boot (Power-on)
```
=====================================
DEVICE STARTING
Power-on or reset detected
=====================================
CPU frequency set to: 80 MHz
Power optimizations configured
MPU-6050 initialized
Using stored calibration offsets
Offsets: X=0.1234, Y=-0.0987, Z=0.0543
------------------------------------
State variables reset
BLE power set to minimum for energy efficiency
Waiting for a client connection to notify...
```

### Wake from Sleep
```
=====================================
WOKE UP FROM DEEP SLEEP
Reason: Motion detection triggered
Resuming normal operation...
=====================================
CPU frequency set to: 80 MHz
Power optimizations configured
Waking MPU-6050 from low power mode...
  - Cleared motion interrupt status
  - Set to normal mode (PWR_MGMT_1 = 0x00)
  - Enabled all sensors (PWR_MGMT_2 = 0x00)
  - Disabled motion interrupt (INT_ENABLE = 0x00)
MPU-6050 woken up and ready for normal operation
MPU-6050 initialized
Using stored calibration offsets
------------------------------------
State variables reset
BLE power set to minimum for energy efficiency
Waiting for a client connection to notify...
```

## Normal Operation Diagnostics

### Idle State
```
======== STATE DIAGNOSTIC ========
Uptime: 5 seconds
BLE Connected: YES
Rep Count: 0 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 5 / 20 seconds
==================================
```

### During Rep (Moving Up)
```
REP: Started - Moving UP
======== STATE DIAGNOSTIC ========
Uptime: 8 seconds
BLE Connected: YES
Rep Count: 0 | State: MOVING_UP
Position (m): X=0.012, Y=-0.003, Z=0.145
Velocity (m/s): X=0.023, Y=-0.005, Z=0.312
Idle timer: 0 / 20 seconds
==================================
Sent Reps:  Count:0,State:UP (repCount=0)
```

### After Completing Rep
```
REP: Direction change UP->DOWN | Total Reps: 1
======== STATE DIAGNOSTIC ========
Uptime: 10 seconds
BLE Connected: YES
Rep Count: 1 | State: MOVING_DOWN
Position (m): X=0.008, Y=-0.001, Z=0.087
Velocity (m/s): X=-0.015, Y=0.002, Z=-0.245
Idle timer: 0 / 20 seconds
==================================
Sent Reps:  Count:1,State:DOWN (repCount=1)
```

### Multiple Reps
```
REP: Direction change DOWN->UP | Total Reps: 1
REP: Direction change UP->DOWN | Total Reps: 2
REP: Direction change DOWN->UP | Total Reps: 2
REP: Direction change UP->DOWN | Total Reps: 3
======== STATE DIAGNOSTIC ========
Uptime: 25 seconds
BLE Connected: YES
Rep Count: 3 | State: MOVING_DOWN
Position (m): X=-0.005, Y=0.002, Z=0.023
Velocity (m/s): X=-0.018, Y=0.003, Z=-0.198
Idle timer: 0 / 20 seconds
==================================
Sent Reps:  Count:3,State:DOWN (repCount=3)
```

## Sleep Sequence

### Warning Before Sleep
```
======== STATE DIAGNOSTIC ========
Uptime: 15 seconds
BLE Connected: NO
Rep Count: 3 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 15 / 20 seconds
==================================
WARNING: Device will enter sleep in 5 seconds if no activity detected
```

### Entering Sleep
```
======== STATE DIAGNOSTIC ========
Uptime: 20 seconds
BLE Connected: NO
Rep Count: 3 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 20 / 20 seconds
==================================
Idle timeout reached - entering deep sleep
=====================================
ENTERING DEEP SLEEP MODE
Device will wake on motion detection
Current uptime: 20 seconds
=====================================
Preparing MPU-6050 for sleep mode...
MPU-6050 motion interrupt configured
  - Set to normal mode with temp disabled
  - Disabled gyroscope, kept accelerometer enabled
  - Motion interrupt enabled
MPU-6050 in low-power mode with motion detection enabled
(Gyroscope disabled, temperature sensor disabled for power savings)
```

## BLE Interaction

### Connection Event
```
Device connected
======== STATE DIAGNOSTIC ========
Uptime: 12 seconds
BLE Connected: YES
Rep Count: 2 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 0 / 20 seconds
==================================
```

### Reset Command Received
```
Received command: RESET
Rep count reset to 0
Sent Reps:  Count:0,State:IDLE (repCount=0)
======== STATE DIAGNOSTIC ========
Uptime: 35 seconds
BLE Connected: YES
Rep Count: 0 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 0 / 20 seconds
==================================
```

### Disconnection Event
```
Device disconnected
======== STATE DIAGNOSTIC ========
Uptime: 45 seconds
BLE Connected: NO
Rep Count: 5 | State: IDLE
Position (m): X=0.000, Y=0.000, Z=0.000
Velocity (m/s): X=0.000, Y=0.000, Z=0.000
Idle timer: 0 / 20 seconds
==================================
```

## Diagnostic Information Guide

### Reading the Diagnostics

**Uptime**: Time since boot or wake from sleep (in seconds)

**BLE Connected**: 
- YES = Client connected and subscribed
- NO = No active connection

**Rep Count**: Total reps counted since last reset or wake

**State**: Current rep detection state
- IDLE = No motion detected
- MOVING_UP = Upward motion phase
- MOVING_DOWN = Downward motion phase

**Position**: 3D position estimate in meters (X, Y, Z)
- Values near 0.000 indicate stable/stationary
- Larger values indicate movement has occurred

**Velocity**: 3D velocity in meters per second (X, Y, Z)
- Values near 0.000 indicate no motion
- Positive/negative indicates direction
- Magnitude > 0.20 typically indicates active rep

**Idle Timer**: 
- First number: seconds since last activity
- Second number: timeout threshold (20 for testing, 300 for production)
- When first >= second, device enters sleep

### Troubleshooting with Diagnostics

**Problem**: Rep count not incrementing
- Check State changes from IDLE to MOVING_UP/DOWN
- Verify Velocity magnitude exceeds 0.20 m/s
- Ensure motion is sustained for at least 500ms

**Problem**: Device sleeping too quickly
- Monitor Idle timer
- Verify activity resets timer to 0
- Check BLE connection extends timeout

**Problem**: Reps not transmitted via BLE
- Verify "BLE Connected: YES"
- Check "Sent Reps:" messages appear
- Confirm client is subscribed to notifications

**Problem**: Position drifting over time
- Small drift is normal due to integration
- Gets reset when device becomes stationary
- Large continuous drift may indicate calibration issue
