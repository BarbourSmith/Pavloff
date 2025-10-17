# Usage Guide: Workout Rep Detection

This guide provides practical instructions for using the workout rep detection feature.

## Quick Start

1. **Build and Upload**
   ```bash
   pio run -e esp1 -t upload
   ```

2. **Calibration**
   - Keep sensor stationary during startup
   - Wait for "Calibration complete!" message

3. **Attach to Weight**
   - Secure sensor to free weight (dumbbell, barbell, kettlebell, etc.)
   - Orientation doesn't matter - the algorithm adapts automatically

4. **Start Exercising**
   - Perform your workout as normal
   - System automatically detects and counts reps

## Reading the Data

### Serial Monitor Output

Connect via serial monitor (115200 baud) to see real-time feedback:

```
REP: Started - Moving UP
REP: Direction change UP->DOWN | Total Reps: 0
REP: Direction change DOWN->UP | Total Reps: 1
REP: Direction change UP->DOWN | Total Reps: 1
REP: Direction change DOWN->UP | Total Reps: 2
```

**Understanding the Count**: Each complete up-down cycle counts as 1 rep.
- 1 complete up-down motion = 1 rep in the count
- This matches the traditional definition of a repetition

### BLE Connection

1. **Connect via BLE**
   - Device advertises as "Pavloff Workout Sensor"
   - Connect using any BLE client app

2. **Rep Count Characteristic**
   - UUID: `8d3f7a9e-4b2c-11ef-9f27-0242ac120002`
   - Format: `Count:X,State:Y`
   - Example: `Count:12,State:UP`

3. **States**
   - `IDLE`: No motion detected
   - `UP`: Moving in positive direction  
   - `DOWN`: Moving in negative direction

## Tuning for Your Exercise

Default settings work well for most exercises, but you can customize:

### Editing the Configuration

Edit `src/esp1/main.cpp` to adjust parameters.

### Parameters to Adjust

Located near the top of the file:

```cpp
// Rep detection parameters
#define REP_ACCEL_THRESHOLD 0.3f          // Minimum acceleration (g's)
#define REP_VELOCITY_THRESHOLD 0.20f      // Minimum velocity (m/s)
#define REP_MIN_DURATION_MS 500           // Minimum phase time (ms)
#define REP_REST_TIMEOUT_MS 3000          // Reset timeout (ms)
```

### Common Adjustments

**Too Sensitive (counting extra reps)**
```cpp
#define REP_ACCEL_THRESHOLD 0.4f      // Increase
#define REP_VELOCITY_THRESHOLD 0.25f  // Increase
#define REP_MIN_DURATION_MS 600       // Increase
```

**Not Sensitive Enough (missing reps)**
```cpp
#define REP_ACCEL_THRESHOLD 0.2f      // Decrease
#define REP_VELOCITY_THRESHOLD 0.15f  // Decrease
#define REP_MIN_DURATION_MS 400       // Decrease
```

**Longer Rest Periods Between Sets**
```cpp
#define REP_REST_TIMEOUT_MS 5000      // Increase timeout
```

## Exercise-Specific Tips

### Bicep Curls
- Default settings work well
- Moderate speed movements
- Clear up/down motion

### Squats
- May need lower velocity threshold
- Slower movements
- Suggested: `REP_VELOCITY_THRESHOLD 0.15f` and `REP_MIN_DURATION_MS 700`

### Bench Press
- Default settings work well
- Attach to bar near grip

### Shoulder Press
- Default settings work well
- Good vertical motion

### Kettlebell Swings
- May need higher thresholds
- Fast dynamic movements
- Suggested: `REP_ACCEL_THRESHOLD 0.5f`

## Troubleshooting

### Problem: No Reps Detected

**Possible Causes:**
1. Movement too slow - lower velocity threshold
2. Movement too gentle - lower acceleration threshold
3. Sensor not properly attached

**Solutions:**
- Check serial monitor for motion detection messages
- Lower `REP_VELOCITY_THRESHOLD` to 0.10
- Ensure sensor is firmly attached

### Problem: Too Many Reps Counted

**Possible Causes:**
1. Bouncing/shaking during movement
2. Thresholds too sensitive
3. Minimum duration too short

**Solutions:**
- Increase `REP_MIN_DURATION_MS` to 400-500
- Increase velocity threshold
- Perform smoother movements

### Problem: Count Resets During Set

**Cause:** Rest timeout triggered (3 seconds default)

**Solution:**
- Increase `REP_REST_TIMEOUT_MS` to 5000 or more
- Maintain continuous motion during set

### Problem: Inconsistent Detection

**Possible Causes:**
1. Inconsistent movement speed
2. Sensor orientation changing
3. Loose attachment

**Solutions:**
- Maintain consistent tempo
- Secure sensor more firmly
- Check that sensor isn't rotating during movement

## Best Practices

1. **Consistent Tempo**: Maintain steady movement speed throughout set
2. **Full Range of Motion**: Complete movements register better than partial reps
3. **Secure Mounting**: Ensure sensor doesn't shift or rotate during exercise
4. **Start/Stop Clearly**: Begin and end sets with deliberate motion
5. **Monitor Output**: Use serial monitor during initial testing to verify detection

## Understanding Rep Count

The system counts each **complete up-down cycle** as one rep:

| Movement | Count Display | Traditional Reps |
|----------|--------------|------------------|
| Start position | 0 | 0 |
| Up | 0 (moving) | 0 |
| Top → Down | 0 (moving) | 0 |
| Bottom → Up | 1 | 1 |
| Top → Down | 1 (moving) | 1 |
| Bottom → Up | 2 | 2 |

**Rep count matches traditional definition**: Each complete up-down motion = 1 rep

The rep is counted when you return to the starting position, completing a full cycle.

## Example BLE Client Code

### Python (using `bleak`)

```python
import asyncio
from bleak import BleakClient

REP_UUID = "8d3f7a9e-4b2c-11ef-9f27-0242ac120002"
DEVICE_ADDRESS = "XX:XX:XX:XX:XX:XX"  # Your ESP32 address

async def main():
    async with BleakClient(DEVICE_ADDRESS) as client:
        def callback(sender, data):
            rep_data = data.decode('utf-8')
            print(f"Rep Data: {rep_data}")
            # Parse: Count:12,State:UP
            parts = rep_data.split(',')
            count = int(parts[0].split(':')[1])
            state = parts[1].split(':')[1]
            print(f"Reps: {count}, State: {state}")
        
        await client.start_notify(REP_UUID, callback)
        await asyncio.sleep(60)  # Monitor for 60 seconds

asyncio.run(main())
```

## Next Steps

1. Test with your preferred exercises
2. Fine-tune thresholds if needed
3. Build your workout tracking app using BLE data
4. Share your configuration for different exercises!

## Need Help?

- Check serial output for debug information
- Review [REP_DETECTION.md](REP_DETECTION.md) for technical details
- File an issue on GitHub with:
  - Exercise type
  - Movement speed
  - Serial output sample
  - Current threshold settings
