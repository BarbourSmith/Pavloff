# Workout Tracking App - Test Plan

## Overview
The app has been updated to support multi-exercise workout tracking with configurable target reps.

## Key Features to Test

### 1. Setup Screen
**Access**: Tap "Workout Settings" button (gear icon) from the workout screen

**Test Cases**:
- [ ] Screen displays "Workout Setup" title
- [ ] Three exercises are shown: Bicep Curls, Shoulder Press, Lateral Raises
- [ ] Each exercise shows current target reps (default: 10)
- [ ] Plus button increases target reps (max 50)
- [ ] Minus button decreases target reps (min 1)
- [ ] Buttons are disabled at min/max limits
- [ ] "Start Workout" button returns to workout screen
- [ ] Settings changes are preserved

### 2. Workout Screen (Default View)
**Access**: App opens directly to this screen

**Test Cases - Not Connected**:
- [ ] Shows "Workout Tracker" title
- [ ] Displays "Scanning for Pavloff Workout Sensor" status
- [ ] Shows progress spinner
- [ ] Shows waiting message with device instructions
- [ ] "Workout Settings" button is accessible

**Test Cases - Connected**:
- [ ] Connection status shows "Connected to Pavloff Workout Sensor"
- [ ] Progress spinner disappears
- [ ] Exercise indicators show as dots (3 dots for 3 exercises)
- [ ] Current exercise dot is blue, completed are green, upcoming are gray
- [ ] Current exercise name is displayed
- [ ] Rep counter shows: [current] / [target]
- [ ] Progress bar fills as reps increase
- [ ] Movement state badge shows (UP/DOWN/IDLE) with appropriate color
- [ ] "Workout Settings" button opens setup
- [ ] "Reset Exercise" button resets current exercise to 0 reps

**Test Cases - Exercise Progression**:
- [ ] When current reps reach target, automatically moves to next exercise
- [ ] Rep counter resets to 0 for new exercise
- [ ] Exercise indicator updates (current becomes green, next becomes blue)
- [ ] Exercise name updates to show new current exercise
- [ ] After completing all exercises, congratulations screen appears

### 3. Congratulations Screen
**Access**: Complete all exercises in the workout

**Test Cases**:
- [ ] Shows green checkmark icon
- [ ] Displays "Congratulations!" message
- [ ] Shows workout summary with all exercises and their target reps
- [ ] Each completed exercise shows green checkmark
- [ ] "Start New Workout" button restarts workout from first exercise
- [ ] "Done" button dismisses screen and returns to workout view

### 4. BLE Connection Handling
**Test Cases**:
- [ ] App automatically scans for Pavloff Workout Sensor device
- [ ] Connects when device is found
- [ ] Shows appropriate status during connection process
- [ ] Handles disconnection gracefully (shows "reconnecting" message)
- [ ] Automatically reconnects when device comes back in range
- [ ] Rep count persists during brief disconnections

### 5. Rep Counting Logic
**Test Cases**:
- [ ] Rep count increases based on ESP32 sensor data
- [ ] Count displays in real-time
- [ ] State indicator (UP/DOWN/IDLE) updates correctly
- [ ] Progress bar updates smoothly
- [ ] Reaching target triggers exercise change (not before)

## User Workflows

### Workflow 1: Complete Full Workout
1. Open app → arrives at workout screen
2. Wait for ESP32 connection
3. Perform Bicep Curls (10 reps)
4. Automatically switches to Shoulder Press
5. Perform Shoulder Press (10 reps)
6. Automatically switches to Lateral Raises
7. Perform Lateral Raises (10 reps)
8. Congratulations screen appears
9. Tap "Start New Workout" to do another set

### Workflow 2: Custom Workout
1. Open app → workout screen appears
2. Tap "Workout Settings"
3. Adjust Bicep Curls to 15 reps
4. Adjust Shoulder Press to 12 reps
5. Adjust Lateral Raises to 8 reps
6. Tap "Start Workout"
7. Perform exercises with custom targets
8. Complete workout

### Workflow 3: Mid-Workout Reset
1. Start workout
2. Perform 5 reps of current exercise
3. Tap "Reset Exercise"
4. Verify count returns to 0
5. Continue workout from 0

## Device Requirements
- Physical iOS device (iOS 16.0+) - BLE requires physical device
- ESP32 device broadcasting as "Pavloff Workout Sensor"
- ESP32 must send rep count data in format: "Count:X,State:Y"

## Known Behaviors
- App defaults to workout screen on launch
- BLE scanning happens automatically every 5 seconds when not connected
- Workout state is preserved during the app session
- Settings persist for the current session only (not saved between app launches)
- Exercise progression is automatic and cannot be manually controlled

