# Security Audit (Public Repo Readiness)

Date: 2026-05-19

## Findings

### 1) Hardcoded OTA Wi‑Fi password (credential)
- `Firmware/src/esp1/main.cpp`: `#define OTA_AP_PASSWORD "pavloff123"`
- `ios/esp32Connect/FirmwareUpdateManager.swift`: `static let apPassword = "pavloff123"`

This is a real credential value and should be treated as sensitive.

### 2) Apple Developer Team ID in Xcode project metadata
- `ios/esp32Connect.xcodeproj/project.pbxproj`: `DEVELOPMENT_TEAM = Y29YA968X5;`

This is not typically a secret, but it is account-identifying metadata you may prefer to remove before making the repository public.

## Recommended actions before making repo public

1. Rotate/change OTA AP credentials used by devices and app documentation.
2. Consider replacing `DEVELOPMENT_TEAM` in project settings with a neutral value for open-source distribution.
3. If any sensitive credential has ever been committed, treat it as exposed and rotate it even if removed in later commits.

## What was checked

- Regex scan for common secrets (API keys, tokens, passwords, private keys).
- Search for sensitive file types (keys, certs, provisioning profiles, env files).
- Focused review of iOS and firmware update code paths.
