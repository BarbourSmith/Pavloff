# Midnight Re-Lock Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           iOS Device                                     │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Main App (esp32Connect)                       │   │
│  │                                                                   │   │
│  │  ┌──────────────────┐        ┌──────────────────┐              │   │
│  │  │  WorkoutView     │        │ ScreenTimeManager│              │   │
│  │  │                  │        │                  │              │   │
│  │  │ • Track workouts │◄──────►│ • Request auth   │              │   │
│  │  │ • Save completion│        │ • Select apps    │              │   │
│  │  │ • Check status   │        │ • Apply shields  │              │   │
│  │  │                  │        │ • Setup schedule │              │   │
│  │  └──────────────────┘        └────────┬─────────┘              │   │
│  │                                       │                          │   │
│  │                                       │                          │   │
│  │                              ┌────────▼─────────┐               │   │
│  │                              │ SharedConstants  │               │   │
│  │                              │                  │               │   │
│  │                              │ • App Group ID   │               │   │
│  │                              │ • UserDefaults   │               │   │
│  │                              │   keys           │               │   │
│  │                              └──────────────────┘               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                       │                                  │
│                                       │                                  │
│                        ┌──────────────▼──────────────┐                  │
│                        │    App Group Container       │                  │
│                        │  (group.com.barboursmith     │                  │
│                        │         .pavloff)            │                  │
│                        │                              │                  │
│                        │  UserDefaults:               │                  │
│                        │  • hasAppSelection: Bool     │                  │
│                        │  • savedAppSelection: Data   │                  │
│                        │  • lastWorkoutCompletion:    │                  │
│                        │    Date                      │                  │
│                        └──────────────┬───────────────┘                  │
│                                       │                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │         DeviceActivityMonitor Extension                          │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │   DeviceActivityMonitorExtension                          │  │   │
│  │  │                                                            │  │   │
│  │  │   • intervalDidStart(at midnight)                         │  │   │
│  │  │   • Check workout completion                              │  │   │
│  │  │   • Reload app selection                                  │  │   │
│  │  │   • Reapply shields                                       │  │   │
│  │  │                                                            │  │   │
│  │  └────────────────────────┬───────────────────────────────────┘  │   │
│  │                           │                                      │   │
│  │                  ┌────────▼─────────┐                           │   │
│  │                  │ SharedConstants  │                           │   │
│  │                  │ (copy in ext)    │                           │   │
│  │                  └──────────────────┘                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                       │                                  │
│                                       │                                  │
│                        ┌──────────────▼──────────────┐                  │
│                        │   ManagedSettingsStore       │                  │
│                        │   (System-managed)           │                  │
│                        │                              │                  │
│                        │   • shield.applications      │                  │
│                        │   • shield.applicationCatego-│                  │
│                        │     ries                     │                  │
│                        │                              │                  │
│                        │   (Persists shields across   │                  │
│                        │    app launches)             │                  │
│                        └──────────────┬───────────────┘                  │
│                                       │                                  │
│                        ┌──────────────▼──────────────┐                  │
│                        │   DeviceActivityCenter       │                  │
│                        │   (System service)           │                  │
│                        │                              │                  │
│                        │   • Manages schedule         │                  │
│                        │   • Triggers extension at    │                  │
│                        │     midnight                 │                  │
│                        └──────────────────────────────┘                  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

### Initial Setup (User Selects Apps)

```
User
 │
 │ 1. Opens Workout Settings
 │
 ▼
WorkoutView
 │
 │ 2. Shows Family Activity Picker
 │
 ▼
ScreenTimeManager
 │
 │ 3. Request authorization
 │
 ▼
iOS System (AuthorizationCenter)
 │
 │ 4. User grants permission
 │
 ▼
ScreenTimeManager
 │
 │ 5. User selects apps
 │
 ▼
ScreenTimeManager.selectedApps (FamilyActivitySelection)
 │
 ├─► 6a. Encode and save to App Group UserDefaults
 │        └─► savedAppSelection: Data
 │        └─► hasAppSelection: true
 │
 ├─► 6b. Apply shields to ManagedSettingsStore
 │        └─► store.shield.applications = tokens
 │
 └─► 6c. Setup daily monitoring schedule
      └─► DeviceActivityCenter.startMonitoring()
           └─► Schedule: 00:00 - 23:59, repeats daily
```

### Workout Completion (Apps Unlock)

