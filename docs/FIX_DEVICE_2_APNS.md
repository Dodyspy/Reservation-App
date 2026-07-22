# Fix APNS Token Issue on Device 2

## Problem
Device 2 is not receiving APNS token even though it's a real device with iOS 26.
Device 1 with same iOS version works perfectly.

## Root Cause
The `didRegisterForRemoteNotificationsWithDeviceToken` callback is never being called on Device 2.
This is a device-specific issue, not a code issue.

## Solution Steps

### Step 1: Complete App Removal on Device 2

1. **Delete the app completely**:
   - Long press app icon
   - Tap "Remove App"
   - Select "Delete App" (not "Remove from Home Screen")
   
2. **Verify app is completely removed**:
   - Check Settings → General → iPhone Storage
   - Ensure ReserveApp is not listed

3. **Force restart Device 2**:
   - **iPhone 8 or later**: 
     - Press Volume Up, release
     - Press Volume Down, release
     - Hold Side button until Apple logo
   - **iPhone 7**: 
     - Hold Volume Down + Side button until Apple logo
   - **iPhone 6s or earlier**: 
     - Hold Home + Top button until Apple logo

### Step 2: Reset Network Settings (Optional but Recommended)

This clears any stale APNS connections:

1. Go to **Settings → General → Transfer or Reset iPhone**
2. Tap **Reset**
3. Tap **Reset Network Settings**
4. Enter passcode
5. Confirm reset
6. Device will restart

**Note:** This will forget Wi-Fi passwords, so have them ready.

### Step 3: Clean Build in Xcode

