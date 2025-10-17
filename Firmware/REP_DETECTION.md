# Workout Rep Detection

This document describes the workout repetition detection algorithm implemented in the Motion Control Board.

## Overview

The rep detection algorithm uses velocity direction changes and acceleration magnitude to count workout repetitions. Unlike position-based tracking (which accumulates noise through double integration), this approach directly analyzes motion patterns in velocity space for more reliable rep counting.

**Important**: This algorithm is designed for **dynamic, repetitive movements** (e.g., bicep curls, squats, bench press) and does not support isometric exercises (static holds). A complete rep cycle (up and down motion) is counted as one rep.

## Key Features

- **Orientation Independent**: Works regardless of how the sensor is mounted on the weight
- **Velocity-Based**: Uses velocity direction changes instead of noisy position tracking
- **State Machine**: Robust three-state system prevents false positives
- **Configurable**: Adjustable thresholds for different exercise types
- **Automatic Reset**: Self-resets after periods of inactivity

## Algorithm Description

### Motion Detection

The algorithm determines if the weight is in motion by checking two conditions:
1. **Velocity Magnitude**: Total velocity must exceed threshold (0.15 m/s)
2. **Acceleration Magnitude**: Linear acceleration must exceed threshold (0.3 g)

Both conditions must be met to consider the weight "in motion". This prevents noise from triggering false rep counts.

### Dominant Axis Selection

Since the sensor orientation is unknown, the algorithm automatically selects the dominant motion axis:
- Compares velocity magnitudes along X, Y, and Z axes
- Tracks velocity along the axis with highest magnitude
- This makes the approach orientation-independent

### State Machine

The rep detection uses a three-state machine:

```
REP_IDLE → REP_MOVING_UP → REP_MOVING_DOWN → REP_MOVING_UP → ...
```

#### States:

1. **REP_IDLE**: No significant motion detected
   - Waiting for initial motion to start tracking
   - Requires velocity magnitude > 1.5× threshold to transition (higher threshold prevents false starts from small movements)

2. **REP_MOVING_UP**: Weight moving in positive direction
   - Monitors for velocity reversal to negative direction
   - Requires minimum phase duration (300ms) before transitioning to DOWN state
   - Increments rep count on transition to DOWN state (completing a full rep cycle)

3. **REP_MOVING_DOWN**: Weight moving in negative direction
   - Monitors for velocity reversal to positive direction
   - Requires minimum phase duration (300ms) before transitioning to UP state

### Rep Counting

A complete rep is counted when:
1. A full up-down motion cycle completes (UP->DOWN transition)
2. Minimum phase duration has elapsed for each phase (prevents false triggers)
3. Motion thresholds are met (prevents counting noise)

**Rep Counting Behavior**: This implementation counts each complete up-down cycle as one rep:
- Starting from rest, moving up, then down = 1 rep
- The rep is incremented when transitioning from the up position to down
- This matches the traditional definition of a repetition in exercise

### Timeout and Reset

- If no motion detected for 3 seconds, state resets to IDLE
- Rep count persists across resets (only resets on device restart)
- Allows for rest periods between sets without losing count

## Configuration Parameters

All parameters are defined as constants in the code:

| Parameter | Default | Description | Tuning Tips |
|-----------|---------|-------------|-------------|
| `REP_ACCEL_THRESHOLD` | 0.3 g | Min acceleration for active motion | Increase for fast movements, decrease for slow |
| `REP_VELOCITY_THRESHOLD` | 0.20 m/s | Min velocity to consider moving | Increase to ignore small movements |
| `REP_MIN_DURATION_MS` | 500 ms | Min time for each phase | Increase for slower exercises |
| `REP_REST_TIMEOUT_MS` | 3000 ms | Inactivity timeout | Increase for longer rest periods |

## BLE Characteristic

The rep detection data is sent via BLE using the Rep Count characteristic:

- **UUID**: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`
- **Format**: `Count:value,State:state`
- **Example**: `Count:12,State:UP`

States transmitted:
- `IDLE`: No motion
- `UP`: Moving in positive direction
- `DOWN`: Moving in negative direction

## Tuning for Different Exercises

### Fast Movements (e.g., Bicep Curls)
```cpp
#define REP_ACCEL_THRESHOLD 0.4f
#define REP_VELOCITY_THRESHOLD 0.25f
#define REP_MIN_DURATION_MS 400
```

### Slow Movements (e.g., Heavy Squats)
```cpp
#define REP_ACCEL_THRESHOLD 0.2f
#define REP_VELOCITY_THRESHOLD 0.15f
#define REP_MIN_DURATION_MS 700
```

### Very Slow Controlled Movements (e.g., Tempo Squats)
```cpp
#define REP_ACCEL_THRESHOLD 0.15f
#define REP_VELOCITY_THRESHOLD 0.12f
#define REP_MIN_DURATION_MS 900
```

**Note**: This algorithm is designed for **dynamic, repetitive movements** and does not work for isometric exercises (static holds like planks).

## Serial Monitor Output

When motion is detected, the system prints debug information:

```
REP: Started - Moving UP
REP: Direction change UP->DOWN | Total Reps: 1
REP: Direction change DOWN->UP | Total Reps: 1
REP: Direction change UP->DOWN | Total Reps: 2
REP: Reset - No motion timeout
```

## Advantages Over Position Tracking

| Aspect | Position Integration | Rep Detection |
|--------|---------------------|---------------|
| Noise sensitivity | Very high (double integration) | Low (single integration) |
| Drift | Severe accumulation | Minimal (damped) |
| Orientation dependency | Requires known orientation | Fully independent |
| Processing complexity | High (filtering required) | Moderate (state machine) |
| Accuracy | Poor for reps | Good for reps |

## Limitations

1. **Static Holds**: Does not count isometric exercises or static holds
2. **Partial Reps**: Counts any complete up-down cycle meeting thresholds
3. **Rep Definition**: One complete up-down cycle = 1 rep
4. **Velocity-Based**: Requires continuous motion; very slow movements may not register

## Future Enhancements

Potential improvements for future versions:
- Detect full rep cycles (up-down as single rep)
- Range-of-motion estimation using peak detection
- Exercise type classification
- Adaptive threshold tuning
- Rep quality scoring (full vs partial reps)

## References

- Current implementation focuses on robust rep counting vs. precise position tracking
- State machine design prevents false positives from sensor noise
- Velocity-based approach more suitable for cyclic motion than position integration
