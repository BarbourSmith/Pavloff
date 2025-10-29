# Workout Streak Feature

## Overview
The app now includes a Duolingo-style streak feature that tracks how many consecutive days you've exercised, motivating users to maintain their workout routine.

## Quick Start

1. **Complete your first workout** - Your streak starts at 1 day
2. **Check the header** - See your current streak with a 🔥 emoji
3. **Complete workouts daily** - Your streak increases each consecutive day
4. **Celebrate milestones** - Special messages appear at 7, 30, 50, 100, and 365 days

## Features

### 🔥 Streak Tracking
- **Current Streak**: Tracks consecutive days with completed workouts
- **Longest Streak**: Remembers your personal best
- **Automatic Updates**: Streak updates when you complete all exercises
- **Smart Detection**: 
  - Multiple workouts on the same day don't affect your streak
  - Workouts on consecutive days increase your streak by 1
  - Missing a day resets your streak to 1

### 📊 Visual Indicators

#### Workout Screen Header
- Displays current streak: "🔥 X day streak"
- Shows when streak > 0
- Styled with orange background for visibility
- Updates in real-time when workout is completed

#### Congratulations Screen
- **Large Streak Display**: Shows current streak with fire emoji
- **Personal Record Badge**: "New Personal Record! 🎉" when you beat your longest streak
- **Best Streak**: Shows your longest streak for comparison
- **Milestone Messages**: Special celebrations for achievements:
  - 7 days: "🎉 7 Day Streak! One week strong!"
  - 30 days: "🔥 30 Day Streak! A full month!"
  - 50 days: "💪 50 Day Streak! Incredible!"
  - 100 days: "🏆 100 Day Streak! You're unstoppable!"
  - 365 days: "👑 365 Day Streak! A full year! Legendary!"

## How It Works

### Streak Logic

```
Day 1: Complete workout → Streak = 1
Day 2: Complete workout → Streak = 2
Day 3: Skip workout → Streak resets to 0
Day 4: Complete workout → Streak = 1
Day 5: Complete workout → Streak = 2
Day 5: Complete 2nd workout → Streak still = 2 (no change for same day)
```

### Data Persistence
All streak data is saved locally using UserDefaults:
- `currentWorkoutStreak`: Your current consecutive day count
- `longestWorkoutStreak`: Your best streak ever
- `lastWorkoutDate`: Last day you completed a workout

The app automatically:
1. Loads your streak when you open the app
2. Checks if today is consecutive to your last workout
3. Updates streak appropriately when you finish
4. Saves all changes immediately

### Smart Streak Updates

The `StreakManager` class handles all streak logic:

**First Workout Ever**
- Sets streak to 1
- Records today as last workout date

**Same Day Workout**
- Detects if you already worked out today
- Keeps streak unchanged (prevents gaming the system)

**Consecutive Day**
- Detects if last workout was yesterday
- Increments streak by 1
- Updates longest streak if new record

**Missed Day(s)**
- Detects if you skipped a day or more
- Resets current streak to 1
- Keeps longest streak preserved

## Technical Implementation

### StreakManager Class
Location: `ios/esp32Connect/Models.swift`

```swift
class StreakManager: ObservableObject {
    @Published private(set) var currentStreak: Int
    @Published private(set) var longestStreak: Int
    
    func checkAndUpdateStreak()
    func getStreakStatus() -> (current: Int, longest: Int, isNewRecord: Bool)
    func isMilestone(_ streak: Int) -> Bool
    func getMilestoneMessage(_ streak: Int) -> String?
}
```

### Integration Points

**WorkoutView.swift**
- Initializes `@StateObject private var streakManager = StreakManager.shared`
- Displays streak in header
- Calls `streakManager.checkAndUpdateStreak()` on workout completion

**CongratulationsView.swift**
- Shows detailed streak information
- Displays milestone messages
- Shows personal record badge

## Tips for Users

1. **Build the Habit**: Start with a realistic goal like 7 consecutive days
2. **Track Progress**: Check your streak daily to stay motivated
3. **Plan Ahead**: Schedule workouts to avoid breaking your streak
4. **Celebrate Milestones**: Enjoy the special messages at streak milestones
5. **Recovery Days**: Remember that missing a day resets your streak - plan rest days strategically

## Future Enhancements (Ideas)

- Weekly streak statistics
- Streak recovery (1 free skip per month)
- Social sharing of milestone achievements
- Streak notifications/reminders
- Longest streak leaderboard among friends

---

**Remember**: The streak feature is designed to motivate consistency, not perfection. Even if you break a streak, starting fresh helps rebuild the habit!
