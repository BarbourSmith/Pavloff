# Screen Time Controls - Developer Guide

## Overview

The Screen Time Controls feature leverages Apple's Screen Time API to help users stay focused by blocking selected apps until they complete their daily workout. This feature integrates seamlessly with the existing workout tracking functionality.

## Architecture

### Components

1. **ScreenTimeManager** (`ScreenTimeManager.swift`)
   - Singleton class managing all Screen Time API interactions
   - Handles authorization, app selection, and blocking/unblocking
   - Observable object for UI state updates

2. **WorkoutSettings** (`Models.swift`)
   - Extended with `screenTimeEnabled` boolean property
   - Persists user's preference for screen time controls

3. **SetupView** (`SetupView.swift`)
   - UI for enabling/disabling screen time controls
   - App selection interface using `FamilyActivityPicker`
   - Visual feedback for authorization status

4. **WorkoutView** (`WorkoutView.swift`)
   - Displays blocking status in header
   - Triggers app blocking on view appear
   - Unblocks apps on workout completion

## API Integration

### FamilyControls Framework

```swift
import FamilyControls

// Request authorization
try await AuthorizationCenter.shared.requestAuthorization(for: .individual)

// Present app picker
.familyActivityPicker(isPresented: $showingAppPicker, selection: $selectedApps)
```

### ManagedSettings Framework

```swift
import ManagedSettings

// Apply shields to block apps
let store = ManagedSettingsStore()
store.shield.applications = selectedApps.applicationTokens
store.shield.applicationCategories = selectedApps.categoryTokens

// Remove shields to unblock apps
store.shield.applications = nil
store.shield.applicationCategories = nil
```

### DeviceActivity Framework

```swift
import DeviceActivity

// Set up monitoring schedule
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)

try DeviceActivityCenter().startMonitoring(scheduleId, during: schedule)
```

## User Flow

### Setup Flow

1. User opens Workout Settings
2. Toggles "Enable App Blocking" switch
3. System prompts for Screen Time authorization
4. User grants authorization in Settings
5. App shows "Select Apps to Block" button
6. User taps button to open app picker
7. User selects apps/categories to block
8. Selected apps are stored in ScreenTimeManager

### Daily Usage Flow

1. At midnight, selected apps are automatically blocked
2. User opens Pavloff Workout app
3. Header shows "Apps Blocked" status indicator
4. User performs workout exercises
5. Upon completing final exercise:
   - Congratulations screen appears
   - Apps are automatically unblocked
   - Header updates to "Apps Unlocked"
6. Apps remain unlocked for the rest of the day
7. Cycle repeats at midnight

### Workout Completion Logic

```swift
private func workoutCompletedToday() {
    // Save completion timestamp
    UserDefaults.standard.set(Date(), forKey: "lastWorkoutCompletion")
    workoutStartedToday = true
    
    // Disable app blocking
    if workoutSettings.screenTimeEnabled {
        screenTimeManager.disableAppBlocking()
    }
}
```

### Daily Reset Logic

```swift
private func checkAndEnableScreenTimeBlocking() {
    guard workoutSettings.screenTimeEnabled else { return }
    
    // Check if workout was completed today
    let lastCompletionDate = UserDefaults.standard.object(forKey: "lastWorkoutCompletion") as? Date
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    if let lastDate = lastCompletionDate {
        let lastCompletionDay = calendar.startOfDay(for: lastDate)
        workoutStartedToday = calendar.isDate(lastCompletionDay, inSameDayAs: today)
    } else {
        workoutStartedToday = false
    }
    
    // Enable blocking if workout not completed today
    if !workoutStartedToday {
        screenTimeManager.enableAppBlocking()
    }
}
```

## State Management

### ScreenTimeManager State

- `isAuthorized`: Boolean indicating Screen Time authorization status
- `selectedApps`: FamilyActivitySelection containing app tokens
- `isBlockingEnabled`: Computed property checking if shields are active

### WorkoutView State

- `workoutStartedToday`: Boolean tracking if workout was completed today
- `workoutSettings.screenTimeEnabled`: User preference for the feature

### Persistence

- Workout completion time: `UserDefaults.standard` with key `"lastWorkoutCompletion"`
- Selected apps: Managed internally by `FamilyActivitySelection` (system-managed)

## UI Components

### Setup Screen Additions

