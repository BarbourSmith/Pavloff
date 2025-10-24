# Screen Time Controls - UI Changes

## Setup View (Workout Settings)

### New Section Added

After the exercise configuration rows, a new "Screen Time Controls" section is displayed:

```
┌─────────────────────────────────────────────┐
│                                             │
│  Screen Time Controls                      │
│                                             │
│  Block selected apps from midnight until   │
│  you complete your workout                 │
│                                             │
│  [Toggle] Enable App Blocking         [ON] │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 🛑  Select Apps to Block         ›   │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  ✓ Apps selected for blocking              │
│                                             │
└─────────────────────────────────────────────┘
```

### States

**Disabled State:**
- Toggle is OFF
- "Select Apps to Block" button is hidden

**Enabled - Not Authorized:**
- Toggle is ON
- Shows: "⚠️ Screen Time authorization required"
- "Select Apps to Block" button is hidden

**Enabled - Authorized - No Apps Selected:**
- Toggle is ON
- "Select Apps to Block" button is visible
- No checkmark message shown

**Enabled - Authorized - Apps Selected:**
- Toggle is ON
- "Select Apps to Block" button is visible
- Green checkmark: "✓ Apps selected for blocking"

## Workout View Header

### Original Header
```
┌─────────────────────────────────────────────┐
│          Workout Tracker                    │
│                                             │
│    🔄 Scanning for device...                │
└─────────────────────────────────────────────┘
```

### New Header (Screen Time Disabled)
```
┌─────────────────────────────────────────────┐
│          Workout Tracker                    │
│                                             │
│    ✓ Connected to Pavloff Workout Sensor   │
└─────────────────────────────────────────────┘
```

### New Header (Apps Blocked)
```
┌─────────────────────────────────────────────┐
│          Workout Tracker                    │
│                                             │
│    ✓ Connected to Pavloff Workout Sensor   │
│                                             │
│    [ 🔒 Apps Blocked ]                      │
└─────────────────────────────────────────────┘
```
*Status badge has orange background*

### New Header (Apps Unlocked)
```
┌─────────────────────────────────────────────┐
│          Workout Tracker                    │
│                                             │
│    ✓ Connected to Pavloff Workout Sensor   │
│                                             │
│    [ 🔓 Apps Unlocked ]                     │
└─────────────────────────────────────────────┘
```
*Status badge has green background*

## App Picker Modal

When user taps "Select Apps to Block", the system presents Apple's FamilyActivityPicker:

```
┌─────────────────────────────────────────────┐
│  Cancel                         Done        │
│                                             │
│  Select Apps                                │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ Search apps and categories            │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  Apps                                       │
│  ☑️ Safari                                  │
│  ☐ Mail                                     │
│  ☑️ Instagram                               │
│  ☐ Twitter                                  │
│  ☑️ TikTok                                  │
│                                             │
│  Categories                                 │
│  ☐ Social Networking                        │
│  ☑️ Games                                   │
│  ☐ Entertainment                            │
│                                             │
└─────────────────────────────────────────────┘
```

## User Journey

### First Time Setup
1. User opens app → sees Workout Tracker
2. Taps "Workout Settings" → sees Setup View
3. Scrolls down to "Screen Time Controls" section
4. Toggles "Enable App Blocking" ON
5. System shows authorization prompt
6. User grants Screen Time permission
7. "Select Apps to Block" button appears
8. User taps button → App Picker modal opens
9. User selects apps/categories to block
10. Taps "Done" → returns to Setup View
11. Green checkmark confirms selection
12. Taps "Start Workout" → returns to Workout View
13. Header shows "🔒 Apps Blocked" badge

### Daily Usage
1. User opens app in morning
2. If workout not completed today:
   - Header shows "🔒 Apps Blocked"
   - Selected apps are blocked with Screen Time shield
3. User performs workout
4. After completing all exercises:
   - Congratulations screen appears
   - Apps automatically unlock
   - Header updates to "🔓 Apps Unlocked"
5. User can access previously blocked apps

### Changing Settings
1. User taps "Workout Settings" during workout
2. Can modify:
   - Toggle blocking on/off
   - Change selected apps
   - Adjust exercise targets
3. Changes take effect immediately
4. If blocking disabled, apps unlock instantly

## Visual Design

### Colors
- **Blocked Badge**: Orange background (#FF9800 with 30% opacity)
- **Unlocked Badge**: Green background (#28A745 with 30% opacity)
- **Button**: Blue (#007BFF)
- **Warning**: Orange text (#FF9800)
- **Success**: Green text (#28A745)

### Icons
- Blocked: `lock.fill` (SF Symbol)
- Unlocked: `lock.open.fill` (SF Symbol)
- Settings: `gearshape.fill` (SF Symbol)
- Select Apps: `hand.raised.fill` (SF Symbol)
- Checkmark: `checkmark.circle.fill` (SF Symbol)

### Typography
- Section Title: `.headline` (bold)
- Description: `.subheadline` (gray)
- Status Badge: `.caption` (semibold)
- Button: `.body` (semibold)

## Interaction Patterns

### Toggle Switch
- Standard iOS toggle
- Tint color: Blue
- Haptic feedback on toggle
- Async authorization request on enable

### Button Tap
- Standard iOS button
- Tap → present modal sheet
- No animation delay
- System-managed presentation

### Status Badge
- Non-interactive
- Auto-updates based on state
- Smooth fade transition
- Positioned below connection status

## Accessibility

### VoiceOver
- Toggle: "Enable App Blocking, switch, currently [on/off]"
- Button: "Select Apps to Block, button"
- Status: "Apps Blocked" or "Apps Unlocked"
- Description: Reads full explanation text

### Dynamic Type
- All text scales with system font size
- Layout adjusts for larger text
- Buttons remain tappable at all sizes

### Color Contrast
- Badge text: White on colored background
- Meets WCAG AA standards
- Works in both light and dark mode

## Error States

### Authorization Denied
```
┌─────────────────────────────────────────────┐
│  Screen Time Controls                      │
│                                             │
│  [Toggle] Enable App Blocking        [OFF] │
│                                             │
│  ⚠️ Screen Time authorization required     │
│                                             │
│  Go to Settings > Screen Time to grant     │
│  permission to this app.                   │
└─────────────────────────────────────────────┘
```

### No Apps Selected
```
┌─────────────────────────────────────────────┐
│  Screen Time Controls                      │
│                                             │
│  [Toggle] Enable App Blocking         [ON] │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 🛑  Select Apps to Block         ›   │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  ℹ️ No apps selected yet                   │
└─────────────────────────────────────────────┘
```

## Platform Behavior

### iOS System Integration
- Blocked apps show Screen Time shield
- Shield displays custom message
- Tapping shield shows usage info
- System manages enforcement
- No additional user action needed

### Notification
- No custom notifications implemented
- System may show Screen Time notifications
- User receives standard iOS alerts
- App works silently in background
