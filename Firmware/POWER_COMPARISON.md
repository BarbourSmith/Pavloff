# Power Consumption Comparison: Polling vs Interrupt-Based Wake

## Overview

This document compares the power consumption of two different wake-from-sleep approaches:
1. **Timer-based polling** (current implementation)
2. **Interrupt-based wake** (previous implementation, not working)

## Implementation Details

### Timer-based Polling (Current)
- ESP32 wakes from deep sleep every 2 seconds using internal RTC timer
- On wake, MPU6050 is powered up and accelerometer is read
- If motion detected (accel magnitude deviates > 0.15g from 1g), device stays awake
- If no motion, device immediately returns to deep sleep
- Wake cycle takes approximately 100-200ms

### Interrupt-based Wake (Previous)
- MPU6050 configured to generate interrupt on motion detection
- ESP32 remains in deep sleep until GPIO interrupt received
- Wake only occurs when actual motion is detected
- No periodic wake-ups required

## Power Consumption Analysis

### Deep Sleep Current Draw

| Component | Polling (2s interval) | Interrupt-based |
|-----------|----------------------|-----------------|
| ESP32-S3 (sleep) | ~10 μA | ~10 μA |
| ESP32-S3 (wake cycles) | ~2.5 mA average* | 0 μA |
| MPU6050 (gyro disabled) | ~500 μA** | ~40 μA |
| **Total average*** | ~3 mA | ~50 μA |

\* Averaged over 2-second polling interval (assumes 150ms wake time @ 30mA)  
\*\* MPU6050 kept in standby mode with accelerometer active for quick wake  
\*\*\* During periods with no motion

### Calculation Details

#### Polling System (2-second interval):
- Sleep time: 1.85s @ 0.51 mA (ESP32 10μA + MPU6050 500μA)
- Wake time: 0.15s @ 30 mA (ESP32 active + MPU6050 active)
- Average current: (1.85s × 0.51mA + 0.15s × 30mA) / 2s = **2.72 mA**

#### Interrupt System:
- Continuous sleep: 0.05 mA (ESP32 10μA + MPU6050 40μA in motion detection mode)
- Average current: **0.05 mA**

## Battery Life Impact

Assuming a 500 mAh battery in idle/stationary mode:

| System | Average Current | Battery Life | Comparison |
|--------|----------------|--------------|------------|
| Interrupt-based | 0.05 mA | ~10,000 hours (~417 days) | Baseline |
| Polling (2s) | 2.72 mA | ~184 hours (~7.7 days) | **54× worse** |
| Polling (5s) | 1.20 mA | ~417 hours (~17.4 days) | **24× worse** |
| Polling (10s) | 0.65 mA | ~769 hours (~32 days) | **13× worse** |

### Real-World Usage Scenario

Assuming mixed usage (mostly idle with periodic workouts):

**Interrupt-based wake:**
- 23 hours/day idle @ 0.05 mA = 1.15 mAh
- 1 hour/day active @ 34 mA = 34 mAh
- Total per day: ~35 mAh
- **Battery life: ~14 days**

**Polling wake (2s interval):**
- 23 hours/day idle @ 2.72 mA = 62.6 mAh
- 1 hour/day active @ 34 mA = 34 mAh
- Total per day: ~97 mAh
- **Battery life: ~5 days** (2.8× worse)

## Optimization Opportunities for Polling System

If stuck with polling approach, here are ways to reduce power consumption:

### 1. Increase Polling Interval
- **2 seconds** (current): 2.72 mA average → ~5 days battery life
- **5 seconds**: 1.20 mA average → ~11 days battery life
- **10 seconds**: 0.65 mA average → ~23 days battery life
- **30 seconds**: 0.27 mA average → ~52 days battery life

Trade-off: Longer intervals mean slower response to motion detection.

### 2. Reduce Wake Duration
- Optimize MPU6050 initialization to reduce wake time from 150ms to <50ms
- Potential improvement: ~30% reduction in average current
- Estimated battery life: ~7 days (vs 5 days currently)

### 3. Put MPU6050 in Full Sleep
- Currently MPU6050 accelerometer stays active (500μA)
- Could fully sleep MPU6050 (6μA) but wake time increases to ~300ms
- Net effect: Minimal improvement due to longer wake time

### 4. Adaptive Polling
- Use accelerometer's built-in motion detection to increase polling rate
- Start at 30s interval, switch to 2s interval when motion detected recently
- Could achieve near-interrupt performance with better reliability

## Recommended Configuration

For best balance of battery life and responsiveness with polling system:

```cpp
#define POLL_INTERVAL_SECONDS 5  // Wake every 5 seconds
```

This provides:
- Reasonable motion detection latency (max 5 seconds)
- ~11 days battery life in mixed usage scenario
- ~24× worse than interrupt-based, but still acceptable for many use cases

## Conclusion

**The timer-based polling system consumes approximately 50-54× more power than an interrupt-based system during idle periods.** 

In real-world mixed usage scenarios, this translates to approximately 2.8× worse battery life (5 days vs 14 days with a 500mAh battery at 2-second polling interval).

While this is significantly worse, the polling approach offers:
- ✅ **Reliability**: No issues with interrupt configuration or spurious wake-ups
- ✅ **Simplicity**: Easier to debug and maintain
- ✅ **Guaranteed wake**: Timer-based wake is very reliable
- ✅ **Flexibility**: Easy to adjust polling interval for different use cases

The trade-off may be acceptable depending on:
- Available battery capacity (larger battery mitigates the issue)
- Usage patterns (frequent workout sessions reduce the impact)
- Reliability requirements (polling is more predictable)
- Charging frequency (if charged daily, 5-day battery life is sufficient)

## Future Improvements

To get closer to interrupt-based performance:

1. **Fix the interrupt-based wake system** - This should be the long-term goal as it offers the best power efficiency
2. **Hybrid approach** - Use both timer and interrupt, with timer as fallback
3. **Adaptive polling** - Dynamically adjust polling rate based on recent activity
4. **Larger battery** - Use 1000mAh or larger battery to extend runtime with polling
