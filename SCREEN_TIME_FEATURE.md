# Screen Time Controls Feature

This update adds screen time controls to the Pavloff Workout app, allowing users to block selected apps from midnight until they complete their daily workout.

## What's New

### User-Facing Changes

1. **App Blocking Setup**
   - New toggle in Workout Settings to enable/disable app blocking
   - App selection interface using Apple's FamilyActivityPicker
   - Visual indicator showing when apps are blocked/unlocked

2. **Automatic Blocking Schedule**
   - Selected apps are automatically blocked starting at midnight
   - Apps remain blocked until the user completes their workout
   - Blocking status is shown in the workout tracker header

3. **Workout Completion**
   - Completing the workout automatically unblocks the selected apps
   - Apps remain unlocked for the rest of the day
   - Blocking resets at midnight the next day

### Technical Implementation

1. **New Files**
   - `ScreenTimeManager.swift`: Manages Screen Time API integration
   - `esp32Connect.entitlements`: Contains Family Controls capability

2. **Modified Files**
   - `SetupView.swift`: Added screen time controls UI
   - `WorkoutView.swift`: Integrated blocking status and workout completion
   - `Models.swift`: Added screenTimeEnabled property to WorkoutSettings
   - `Info.plist`: Added NSFamilyControlsUsageDescription
   - `project.pbxproj`: Added new files and entitlements to build

3. **Frameworks Used**
   - FamilyControls: User authorization and app selection
   - ManagedSettings: Enforcing app shields (blocks)
   - DeviceActivity: Monitoring and scheduling

## Important Notes

### App Store Requirements

The `com.apple.developer.family-controls` entitlement requires special approval from Apple:
- Apps must request this entitlement when submitting to App Store
- The feature is designed for parental controls and productivity apps
- Apple reviews the use case before granting the entitlement

### Permissions

Users will be prompted to grant Screen Time permissions when they:
1. Enable the "Enable App Blocking" toggle in Workout Settings
2. The app requests authorization through the FamilyControls framework

### Testing

To test this feature:
1. Build and run the app on a physical iOS device (iOS 16.0+)
2. Go to Workout Settings
3. Enable "Enable App Blocking"
4. Grant Screen Time permissions when prompted
5. Select apps to block
6. Complete a workout to see apps unlock

### Limitations

- Requires iOS 16.0 or later
- Only works on physical devices (not simulator)
- Requires user authorization through Screen Time settings
- Blocked apps show the Screen Time shield interface
- The entitlement requires Apple approval for App Store distribution

## User Flow

1. User opens Workout Settings
2. Toggles "Enable App Blocking"
3. Grants Screen Time authorization
4. Taps "Select Apps to Block"
5. Chooses apps from the system picker
6. Selected apps are blocked from midnight to workout completion
7. User sees "Apps Blocked" indicator in workout screen
8. After completing workout, apps are unlocked
9. "Apps Unlocked" indicator confirms the change

## Code Architecture

The implementation follows these principles:
- Minimal changes to existing code
- Separation of concerns with dedicated ScreenTimeManager
- Observable state management for UI updates
- UserDefaults for tracking daily workout completion
- Integration with existing workout completion flow
