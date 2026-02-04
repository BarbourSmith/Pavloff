# Event Log Export Feature

## Overview

Added copy and export functionality to the Event Log view, allowing users to easily share event logs for debugging purposes.

## Features Added

### 1. Copy to Clipboard

Users can copy the entire event log to the clipboard with a single tap:

1. Open Event Log
2. Tap the menu button (ellipsis icon ⋯) in the top-left corner
3. Select "Copy to Clipboard"
4. Confirmation alert appears
5. Paste anywhere (Notes, Messages, GitHub issues, etc.)

### 2. Share Log (iOS Share Sheet)

Users can share the event log using the native iOS share sheet:

1. Open Event Log
2. Tap the menu button (ellipsis icon ⋯) in the top-left corner
3. Select "Share Log"
4. iOS share sheet appears with options:
   - Messages
   - Mail
   - Notes
   - Files (save to iCloud Drive or local)
   - AirDrop
   - Any other compatible apps

### 3. Formatted Text Output

The exported log is formatted as plain text with clear structure:

```
Pavloff Event Log
==================
Exported: February 4, 2026 at 3:54 PM
Total Events: 5

[2/3/26, 11:59 PM] Midnight Trigger
Source: Extension
Message: Midnight interval started for activity: workoutSchedule
---

[2/3/26, 11:59 PM] Info
Source: Extension
Message: Workout not completed today - will reapply shields
---

[2/3/26, 12:00 AM] Apps Blocked
Source: Extension
Message: Successfully reapplied shields for 5 apps
---
```

## Use Cases

### 1. Debugging Extension Issues

When the extension isn't triggering at midnight:
- Export the log
- Check for "Daily monitoring schedule registered successfully" message
- Check for midnight trigger events
- Share with developer if issues persist

### 2. Reporting Issues

When filing a GitHub issue:
- Copy the event log
- Paste directly into the issue description
- Provides complete diagnostic information
- Shows exactly what happened and when

### 3. Support Requests

When asking for help:
- Share via Messages or Mail
- Complete event history available
- No need to take screenshots
- All timestamps and details preserved

## Implementation Details

### Components Added

**Menu Button (Toolbar)**:
- Location: Top-left corner of Event Log view
- Icon: Ellipsis circle (⋯)
- Disabled when no events exist

**Menu Options**:
1. Copy to Clipboard (clipboard icon)
2. Share Log (share icon)

**Copy Confirmation**:
- Alert shown after copying
- "OK" button to dismiss
- Confirms successful copy operation

**Share Sheet**:
- Native `UIActivityViewController`
- Full iOS sharing capabilities
- Standard iOS behavior

### Code Structure

**EventLogView.swift**:
- Added `@State` variables for sheet and alert presentation
- Added `formatEventsAsText()` function
- Added `copyToClipboard()` function
- Added menu with copy/share options
- Added `ActivityViewController` wrapper for share sheet

**ActivityViewController**:
- UIKit bridge to SwiftUI
- Wraps `UIActivityViewController`
- Provides native iOS share experience

## Format Specification

### Header Section
```
Pavloff Event Log
==================
Exported: [Long date and time]
Total Events: [Count]
```

### Event Entry
```
[[Short date and time]] [Event Type]
Source: [Source name]
Message: [Event message]
---
```

### Example Full Export
```
Pavloff Event Log
==================
Exported: February 4, 2026 at 3:54:30 PM EST
Total Events: 8

[2/4/26, 8:00 PM] App Launched
Source: WorkoutView
Message: App launched - workout not completed today, enabling blocking
---

[2/4/26, 8:00 PM] Apps Blocked
Source: ScreenTimeManager
Message: App blocking enabled: 5 apps, 0 categories
---

[2/4/26, 8:00 PM] Info
Source: ScreenTimeManager
Message: Daily monitoring schedule registered successfully - extension should trigger at midnight
---

[2/4/26, 9:30 PM] Workout Completed
Source: WorkoutView
Message: Workout completed for today - apps unlocked
---

[2/4/26, 9:30 PM] Apps Unlocked
Source: ScreenTimeManager
Message: Apps unlocked - workout completed
---

[2/4/26, 12:00 AM] Midnight Trigger
Source: Extension
Message: Midnight interval started for activity: workoutSchedule
---

[2/4/26, 12:00 AM] Info
Source: Extension
Message: Workout not completed today - will reapply shields
---

[2/4/26, 12:00 AM] Apps Blocked
Source: Extension
Message: Successfully reapplied shields for 5 apps
---
```

## User Experience

### Visual Changes

**Before**:
- Only trash (delete) button in toolbar
- No way to export or share logs

**After**:
- Menu button (⋯) in top-left
- Trash button remains in top-right
- Menu reveals copy and share options
- Confirmation alerts provide feedback

### Accessibility

- All buttons have proper labels for VoiceOver
- System icons (SF Symbols) are recognizable
- Standard iOS patterns (share sheet)
- Consistent with iOS Human Interface Guidelines

## Testing

### Manual Test Cases

1. **Empty Log**:
   - ✅ Menu button should be disabled
   - ✅ No export possible when no events

2. **Copy to Clipboard**:
   - ✅ Tap menu → Copy to Clipboard
   - ✅ Confirmation alert appears
   - ✅ Can paste into Notes app
   - ✅ Format matches specification

3. **Share via Messages**:
   - ✅ Tap menu → Share Log
   - ✅ Share sheet appears
   - ✅ Select Messages
   - ✅ Log appears as text in compose field
   - ✅ Can send successfully

4. **Share via Mail**:
   - ✅ Tap menu → Share Log
   - ✅ Select Mail
   - ✅ Log appears in email body
   - ✅ Can send successfully

5. **Save to Files**:
   - ✅ Tap menu → Share Log
   - ✅ Select "Save to Files"
   - ✅ Choose location (iCloud Drive or local)
   - ✅ File saves successfully
   - ✅ File opens as text

6. **Multiple Events**:
   - ✅ Create several events
   - ✅ Export log
   - ✅ All events included
   - ✅ Correct order (newest first)
   - ✅ Proper formatting

## Benefits

### For Users
- ✅ Easy to share diagnostic information
- ✅ Can report issues with complete data
- ✅ No need to take multiple screenshots
- ✅ Copy/paste into any app

### For Developers
- ✅ Complete event history in bug reports
- ✅ Exact timestamps for debugging
- ✅ Source information for each event
- ✅ Easy to identify patterns

### For Support
- ✅ Users can easily provide logs
- ✅ Standard text format
- ✅ No special tools needed to read
- ✅ Can be analyzed programmatically

## Future Enhancements

Potential improvements for future versions:

1. **Filter Before Export**:
   - Export only certain event types
   - Date range filtering
   - Source filtering

2. **Format Options**:
   - JSON format for programmatic analysis
   - CSV format for spreadsheet import
   - Markdown format for documentation

3. **Automatic Export**:
   - Auto-export on specific events (errors)
   - Scheduled exports
   - Cloud backup integration

4. **Email Template**:
   - Pre-filled email with log
   - Standard subject line
   - Context information included

## Related Documentation

- **EVENT_LOG_FEATURE.md** - Overview of event logging system
- **EXTENSION_TROUBLESHOOTING.md** - How to use logs for debugging
- **INFO_PLIST_FIX.md** - Extension configuration fix

## Commit

- **6560afd** - Add copy and share functionality to Event Log view

## Files Changed

- `ios/esp32Connect/EventLogView.swift` - Added export functionality
