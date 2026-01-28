# Extension Building But Not Installing - Investigation

## Status Update

User reports:
- ✅ Extension IS building (visible in build log)
- ✅ Extension exists in `Products/Debug-iphoneos/DeviceActivityMonitorExtension.appex`
- ✅ Extension target has no dependencies (correct)
- ❌ Extension NOT appearing in Console.app logs
- ❌ Apps not re-locking at midnight

## Critical Discovery

The extension is **building successfully** but may not be **installing into the app bundle on the device**.

## Build vs Install

There's an important distinction:

### Build Output (✅ Working)
```
Products/
  Debug-iphoneos/
    esp32Connect.app
    DeviceActivityMonitorExtension.appex  ← Extension builds here
```

### Installed App (❓ Unknown)
```
/var/containers/Bundle/Application/[UUID]/esp32Connect.app/
  PlugIns/
    DeviceActivityMonitorExtension.appex  ← Must be here for iOS to load it
```

## Verification Required

User needs to check the **INSTALLED** app on device:

**Method 1: Via Xcode Devices**
1. Xcode → Window → Devices and Simulators
2. Select device → Installed Apps
3. Find "esp32Connect" (or "Tides")
4. Click gear icon → Show Container
5. Navigate to .app bundle
6. Check if PlugIns/ folder exists with extension

**Method 2: Via Console.app During Install**
Watch for messages during app installation:
```
installd: Installing application [bundle ID]
installd: Embedded extensions: DeviceActivityMonitorExtension
```

## Project Configuration Analysis

### Embed Phase Configuration ✅
```
60D7C9662EB570B10076DBF0 /* Embed Foundation Extensions */ = {
    isa = PBXCopyFilesBuildPhase;
    dstSubfolderSpec = 13;  // 13 = PlugIns folder
    files = (
        60D7C96B2EB573000076DBF0 /* DeviceActivityMonitorExtension.appex */,
    );
}
```
✅ Correctly configured

### Main App Build Phases ✅
```
buildPhases = (
    13B07F871A680F5B00A75B9A /* Sources */,
    13B07F8C1A680F5B00A75B9A /* Frameworks */,
    13B07F8E1A680F5B00A75B9A /* Resources */,
    60D7C9662EB570B10076DBF0 /* Embed Foundation Extensions */,  ← Present
    60D7C9692EB572920076DBF0 /* Copy Files */,
);
```
✅ Embed phase is included

### Target Dependencies ✅
```
dependencies = (
    60D7C9652EB570B10076DBF0 /* PBXTargetDependency */,
    60D7C9682EB570B90076DBF0 /* PBXTargetDependency */,
);
```
✅ Main app depends on extension target

## Possible Reasons Extension Not Installing

Despite correct configuration, extension might not install due to:

### 1. Code Signing Mismatch
**Symptom**: Extension builds but iOS refuses to install it

**Check**:
- Main app and extension must use same development team
- Both must have valid provisioning profiles
- App Group entitlements must match exactly

**In Xcode**:
1. Select "esp32Connect" target → Signing & Capabilities
   - Note the Team
   - Note the Bundle ID: `com.maslowcnc.Tides`
2. Select "DeviceActivityMonitorExtension" target → Signing & Capabilities
   - Must use **same** Team
   - Bundle ID: `com.maslowcnc.Tides.DeviceActivityMonitorExtension`
   - App Groups must include: `group.com.maslowcnc.Tides`

### 2. Installation Method
**Symptom**: Extension installs in Debug but not Release, or vice versa

**Test**: Try both methods:
- Install via Xcode (Run button)
- Install via TestFlight or direct IPA
- Check if behavior differs

### 3. iOS Restrictions After Install
**Symptom**: Extension installs but iOS doesn't trust it yet

**Solution**:
- After first install, device must be unlocked for 24 hours for iOS to trust extension
- Try: Settings → General → VPN & Device Management → Trust certificate

### 4. Provisioning Profile Issues
**Symptom**: Extension missing capabilities in profile

**Check**: Ensure provisioning profile includes:
- Family Controls capability
- App Groups capability
- DeviceActivity entitlement

## Diagnostic Steps

### Step 1: Verify Install (Most Important)
```
1. Install app to device via Xcode
2. Xcode → Devices → Show Container
3. Check if PlugIns/DeviceActivityMonitorExtension.appex exists
```

**If EXISTS**: Extension is installing, issue is runtime (device state, etc.)
**If MISSING**: Extension not installing, code signing or build issue

### Step 2: Check Install Logs
In Console.app, filter by "installd" during installation:
```
installd: Installing bundle: com.maslowcnc.Tides
installd: Scanning for embedded extensions
installd: Found extension: DeviceActivityMonitorExtension
```

### Step 3: Check System Logs for Extension Loading
In Console.app, filter by "SpringBoard" (iOS system):
```
SpringBoard: Loading extension: DeviceActivityMonitorExtension
SpringBoard: Extension loaded successfully
```
OR
```
SpringBoard: Failed to load extension: [error]
```

### Step 4: Verify Code Signing
```bash
# After getting .app from device
codesign -d --entitlements - /path/to/esp32Connect.app
codesign -d --entitlements - /path/to/esp32Connect.app/PlugIns/DeviceActivityMonitorExtension.appex
```

Should show matching team and entitlements.

## Expected vs Actual Behavior

### Expected (Working)
1. Build both targets ✅
2. Embed extension in app bundle ✅
3. Install app + extension to device ❓
4. iOS recognizes extension ❓
5. Extension fires at midnight ❌

### Actual (Current)
1. Build: ✅ Extension builds successfully
2. Embed: ✅ Configuration present in project
3. Install: ❓ Not verified on device
4. Recognize: ❌ No Console logs = not loaded
5. Fire: ❌ Apps not re-locking

## Next Actions for User

### Critical Action
**Verify extension in installed app bundle**:
```
Xcode → Devices → Installed Apps → esp32Connect → Show Container
→ Check PlugIns/DeviceActivityMonitorExtension.appex
```

### If Extension MISSING from Installed App

**Rebuild steps:**
1. Clean build folder (Shift+Cmd+K)
2. Delete derived data
3. In Xcode, select "DeviceActivityMonitorExtension" scheme → Build
4. Then select "esp32Connect" scheme → Build
5. Install to device
6. Check again

**Check code signing:**
- Both targets use same Team
- Both have valid provisioning profiles
- No signing errors in build log

### If Extension PRESENT in Installed App

**Then issue is runtime, not build:**
- Device must be unlocked when extension should fire
- Screen must be on or device charging
- Low Power Mode disables extensions
- First 24 hours after install, iOS may not trust extension

**Test with device unlocked:**
1. Keep device plugged in
2. Set Auto-Lock to "Never"
3. Keep screen on
4. Use time-change test (11:58 PM → 12:01 AM)
5. Watch Console.app for logs

## Summary

The project configuration is correct. Extension is building. The missing piece is:

**Is the extension actually being installed into the app bundle on the device?**

Once we confirm this, we can determine if it's a build/install issue or a runtime/device state issue.
