# Screen Layouts - ESP32 Connect Swift App

This document describes the layout and functionality of each screen in the native Swift iOS app.

## Navigation Flow

```
HomeView (Device Scanning)
    ↓ [Select devices & tap "Proceed to Connect"]
ConnectionView (Connection Status)
    ↓ [Tap "Show Data" when connected]
DataDisplayView (Real-time IMU Data)
    ↓ [Tap "Stop Monitoring"]
Back to HomeView
```

## Screen 1: HomeView (Device Scanning)

### Purpose
Scan for and select ESP32 BLE devices for connection.

### Layout Description

```
┌─────────────────────────────────────┐
│ ← BLE Device Scanner                │  Navigation Bar (Blue)
├─────────────────────────────────────┤
│                                     │
│  Select Devices (1 or 2)            │  Title
│                                     │
│  ┌─────────────────────────────┐   │
│  │   Scan for Devices          │   │  Scan Button (Blue)
│  └─────────────────────────────┘   │  or "Stop Scan" (Red when scanning)
│                                     │
│  ⭕ Scanning... (10s timeout)       │  Progress indicator (when scanning)
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │ 📱 ESP32-Device-01          │   │  Device item (unselected)
│  │ A1B2C3D4-...                │   │  Gray border
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📱 ESP32-Device-02          │   │  Device item (selected)
│  │ E5F6G7H8-...                │   │  Blue border & light blue background
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📱 ESP32-Sensor-01          │   │  Another device item
│  │ I9J0K1L2-...                │   │
│  └─────────────────────────────┘   │
│                                     │
│                                     │  Scrollable list
│                                     │
├─────────────────────────────────────┤
│  2 device(s) selected               │  Footer (white background)
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Proceed to Connect         │   │  Action button (Blue if devices selected,
│  └─────────────────────────────┘   │                  Gray if none selected)
└─────────────────────────────────────┘
```

### UI Elements

**Header Section (White background)**
- Title: "Select Devices (1 or 2)" - Bold, centered
- Scan Button: Full-width button
  - Blue when not scanning: "Scan for Devices"
  - Red when scanning: "Stop Scan"
- Progress indicator with text when scanning

**Device List (Scrollable, light gray background)**
- Each device shown as a card:
  - Device name (bold)
  - UUID (smaller, gray text)
  - Tap to select/deselect
  - Selected: Blue border + light blue background
  - Unselected: Gray border + white background

**Footer Section (White background)**
- Selected count display
- "Proceed to Connect" button
  - Blue when 1-2 devices selected
  - Gray (disabled) when none selected

### User Interactions
1. Tap "Scan for Devices" to start scanning
2. Tap device cards to select/deselect (max 2)
3. Tap "Proceed to Connect" to navigate to ConnectionView

---

## Screen 2: ConnectionView (Connection Status)

### Purpose
Display real-time connection status for each selected device.

### Layout Description

```
┌─────────────────────────────────────┐
│ ← Connecting...                     │  Navigation Bar (Blue)
├─────────────────────────────────────┤
│                                     │
│  Device Connection Status           │  Title (Bold, centered)
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │                             │   │  Status container (white card)
│  │  ESP32-Device-01            │   │  Device name
│  │                             │   │
│  │              ⭕ Connecting...│   │  Status (Gray + spinner)
│  │                             │   │
│  ├─────────────────────────────┤   │  Divider
│  │                             │   │
│  │  ESP32-Device-02            │   │  Device name
│  │                             │   │
│  │              ✅ Connected    │   │  Status (Green)
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Show Data for 1 Device(s)  │   │  Action button (Blue when devices connected,
│  └─────────────────────────────┘   │                  Gray if none connected)
│                                     │
└─────────────────────────────────────┘
```

### UI Elements

**Status Display**
- White card with device list
- Each device shows:
  - Name (left-aligned, bold)
  - Status (right-aligned) with appropriate color:
    - "Pending..." (Gray)
    - "Connecting..." (Gray + spinner)
    - "Discovering..." (Gray + spinner)
    - "Connected" (Green)
    - "Failed: [error]" (Red)

**Action Button**
- "Show Data for X Device(s)"
- Enabled (blue) only when at least one device is connected
- Disabled (gray) when no devices connected

### Connection Process
1. Auto-starts connecting to all selected devices
2. Shows real-time progress for each device
3. Displays final status (Connected/Failed)
4. Enables "Show Data" button when ready

### User Interactions
1. View connection progress (automatic)
2. Tap "Show Data" when devices are connected
3. Navigate back to rescan if connection fails

