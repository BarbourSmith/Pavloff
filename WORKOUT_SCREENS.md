# Workout Tracking App - Screen Designs

## Screen Flow
```
App Launch → Workout Screen ⟷ Setup Screen
                ↓
         Congratulations Screen
                ↓
           Workout Screen
```

## 1. Workout Screen (Default/Main View)

### When Not Connected
```
┌─────────────────────────────────────┐
│    Workout Tracker                  │ ← Blue header
│    ○ Scanning for Pavloff Workout Sensor  │
├─────────────────────────────────────┤
│                                     │
│           ⏳                        │
│                                     │
│     Waiting for Pavloff Workout Sensor    │
│        to be available...           │
│                                     │
│   Make sure your device is powered  │
│        on and in range.             │
│                                     │
│    ┌───────────────────────┐       │
│    │ ⚙ Workout Settings    │       │ ← Blue button
│    └───────────────────────┘       │
│                                     │
└─────────────────────────────────────┘
```

### When Connected
```
┌─────────────────────────────────────┐
│    Workout Tracker                  │ ← Blue header
│    Connected to Pavloff Workout Sensor    │
├─────────────────────────────────────┤
│                                     │
│         ● ○ ○                       │ ← Progress dots
│      (blue, gray, gray)             │
│                                     │
│     CURRENT EXERCISE                │
│      Bicep Curls                    │ ← Exercise name
│                                     │
│          REPS                       │
│                                     │
│         5 / 10                      │ ← Large counter
│                                     │
│    ▓▓▓▓▓▓▓▓░░░░░░░░                │ ← Progress bar
│                                     │
│      ╔═══════════╗                 │
│      ║    UP     ║                  │ ← State badge
│      ╚═══════════╝                 │   (green)
│                                     │
│    ┌───────────────────────┐       │
│    │ ⚙ Workout Settings    │       │ ← Gray button
│    └───────────────────────┘       │
│    ┌───────────────────────┐       │
│    │ ↻ Reset Exercise      │       │ ← Orange button
│    └───────────────────────┘       │
│                                     │
└─────────────────────────────────────┘
```

## 2. Setup Screen

```
┌─────────────────────────────────────┐
│ ← Workout Setup                     │ ← Navigation bar
├─────────────────────────────────────┤
│                                     │
│    Set your target reps for each    │
│           exercise                  │
│                                     │
│ ┌─────────────────────────────────┐│
│ │  Bicep Curls                    ││ ← Card 1
│ │                                 ││
│ │  Target Reps:    ⊖  10  ⊕      ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │  Shoulder Press                 ││ ← Card 2
│ │                                 ││
│ │  Target Reps:    ⊖  10  ⊕      ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │  Lateral Raises                 ││ ← Card 3
│ │                                 ││
│ │  Target Reps:    ⊖  10  ⊕      ││
│ └─────────────────────────────────┘│
│                                     │
│                                     │
│    ┌───────────────────────┐       │
│    │   Start Workout       │       │ ← Blue button
│    └───────────────────────┘       │
│                                     │
└─────────────────────────────────────┘
```

## 3. Congratulations Screen

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│            ◉                        │ ← Green circle
│            ✓                        │   with checkmark
│                                     │
│      Congratulations!               │ ← Bold title
│                                     │
│   You've completed your workout!    │
│                                     │
│ ┌─────────────────────────────────┐│
│ │  Workout Summary                ││
│ │                                 ││
│ │  ✓ Bicep Curls        10 reps   ││
│ │  ✓ Shoulder Press     10 reps   ││
│ │  ✓ Lateral Raises     10 reps   ││
│ │                                 ││
│ └─────────────────────────────────┘│
│                                     │
│                                     │
│    ┌───────────────────────┐       │
│    │  Start New Workout    │       │ ← Blue button
│    └───────────────────────┘       │
│    ┌───────────────────────┐       │
│    │        Done           │       │ ← Gray button
│    └───────────────────────┘       │
│                                     │
└─────────────────────────────────────┘
```

## Color Scheme

- **Header Background**: Blue (#007BFF)
- **Progress Dots**: 
  - Current: Blue
  - Completed: Green
  - Upcoming: Gray (transparent)
- **State Badges**:
  - UP: Green
  - DOWN: Blue
  - IDLE: Gray
- **Primary Button**: Blue
- **Secondary Button**: Gray/Orange
- **Progress Bar**: Blue fill on gray background

## Interactive Elements

### Workout Screen
1. **Workout Settings button**: Opens Setup screen as modal
2. **Reset Exercise button**: Resets current exercise rep count to 0
3. **Rep counter**: Updates automatically from ESP32 device
4. **Progress dots**: Visual indicator of exercise progression

### Setup Screen
1. **Plus/Minus buttons**: Increment/decrement target reps (1-50 range)
2. **Start Workout button**: Dismisses modal and returns to workout

### Congratulations Screen
1. **Start New Workout button**: Resets to first exercise and dismisses modal
2. **Done button**: Dismisses modal and returns to workout view

## Automatic Behaviors

1. **App Launch**: Opens directly to Workout Screen
2. **Auto-Connection**: Automatically scans for and connects to ESP32 device
3. **Exercise Progression**: When target reps reached, automatically advances to next exercise
4. **Rep Reset**: When advancing exercise, rep count automatically resets to 0
5. **Workout Completion**: After last exercise completed, automatically shows Congratulations screen
