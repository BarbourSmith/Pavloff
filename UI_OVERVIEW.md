# UI Overview - Auto-Connect Single Screen App

## Screen Layout

The app now has a single screen with two main states: **Searching** and **Connected**.

---

## State 1: Searching for Device

When the device is not connected, the screen shows:

```
╔═══════════════════════════════════════════╗
║                                           ║
║         Exercise Rep Counter              ║
║                                           ║
║  ⊙  Scanning for ESP32_IMU_Stream...     ║
║                                           ║
╠═══════════════════════════════════════════╣
║                                           ║
║                                           ║
║              [Loading Spinner]            ║
║                                           ║
║    Waiting for ESP32_IMU_Stream           ║
║        to be available...                 ║
║                                           ║
║   Make sure your device is powered        ║
║        on and in range.                   ║
║                                           ║
║                                           ║
║                                           ║
╚═══════════════════════════════════════════╝
```

**Header (Blue Background)**
- Title: "Exercise Rep Counter"
- Status: Shows current state with loading indicator
  - "Scanning for ESP32_IMU_Stream..."
  - "Connecting to ESP32_IMU_Stream..."
  - "Discovering services..."
  - "ESP32_IMU_Stream not found. Will retry..."

**Body**
- Large loading spinner
- Waiting message
- Instruction text for user

---

## State 2: Connected and Monitoring

When connected, the screen shows:

```
╔═══════════════════════════════════════════╗
║                                           ║
║         Exercise Rep Counter              ║
║                                           ║
║     Connected to ESP32_IMU_Stream         ║
║                                           ║
╠═══════════════════════════════════════════╣
║                                           ║
║          ESP32_IMU_Stream                 ║
║                                           ║
║  ┌────────────────────────────────────┐  ║
║  │                                    │  ║
║  │            REPS                    │  ║
║  │                                    │  ║
║  │             12                     │  ║
║  │                                    │  ║
║  │         ┌─────────┐                │  ║
║  │         │   UP    │                │  ║
║  │         └─────────┘                │  ║
║  │                                    │  ║
║  │    Last Update: 3:45:23 PM         │  ║
║  │                                    │  ║
║  └────────────────────────────────────┘  ║
║                                           ║
╚═══════════════════════════════════════════╝
```

**Header (Blue Background)**
- Title: "Exercise Rep Counter"
- Status: "Connected to ESP32_IMU_Stream" (white/light text)

**Body**
- Device name
- Rep counter card with:
  - Label "REPS"
  - Large count number (huge, bold, blue)
  - State indicator pill (colored):
    - UP: Green background
    - DOWN: Blue background
    - IDLE: Gray background
  - Timestamp of last update

---

## Color Scheme

### Header
- Background: `#007BFF` (primary blue)
- Title text: White
- Status text: Light color (white/off-white)

### Connection States
- Connected: Light green tint `#E8F5E9`
- Disconnected: Light red/pink tint `#FFEBEE`

### Rep Counter
- Background: `#F8F9FA` (light gray)
- Number color: `#007BFF` (blue)
- Number size: 120px (very large)

### State Indicators
- UP: `#4CAF50` (green)
- DOWN: `#2196F3` (blue)
- IDLE: `#9E9E9E` (gray)
- Text: White

### Page Background
- `#FFFFFF` (white)

---

## Typography

### Header Title
- Font size: 24px
- Font weight: Bold
- Color: White

### Status Text
- Font size: 14px
- Style: Italic when disconnected
- Weight: 600 when connected

### Device Name
- Font size: 20px
- Font weight: Bold
- Color: `#333333`

### "REPS" Label
- Font size: 20px
- Font weight: 600
- Color: `#666`
- Letter spacing: 2px

### Rep Count Number
- Font size: 120px
- Font weight: Bold
- Color: `#007BFF`
- Text shadow for depth

### State Text
- Font size: 22px
- Font weight: Bold
- Color: White
- Letter spacing: 1px

### Instruction Text
- Font size: 14px
- Color: `#999999`

---

## Animations & Interactions

### Loading Indicators
- Small spinner in header during scanning
- Large spinner in body while waiting

### State Transitions
- Smooth fade between scanning and connected states
- No abrupt changes

### Auto-Updates
- Rep count updates in real-time
- State indicator changes color dynamically
- Timestamp updates with each data receive

---

## Spacing & Layout

### Header
- Padding: 20px all sides
- Bottom border: 1px solid `#0056b3`

### Rep Counter Card
- Padding: 30px
- Border radius: 20px
- Shadow: Subtle elevation effect
- Min width: 280px
- Centered in screen

### State Indicator Pill
- Padding: 12px vertical, 30px horizontal
- Border radius: 25px (fully rounded)
- Min width: 150px
- Center aligned

---

## Accessibility

### Visual Hierarchy
- Large, clear rep count number is primary focus
- Color-coded states provide quick visual feedback
- Status messages provide context

### Readability
- High contrast text on backgrounds
- Large fonts for important information
- Clear spacing between elements

### User Feedback
- Always shows current state (scanning, connecting, connected)
- Loading indicators show progress
- Error messages are clear and actionable

---

## Responsive Behavior

### All Screen Sizes
- Content is scrollable if needed
- Rep counter card scales appropriately
- Text remains readable on all sizes

### Orientation
- Works in portrait (primary)
- Adapts to landscape if rotated

---

## Error States

When errors occur, status shows:
- "Connection lost. Retrying..."
- "Bluetooth is PoweredOff. Please enable Bluetooth."
- "Scan error: [message]"
- "Connection failed: [message]"

User sees these in the header status area, and scanning automatically resumes.

---

## Key UX Principles

1. **Zero Learning Curve**: No buttons to press, no navigation to learn
2. **Clear Feedback**: Always shows what the app is doing
3. **Auto-Recovery**: Handles errors without user intervention
4. **Focus on Data**: Rep counter is the primary element when connected
5. **Patient UX**: Shows waiting state gracefully, doesn't timeout

---

## Comparison to Previous Version

### Before (3 Screens)
```
HomeScreen → ConnectionScreen → DataDisplayScreen
   ↑              ↓                      ↓
   └──────────────────── Back ──────────┘
```
- User had to tap "Scan"
- User had to select device
- User had to tap "Connect"
- User navigated between 3 screens

### After (1 Screen)
```
DataDisplayScreen (auto-scanning & auto-connecting)
```
- No user input needed
- Everything automatic
- Single unified interface
- Zero navigation

---

This simplified single-screen design fulfills the requirement for "the whole app should be one screen" while maintaining all core functionality.