```swift
// Screen Time Controls Section
VStack(alignment: .leading, spacing: 15) {
    Text("Screen Time Controls")
        .font(.headline)
        .fontWeight(.bold)
    
    Text("Block selected apps from midnight until you complete your workout")
        .font(.subheadline)
        .foregroundColor(.gray)
    
    Toggle(isOn: $workoutSettings.screenTimeEnabled) {
        Text("Enable App Blocking")
    }
    
    Button("Select Apps to Block") {
        showingAppPicker = true
    }
}
.familyActivityPicker(isPresented: $showingAppPicker, selection: $screenTimeManager.selectedApps)
```

### Workout Screen Additions

```swift
// Screen Time Status Indicator
if workoutSettings.screenTimeEnabled && screenTimeManager.isAuthorized {
    HStack(spacing: 6) {
        Image(systemName: workoutStartedToday ? "lock.open.fill" : "lock.fill")
        Text(workoutStartedToday ? "Apps Unlocked" : "Apps Blocked")
    }
    .foregroundColor(.white.opacity(0.9))
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(workoutStartedToday ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
    .cornerRadius(12)
}
```

## Entitlements and Permissions

### Required Entitlement

File: `esp32Connect.entitlements`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.family-controls</key>
    <true/>
</dict>
</plist>
```

### Info.plist Addition

```xml
<key>NSFamilyControlsUsageDescription</key>
<string>This app uses Screen Time to help you stay focused by blocking selected apps until you complete your daily workout.</string>
```

### Build Settings

Added to both Debug and Release configurations:
```
CODE_SIGN_ENTITLEMENTS = esp32Connect/esp32Connect.entitlements;
```

## Testing

### Local Testing

1. Build the app on a physical iOS device (iOS 16.0+)
2. Navigate to Workout Settings
3. Enable "Enable App Blocking"
4. Grant Screen Time authorization when prompted
5. Select test apps (e.g., Safari, Mail)
6. Verify apps are blocked
7. Complete a workout
8. Verify apps are unlocked

### Manual Testing Checklist

- [ ] Screen Time authorization request appears
- [ ] App picker shows system apps and installed apps
- [ ] Selected apps are reflected in UI
- [ ] Blocking status indicator updates correctly
- [ ] Apps are blocked when expected
- [ ] Workout completion unlocks apps
- [ ] Daily reset re-enables blocking at midnight
- [ ] Settings persist across app restarts

### Known Limitations

1. **Simulator**: Screen Time API is not available in iOS Simulator
2. **Entitlement**: Requires Apple approval for App Store distribution
3. **iOS Version**: Requires iOS 16.0 or later
4. **Authorization**: User must grant permission in Settings
5. **Background**: DeviceActivityMonitor extension not yet implemented (future enhancement)

## Future Enhancements

### Potential Improvements

1. **DeviceActivityMonitor Extension**
   - Implement background monitoring
   - Handle schedule events automatically
   - More robust daily reset mechanism

2. **Customizable Schedule**
   - Allow users to set custom blocking hours
   - Weekend vs. weekday schedules
   - Grace periods before blocking starts

3. **Streak Tracking**
   - Count consecutive days of completed workouts
   - Reward consistent users
   - Integration with achievements

4. **App Categories**
   - Pre-defined categories (Social Media, Games, etc.)
   - Quick selection templates
   - Smart suggestions based on usage

## Troubleshooting

### Authorization Issues

**Problem**: Authorization request doesn't appear
**Solution**: Check Info.plist has NSFamilyControlsUsageDescription

**Problem**: Authorization denied
**Solution**: Guide user to Settings > Screen Time > [App Name]

### Blocking Issues

**Problem**: Apps not blocking
**Solution**: 
- Verify authorization status
- Check selectedApps is not empty
- Ensure enableAppBlocking() is called

**Problem**: Apps stay blocked after workout
**Solution**:
- Check workout completion logic
- Verify UserDefaults date comparison
- Call disableAppBlocking() manually

### Build Issues

**Problem**: Framework not found
**Solution**: Ensure iOS deployment target is 16.0+

**Problem**: Entitlement rejected
**Solution**: Request Family Controls entitlement from Apple

## References

- [Apple Screen Time Documentation](https://developer.apple.com/documentation/screentime)
- [FamilyControls Framework](https://developer.apple.com/documentation/familycontrols)
- [ManagedSettings Framework](https://developer.apple.com/documentation/managedsettings)
- [DeviceActivity Framework](https://developer.apple.com/documentation/deviceactivity)
