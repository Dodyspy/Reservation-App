# Console Logging Fix

## Problem
Xcode console was not showing any `print()` statements from the iOS app, even though the app was running correctly.

## Root Cause
By default, Xcode suppresses console output from `print()` statements due to the unified logging system. Only `NSLog()` and `os_log()` statements are shown by default.

## Solutions Applied

### 1. Added OS_ACTIVITY_MODE Environment Variable
- **Location**: `ReserveApp.xcscheme` → LaunchAction → EnvironmentVariables
- **Setting**: `OS_ACTIVITY_MODE = disable`
- **Effect**: Disables log suppression and allows `print()` statements to appear in console

### 2. Added NSLog Fallback
- **Files Modified**: `ReserveAppApp.swift`
- **Change**: Added `NSLog()` calls alongside `print()` statements
- **Effect**: Critical startup logs now use both `NSLog()` (always visible) and `print()` (cleaner when enabled)

## How to Verify Logs Are Working

### In Xcode:
1. **Show Debug Area**: Press `⇧⌘Y` or View → Debug Area → Show Debug Area
2. **Check Console Pane**: Make sure the right side (console) is visible
3. **Clear Filters**: 
   - Bottom-right search box should be empty
   - Click filter icon and select "All Output"
4. **Run App**: You should now see logs like:

```
2025-11-27 21:52:00.123 ReserveApp[12345:67890] ============================================================
2025-11-27 21:52:00.124 ReserveApp[12345:67890] 🚀 ReserveApp STARTING
2025-11-27 21:52:00.125 ReserveApp[12345:67890] 📱 Bundle ID: fr.casanova.RestaurantManager
============================================================
🚀 ReserveApp STARTING
📱 Bundle ID: fr.casanova.RestaurantManager
🚀 App launching - configuring Firebase and notifications...
```

## Logging Best Practices

### Use NSLog for Critical Logs
```swift
NSLog("Critical error: %@", error.localizedDescription)
```
- Always visible in console
- Includes timestamp and process info
- Slightly slower performance

### Use print() for Debug Logs
```swift
print("Debug info: \(someVariable)")
```
- Cleaner output
- Faster performance
- Only visible when OS_ACTIVITY_MODE=disable

### Use os_log for Production
```swift
import os.log
os_log("User action: %@", log: .default, type: .info, action)
```
- Best for production apps
- Integrates with Console.app
- Supports log levels and categories

## Troubleshooting

### Still No Logs?
1. **Restart Xcode**: Sometimes scheme changes require a restart
2. **Clean Build**: Product → Clean Build Folder (⇧⌘K)
3. **Check Scheme**: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
4. **Verify OS_ACTIVITY_MODE**: Should show `OS_ACTIVITY_MODE = disable`

### Logs Appear But Are Truncated?
- Console has a buffer limit
- Use Console.app (macOS app) for full logs
- Filter by process name: "ReserveApp"

### Want to See System Logs Too?
- Remove `OS_ACTIVITY_MODE=disable`
- Use Console.app instead of Xcode console
- Filter by subsystem or category

## Current Status
✅ OS_ACTIVITY_MODE environment variable added to scheme
✅ NSLog fallback added to critical startup code
✅ App should now show all logs in Xcode console