---

## Screen 3: DataDisplayView (Real-time IMU Data)

### Purpose
Display real-time accelerometer and gyroscope data from connected devices.

### Layout Description

```
┌─────────────────────────────────────┐
│ ← Live IMU Data                     │  Navigation Bar (Blue)
├─────────────────────────────────────┤
│                                     │  Scrollable content
│  Live IMU Data                      │  Title (Bold, centered)
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ESP32-Device-01             │   │  Device name (bold)
│  │                             │   │
│  │ Accelerometer               │   │  Sensor title (blue)
│  │                             │   │
│  │ ┌────┐  ┌────┐  ┌────┐     │   │  Data boxes (light blue bg)
│  │ │ X  │  │ Y  │  │ Z  │     │   │
│  │ │0.12│  │-0.45│ │9.81│     │   │  Values (bold, blue)
│  │ └────┘  └────┘  └────┘     │   │
│  │                             │   │
│  │ Updated: 3:45:12 PM         │   │  Timestamp (small, gray)
│  │                             │   │
│  ├─────────────────────────────┤   │  Divider
│  │                             │   │
│  │ Gyroscope                   │   │  Sensor title (green)
│  │                             │   │
│  │ ┌────┐  ┌────┐  ┌────┐     │   │  Data boxes (light green bg)
│  │ │ X  │  │ Y  │  │ Z  │     │   │
│  │ │0.05│  │-0.02│ │0.01│     │   │  Values (bold, green)
│  │ └────┘  └────┘  └────┘     │   │
│  │                             │   │
│  │ Updated: 3:45:12 PM         │   │  Timestamp (small, gray)
│  │                             │   │
│  │ Last Update: 3:45:12 PM     │   │  Device update time (right-aligned)
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │  Another device card (if 2 devices)
│  │ ESP32-Device-02             │   │
│  │ [Similar layout...]          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     Stop Monitoring         │   │  Stop button (Red)
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### UI Elements

**Device Data Cards** (one per connected device)
- White card with shadow
- Device name at top (bold)
- Accelerometer section (blue accent):
  - Title "Accelerometer" (blue)
  - Three data boxes (X, Y, Z) with light blue background
  - Values formatted to 2 decimal places (bold, blue)
  - Update timestamp (small, gray)
- Divider line
- Gyroscope section (green accent):
  - Title "Gyroscope" (green)
  - Three data boxes (X, Y, Z) with light green background
  - Values formatted to 2 decimal places (bold, green)
  - Update timestamp (small, gray)
- Last device update time (right-aligned, small)

**Stop Button**
- Full-width red button at bottom
- "Stop Monitoring" text
- Disconnects all devices and returns to HomeView

### Data Updates
- Values update in real-time as BLE notifications arrive
- Timestamps show when each sensor was last updated
- No manual refresh needed - automatic updates

### User Interactions
1. View real-time data (automatic updates)
2. Scroll to see all connected devices (if multiple)
3. Tap "Stop Monitoring" to disconnect and return home

---

## Color Scheme

### Primary Colors
- **Blue (#007BFF)**: Primary actions, accelerometer data, navigation bar
- **Green (#28A745)**: Success states, gyroscope data
- **Red (#F44336)**: Error states, stop actions
- **Gray (#6c757d)**: Secondary text, pending states

### Backgrounds
- **Light Gray (#F8F9FA)**: App background
- **White (#FFFFFF)**: Cards and containers
- **Light Blue**: Accelerometer data boxes (blue with 0.1 opacity)
- **Light Green**: Gyroscope data boxes (green with 0.1 opacity)

### Text
- **Primary**: Black (default iOS)
- **Secondary**: Gray (#6c757d)
- **Success**: Green (#28A745)
- **Error**: Red (#F44336)

---

## Design Principles

1. **Native iOS Design**: Follows Apple's Human Interface Guidelines
2. **Clear Hierarchy**: Important information is prominent
3. **Consistent Spacing**: Standard iOS padding and margins
4. **Color Coding**: Different sensors use different colors for clarity
5. **Real-time Feedback**: Loading states and progress indicators
6. **Accessibility**: High contrast, readable fonts, clear touch targets

---

## Responsive Design

All screens adapt to different iPhone sizes:
- ScrollViews for content that may not fit
- Flexible layouts that expand to fill available space
- Safe area handling for notched devices
- Consistent padding on all devices

---

## Animations

SwiftUI provides smooth, native animations for:
- Screen transitions (slide from right)
- Button presses (scale effect)
- List updates (fade in/out)
- State changes (smooth color transitions)