```
User
 │
 │ 1. Completes workout exercises
 │
 ▼
WorkoutView.exerciseCompleted()
 │
 │ 2. All exercises done
 │
 ▼
WorkoutView.workoutCompletedToday()
 │
 ├─► 3a. Save completion date to App Group
 │        └─► lastWorkoutCompletion: Date()
 │
 ├─► 3b. Update streak
 │        └─► StreakManager.checkAndUpdateStreak()
 │
 └─► 3c. Disable app blocking
      └─► ScreenTimeManager.disableAppBlocking()
           └─► Remove shields from ManagedSettingsStore
                └─► store.shield.applications = nil
                     └─► Apps are now unlocked ✓
```

### Midnight Re-Lock (Automatic with Extension)

```
System Clock
 │
 │ Midnight (00:00) arrives
 │
 ▼
DeviceActivityCenter
 │
 │ Schedule interval starts
 │
 ▼
DeviceActivityMonitorExtension
 │
 │ intervalDidStart() called
 │
 ▼
DeviceActivityMonitorExtension.handleMidnightReset()
 │
 ├─► 1. Access App Group UserDefaults
 │     └─► Read lastWorkoutCompletion
 │
 ├─► 2. Check if workout done today
 │     └─► Compare lastWorkoutCompletion with today
 │
 ├─► 3. If NOT completed today:
 │     │
 │     └─► Call reapplyShields()
 │          │
 │          ├─► 3a. Read hasAppSelection
 │          │     └─► If false, exit
 │          │
 │          ├─► 3b. Load savedAppSelection from App Group
 │          │     └─► Decode FamilyActivitySelection
 │          │
 │          └─► 3c. Apply shields to ManagedSettingsStore
 │                └─► store.shield.applications = tokens
 │                     └─► Apps are blocked again ✓
 │
 └─► 4. If completed today:
       └─► Do nothing, apps stay unlocked
```

### App Launch After Midnight (Fallback without Extension)

```
User
 │
 │ 1. Opens app next morning
 │
 ▼
WorkoutView.onAppear()
 │
 │ 2. View appears
 │
 ▼
WorkoutView.checkAndEnableScreenTimeBlocking()
 │
 ├─► 3a. Read lastWorkoutCompletion from App Group
 │
 ├─► 3b. Compare with today's date
 │     └─► calendar.isDate(lastCompletionDay, inSameDayAs: today)
 │
 └─► 3c. If different day (workout not done today):
       │
       └─► Call ScreenTimeManager.enableAppBlocking()
            │
            ├─► 4a. Check hasAppSelection
            │
            ├─► 4b. Try to reload tokens if empty
            │     └─► loadSelection() from App Group
            │
            └─► 4c. If tokens available:
                 └─► Apply shields to ManagedSettingsStore
                      └─► store.shield.applications = tokens
                           └─► Apps are blocked ✓
```

## Component Interactions

### ScreenTimeManager ↔ App Group

```swift
// Write
userDefaults.set(hasSelection, forKey: "hasAppSelection")
userDefaults.set(encodedData, forKey: "savedAppSelection")

// Read
let hasSelection = userDefaults.bool(forKey: "hasAppSelection")
let data = userDefaults.data(forKey: "savedAppSelection")
```

### WorkoutView ↔ App Group

```swift
// Write
userDefaults.set(Date(), forKey: "lastWorkoutCompletion")

// Read
let lastDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date
```

### Extension ↔ App Group

```swift
// Read
let lastDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date
let hasSelection = userDefaults.bool(forKey: "hasAppSelection")
let data = userDefaults.data(forKey: "savedAppSelection")
```

### Any Component ↔ ManagedSettingsStore

```swift
// Apply shields
store.shield.applications = applicationTokens
store.shield.applicationCategories = .specific(categoryTokens)

// Remove shields
store.shield.applications = nil
store.shield.applicationCategories = nil
```

### Any Component ↔ DeviceActivityCenter

```swift
// Start monitoring
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)
try activityCenter.startMonitoring(scheduleId, during: schedule)

// Stop monitoring
activityCenter.stopMonitoring([scheduleId])
```

## State Transitions