1. In Xcode, select Device 2 as target
2. **Product → Clean Build Folder** (⇧⌘K)
3. Close Xcode completely
4. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/ReserveApp-*
   ```
5. Reopen Xcode

### Step 4: Reinstall App on Device 2

1. Connect Device 2 to Mac via USB
2. Select Device 2 in Xcode device dropdown
3. **Product → Run** (⌘R)
4. Wait for app to install and launch

### Step 5: Grant Permissions Carefully

When app launches:

1. **Notification Permission Prompt**:
   - Tap **"Allow"**
   - Do NOT tap "Don't Allow"

2. **Verify in iOS Settings**:
   - Go to **Settings → ReserveApp → Notifications**
   - Ensure ALL toggles are ON:
     - ✅ Allow Notifications
     - ✅ Lock Screen
     - ✅ Notification Center
     - ✅ Banners
     - ✅ Sounds
     - ✅ Badges

3. **Check Background App Refresh**:
   - Go to **Settings → General → Background App Refresh**
   - Ensure it's ON globally
   - Ensure ReserveApp is ON

### Step 6: Check Logs in Xcode

With Device 2 connected to Xcode, check console for:

**✅ SUCCESS - You should see:**
```
🚀 App launching - configuring Firebase and notifications...
🔔 Requesting notification permissions...
🔔 Notification permission granted: true
📱 Calling UIApplication.shared.registerForRemoteNotifications()...
🎉 APNS device token received: a1b2c3d4e5f6...
✅ APNS device token registered with Firebase Messaging
🔑 FCM token refreshed after APNS registration: fl-su9fEqkU...
✅ Successfully subscribed to restaurant topic: casanova-reservations
✅ Device token saved for restaurant CASANOVA2024
```

**❌ FAILURE - If you still see:**
```
📱 Calling UIApplication.shared.registerForRemoteNotifications()...
❌ Failed to subscribe to topic: No APNS token specified
```

Then proceed to Step 7.

### Step 7: Check Provisioning Profile on Device 2

1. In Xcode, with Device 2 selected:
   - Go to **Signing & Capabilities** tab
   - Check **Provisioning Profile** name
   - Check **Team** is selected

2. **Refresh provisioning profiles**:
   - Xcode → Settings → Accounts
   - Select your Apple ID
   - Click **Download Manual Profiles**
   - Wait for download to complete

3. **Verify Push Notifications capability**:
   - In **Signing & Capabilities** tab
   - Ensure **Push Notifications** is listed
   - If not, click **+ Capability** and add it

4. **Clean and rebuild**:
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Run (⌘R)

### Step 8: Compare Device Configurations

Check these settings on BOTH devices:

| Setting | Device 1 (✅ Works) | Device 2 (❌ Fails) |
|---------|-------------------|-------------------|
| iOS Version | 26.x | 26.x |
| Notifications Allowed | ✅ | ? |
| Lock Screen Enabled | ✅ | ? |
| Background Refresh | ON | ? |
| Low Power Mode | OFF | ? |
| Focus Mode | OFF | ? |
| Network Connected | ✅ | ? |
| VPN Active | NO | ? |

### Step 9: Check for Device Restrictions

Some corporate or parental controls can block APNS:

1. **Settings → Screen Time → Content & Privacy Restrictions**
   - If enabled, check **Allowed Apps**
   - Ensure notifications are not restricted

2. **Settings → General → VPN & Device Management**
   - Check if any MDM profiles are installed
   - Corporate profiles may block APNS

### Step 10: Test APNS Connectivity

The network errors in your logs suggest connectivity issues:
```
nw_endpoint_flow_failed_with_error [C1 2a00:1450:4007:813::200a.443 failed parent-flow (unsatisfied (No network route), ipv4, dns)]
TCP Conn 0x104223d40 Failed : error 0:50 [50]
```

**Test network on Device 2:**

1. **Disable VPN** (if active)
2. **Switch networks**:
   - If on Wi-Fi, try cellular
   - If on cellular, try different Wi-Fi
3. **Test APNS connectivity**:
   - Open Safari
   - Visit: https://api.push.apple.com
   - Should load (even if blank page)

4. **Toggle Airplane Mode**:
   - Enable Airplane Mode
   - Wait 10 seconds
   - Disable Airplane Mode
   - Wait for network to reconnect
   - Relaunch app

## Advanced Diagnostics

### Add More Logging to Detect the Issue

Let me add additional logging to help diagnose why the callback isn't firing.

The issue might be that the error callback IS being called but silently. Let's add NSLog to ensure we see it.

### Check Apple System Status

1. Visit: https://www.apple.com/support/systemstatus/
2. Check if **Apple Push Notification service** is operational
3. If there's an outage, wait and try again later

### Check Date & Time Settings

Incorrect date/time can cause APNS certificate validation to fail:

1. **Settings → General → Date & Time**
2. Ensure **Set Automatically** is ON
3. Verify date and time are correct

## If Nothing Works

### Last Resort Options:

1. **Backup and Restore Device 2**:
   - Backup to iCloud or Mac
   - Settings → General → Transfer or Reset iPhone → Erase All Content and Settings
   - Restore from backup
   - Reinstall app

2. **Test with Different Apple ID**:
   - Sign out of Apple ID on Device 2
   - Sign in with different Apple ID
   - Reinstall app
   - Test notifications

3. **Contact Apple Support**:
   - If Device 2 consistently fails to get APNS tokens across multiple apps
   - There may be a hardware or account-level issue
   - Apple Support can check APNS registration on their end

## Expected Result

After following these steps, Device 2 should show:

```
🎉 APNS device token received: [64-character hex string]
✅ APNS device token registered with Firebase Messaging
✅ Successfully subscribed to restaurant topic: casanova-reservations
```

Then test:
1. Kill app completely (swipe up and close)
2. Make reservation on website
3. Notification should appear on Device 2 lock screen

## Summary

**Most Likely Fix**: Complete app removal + force restart + clean reinstall

**If That Fails**: Network settings reset + provisioning profile refresh

**If Still Fails**: Device-specific restriction or hardware issue

The fact that Device 1 works proves the code is correct. This is a Device 2 configuration or network issue.
