# UI Changes - Reset Button

## New UI Component

A reset button has been added to the rep counter display. This button allows users to reset the rep count back to zero without needing to restart the device.

## Visual Description

### Button Appearance
- **Color**: Red/Orange (#FF5722)
- **Position**: Below the state indicator in the rep display container
- **Shape**: Rounded rectangle (25px border radius)
- **Size**: 200px minimum width, 15px vertical padding, 40px horizontal padding
- **Text**: "Reset Count" (white, bold, 16px)
- **Elevation**: Shadow effect for depth (5 elevation units)

### Button States

#### Normal State
```
┌─────────────────────────────────┐
│          REPS                   │
│            5                    │
│        ┌────────┐               │
│        │   UP   │               │
│        └────────┘               │
│   Last Update: 2:45:32 PM       │
│                                 │
│   ┌─────────────────────┐       │
│   │   Reset Count       │       │ ← Red button
│   └─────────────────────┘       │
└─────────────────────────────────┘
```

#### Disabled/Resetting State
```
┌─────────────────────────────────┐
│          REPS                   │
│            0                    │
│        ┌────────┐               │
│        │  IDLE  │               │
│        └────────┘               │
│   Last Update: 2:45:35 PM       │
│                                 │
│   ┌─────────────────────┐       │
│   │  Resetting...       │       │ ← Grayed out
│   └─────────────────────┘       │
└─────────────────────────────────┘
```

## User Experience Flow

1. **Before Reset**
   - User has performed several reps (e.g., count shows "5")
   - State shows "UP" or "DOWN"
   - Button is active and clickable

2. **During Reset**
   - User taps "Reset Count" button
   - Button shows "Resetting..." text
   - Button becomes grayed out (disabled)
   - Visual feedback shows operation in progress

3. **After Reset**
   - Success alert appears: "Rep count reset successfully"
   - Count updates to "0"
   - State changes to "IDLE"
   - Button returns to normal state
   - User can continue exercising from zero

## Error Handling

If reset fails:
- Error alert appears: "Failed to reset rep count: [error message]"
- Button returns to normal state
- Count remains unchanged
- User can try again

## Accessibility

- **Touch Target**: Large enough for easy tapping (200px x 45px minimum)
- **Visual Feedback**: Clear state changes (color, text)
- **Error Messages**: User-friendly alert dialogs
- **Disabled State**: Visually distinct to prevent double-taps

## Styling Details

```javascript
resetButton: {
  backgroundColor: '#FF5722',
  paddingHorizontal: 40,
  paddingVertical: 15,
  borderRadius: 25,
  marginTop: 25,
  minWidth: 200,
  shadowColor: '#000',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.25,
  shadowRadius: 3.84,
  elevation: 5,
}

resetButtonDisabled: {
  backgroundColor: '#BDBDBD',
  opacity: 0.6,
}

resetButtonText: {
  fontSize: 16,
  fontWeight: 'bold',
  color: '#FFFFFF',
  textAlign: 'center',
  letterSpacing: 0.5,
}
```

## Integration with Existing UI

The reset button seamlessly integrates with the existing rep display:
- Maintains the same design language (rounded corners, shadows)
- Uses contrasting color to stand out as an action button
- Positioned logically below the data display
- Consistent spacing with other UI elements

## Platform Support

- **iOS**: Full support with native feel
- **Android**: Full support with Material Design principles
- **Responsive**: Adapts to different screen sizes