```
┌─────────────┐
│   Initial   │
│  (No Apps   │
│  Selected)  │
└──────┬──────┘
       │
       │ User selects apps
       │
       ▼
┌─────────────┐
│   Apps      │
│  Selected   │◄──────────────┐
│  & Locked   │               │
└──────┬──────┘               │
       │                      │
       │ Workout completed    │
       │                      │
       ▼                      │
┌─────────────┐               │
│   Apps      │               │
│  Unlocked   │               │
│ (Same Day)  │               │
└──────┬──────┘               │
       │                      │
       │ Midnight passes      │
       │                      │
       ▼                      │
┌─────────────┐               │
│  Midnight   │               │
│   Event     │               │
└──────┬──────┘               │
       │                      │
       ├─► Extension route ───┘
       │   (Automatic)
       │
       └─► Fallback route
           (User opens app)
```

## File Organization

```
ios/
├── esp32Connect/
│   ├── ScreenTimeManager.swift       (Core manager)
│   ├── WorkoutView.swift             (UI + workout logic)
│   ├── SharedConstants.swift         (Shared config)
│   └── esp32Connect.entitlements     (App Group permission)
│
└── DeviceActivityMonitorExtension/
    ├── DeviceActivityMonitorExtension.swift  (Extension logic)
    ├── SharedConstants.swift                 (Copy of shared config)
    └── Info.plist                            (Extension metadata)
```

## Key Design Decisions

### 1. App Group for Data Sharing

**Why**: Extensions run in separate process, need shared storage

**Alternative Considered**: XPC service
**Why Not**: More complex, App Group sufficient for this use case

### 2. SharedConstants Copied to Extension

**Why**: Extensions can't easily import main app files

**Alternative Considered**: Framework target
**Why Not**: Adds build complexity, copy is simpler

### 3. Remove Shields on Workout Completion

**Why**: Immediate user feedback, better UX

**Alternative Considered**: Keep shields, use exemptions
**Why Not**: Exemptions more complex, clearing simpler

### 4. Daily Schedule (00:00 - 23:59)

**Why**: Covers full day, triggers at midnight start

**Alternative Considered**: Multiple smaller intervals
**Why Not**: One daily interval sufficient for use case

### 5. Fallback Mode Without Extension

**Why**: Graceful degradation, still functional

**Alternative Considered**: Require extension
**Why Not**: Better to work partially than not at all

## Extension Lifecycle

```
App Launch
    ↓
App calls startMonitoring()
    ↓
DeviceActivityCenter registers schedule
    ↓
[Time passes... App may be closed]
    ↓
Midnight arrives (00:00)
    ↓
iOS System triggers extension
    ↓
Extension: intervalDidStart() called
    ↓
Extension: handleMidnightReset() runs
    ↓
Extension: Checks data in App Group
    ↓
Extension: Reapplies shields if needed
    ↓
Extension: Exits
    ↓
[Time passes until next midnight]
    ↓
Cycle repeats
```

## Error Handling

### Scenario: App Group Access Fails

```
ScreenTimeManager init
    ↓
Try to create App Group UserDefaults
    ↓
FAIL: Returns nil
    ↓
Log warning: "Failed to create App Group UserDefaults"
    ↓
Fall back to standard UserDefaults
    ↓
Feature continues to work (but extension won't work)
```

### Scenario: Tokens Don't Reload

```
enableAppBlocking() called
    ↓
Tokens are empty
    ↓
Try loadSelection()
    ↓
Still empty after reload
    ↓
Log warning: "Tokens could not be restored"
    ↓
Return without applying shields
    ↓
User will need to reselect apps
```

### Scenario: Extension Can't Access App Group

```
Extension: intervalDidStart()
    ↓
Try to access App Group
    ↓
FAIL: Returns nil
    ↓
Log error: "Failed to access App Group UserDefaults"
    ↓
Return (shields not reapplied)
    ↓
Fallback: Shields will reapply when user opens app
```

## Performance Considerations

- **App Group Access**: Fast, < 1ms typically
- **Token Encoding/Decoding**: Fast, < 10ms typically
- **Shield Application**: Fast, handled by iOS
- **Extension Wake**: Minimal battery impact, runs briefly at midnight
- **Memory**: Extension runs in separate process, no impact on main app

## Security Model

- **Authorization**: User must grant Family Controls permission
- **Tokens**: Cryptographically signed by iOS, opaque to app
- **App Group**: Sandboxed, only accessible by app and extension
- **Shields**: Enforced by iOS, app can't bypass
- **No Network**: All operations local, no data sent anywhere
