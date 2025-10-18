# Workout Tracking Feature

## Overview
The app now includes a comprehensive workout tracking system that guides users through multiple exercises with automatic progression and celebration upon completion.

## Quick Start

1. **Open the app** - You'll see the Workout Screen immediately
2. **Wait for connection** - The app automatically connects to your ESP32 device
3. **Start exercising** - Begin with the first exercise (Bicep Curls)
4. **Track progress** - Watch your reps count up automatically
5. **Auto-advance** - When you hit your target, the app moves to the next exercise
6. **Celebrate** - Complete all exercises to see the congratulations screen!

## Features

### 📋 Setup Screen
Customize your workout before or during your session:
- Adjust target reps for each exercise (1-50 reps)
- Three pre-configured exercises:
  - **Bicep Curls**: Upper arm strength
  - **Shoulder Press**: Shoulder and upper body
  - **Lateral Raises**: Shoulder definition
- Easy increment/decrement buttons
- Changes take effect immediately

### 💪 Workout Screen
Your main training interface:
- **Large Rep Counter**: See current/target at a glance (e.g., "5 / 10")
- **Progress Dots**: Visual indicator of workout progression
  - Blue dot = Current exercise
  - Green dot = Completed exercise
  - Gray dot = Upcoming exercise
- **Progress Bar**: Visual completion percentage
- **Movement State**: Real-time feedback (UP/DOWN/IDLE)
- **Auto-Connect**: Finds your device automatically
- **Quick Reset**: Restart current exercise if needed
- **Mid-Workout Settings**: Adjust targets on the fly

### 🎉 Congratulations Screen
Celebrate your achievement:
- Success animation with green checkmark
- Complete workout summary
- Quick restart option for another set
- Clean finish option

## How It Works

### Exercise Progression
The app automatically advances when you complete an exercise:
```
Bicep Curls (10/10) ✓ → Shoulder Press (0/10)
Shoulder Press (10/10) ✓ → Lateral Raises (0/10)
Lateral Raises (10/10) ✓ → Congratulations!
```

### Smart Detection
The app uses smart logic to prevent false triggers:
- Only advances when rep count increases
- Requires reaching the exact target
- Automatically resets counter for next exercise
- Maintains state during brief disconnections

### ESP32 Integration
Works seamlessly with your ESP32 sensor:
- Auto-scans every 5 seconds when disconnected
- Connects to device named "Pavloff Workout Sensor"
- Receives rep data in format: `Count:X,State:Y`
- Handles disconnections gracefully with auto-reconnect

## Tips for Best Experience

1. **Set Realistic Targets**: Start with achievable rep counts and increase gradually
2. **Stay Connected**: Keep your device within Bluetooth range (typically 10-30 feet)
3. **Proper Form**: The sensor tracks movement - maintain consistent form for accurate counting
4. **Rest Between Sets**: Use "Start New Workout" to begin another complete set
5. **Adjust Mid-Workout**: Don't be afraid to change targets if needed

## Customization

### Adding Exercises
Currently supports three exercises. To add more, modify `WorkoutSettings.defaultExercises` in `Models.swift`:

```swift
static let defaultExercises = [
    Exercise(name: "Bicep Curls", targetReps: 10),
    Exercise(name: "Shoulder Press", targetReps: 10),
    Exercise(name: "Lateral Raises", targetReps: 10),
    Exercise(name: "Your Exercise", targetReps: 10)  // Add here
]
```

### Changing Default Targets
Modify the `targetReps` value in the default exercises array.

### Adjusting Rep Range
Current range is 1-50 reps. Modify limits in `SetupView.swift`:
- Minimum: Change `exercise.targetReps > 1` condition
- Maximum: Change `exercise.targetReps < 50` condition

## Technical Details

### Architecture
- **Models**: Exercise and WorkoutSettings structs manage workout data
- **Views**: SwiftUI-based reactive UI with three main screens
- **BLE Manager**: Handles all Bluetooth communication
- **State Management**: SwiftUI @State and @StateObject for reactivity

### Data Flow
```
ESP32 Sensor
    ↓ (BLE)
BLE Manager (parses Count:X,State:Y)
    ↓
Device Data (SensorData model)
    ↓
WorkoutView (monitors currentReps)
    ↓
UI Updates (reactive via @Published)
```

### Persistence
- Workout settings: Session-only (resets on app restart)
- Exercise progress: Lost on app close
- Connection state: Auto-restores when app reopens

## Troubleshooting

### Device Won't Connect
- Ensure ESP32 is powered on
- Check device is named "Pavloff Workout Sensor"
- Verify Bluetooth is enabled on iPhone
- Try moving closer to the device

### Reps Not Counting
- Check ESP32 is sending data in correct format
- Verify sensor is detecting movement
- Check device connection status in header
- Try resetting the current exercise

### Stuck on Exercise
- Manual progress: Reset exercise and complete reps again
- Check target hasn't been set too high
- Verify device is still connected

### App Crashes
- Ensure iOS 16.0 or later
- Check Bluetooth permissions are granted
- Try force-quitting and reopening the app

## Future Enhancements

Potential features for future versions:
- [ ] Workout history and statistics
- [ ] Custom exercise creation
- [ ] Rest timer between exercises
- [ ] Multiple workout programs
- [ ] Cloud sync across devices
- [ ] Achievement badges
- [ ] Social sharing
- [ ] Voice coaching

## Support

For issues or questions:
1. Check the TEST_PLAN.md for detailed testing scenarios
2. Review WORKOUT_SCREENS.md for screen designs
3. See IMPLEMENTATION_SUMMARY.md for technical details

---

**Enjoy your workout! 💪**
