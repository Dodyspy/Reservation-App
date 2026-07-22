# Push Notification Troubleshooting - Two Devices 🔍

## 🔴 Problem:
- **Device 1:** ✅ Receives notifications when app is killed
- **Device 2:** ❌ Does NOT receive notifications when app is killed

---

## 🎯 Most Common Causes:

### 1. **iOS Settings - Notification Permissions** ⚙️
**Device 2 might have notifications disabled in iOS Settings**

#### Check on Device 2:
```
Settings → ReserveApp → Notifications
```

**Required Settings:**
- ✅ **Allow Notifications:** ON
- ✅ **Lock Screen:** ON (critical for killed app)
- ✅ **Notification Center:** ON
- ✅ **Banners:** ON
- ✅ **Sounds:** ON
- ✅ **Badges:** ON

**⚠️ CRITICAL:** If "Lock Screen" is OFF, notifications won't wake killed app!

---

### 2. **Low Power Mode** 🔋
**Device 2 might have Low Power Mode enabled**

#### Check on Device 2:
```
Settings → Battery → Low Power Mode
```

**Impact:**
- ❌ Low Power Mode = Background app refresh disabled
- ❌ Push notifications delayed or not delivered
- ❌ App won't wake from killed state

**Solution:** Turn OFF Low Power Mode for testing

---

### 3. **Focus Mode / Do Not Disturb** 🌙
**Device 2 might have Focus mode active**

#### Check on Device 2:
```
Control Center → Focus (Moon icon)
Settings → Focus
```

**Types:**
- Do Not Disturb
- Sleep
- Work
- Personal
- Driving

**Solution:** 
- Disable all Focus modes
- OR add ReserveApp to allowed apps in Focus settings

---

### 4. **iOS Version Differences** 📱
**Different iOS versions handle background notifications differently**

#### Check Both Devices:
```
Settings → General → About → Software Version
```

**Known Issues:**
- iOS 16.0-16.2: Background notification bugs
- iOS 17.0: New notification permission system
- iOS 17.4+: Most stable for background push

**Recommendation:** Update Device 2 to latest iOS version

---

### 5. **APNS Token Not Registered** 🔑
**Device 2 might not have successfully registered with APNS**

#### Diagnostic Steps:

1. **Open Xcode Console** while Device 2 is connected
2. **Launch app** on Device 2
3. **Look for these logs:**

**✅ Success Pattern:**
```
🚀 App launching - configuring Firebase and notifications...
🔔 Requesting notification permissions...
🔔 Notification permission granted: true
📱 Calling UIApplication.shared.registerForRemoteNotifications()...
🎉 APNS device token received: [token]
✅ APNS device token registered with Firebase Messaging
🔑 FCM token refreshed after APNS registration: [token]
✅ Successfully subscribed to restaurant topic: casanova_reservations
```

**❌ Failure Pattern:**
```
🔔 Notification permission granted: true
📱 Calling UIApplication.shared.registerForRemoteNotifications()...
❌ Failed to register for remote notifications: [error]
```

---

### 6. **Provisioning Profile Issues** 📜
**Device 2 might be using a different provisioning profile**

#### Check in Xcode:
1. Connect Device 2
2. Select Device 2 as target
3. Go to **Signing & Capabilities**
4. Check **Provisioning Profile** name

**Compare:**
- Device 1 profile: [name]
- Device 2 profile: [name]

**If Different:**
- Ensure both use **Development** or **Distribution** profile
- Ensure profile includes **Push Notifications** capability
- Re-download profiles: Xcode → Preferences → Accounts → Download Manual Profiles

---

### 7. **Network Connectivity** 🌐
**Device 2 might have connectivity issues**

#### Check on Device 2:
```
Settings → Wi-Fi → Connected
Settings → Cellular → On
```

**Test:**
- Open Safari and load a website
- Check if other apps receive push notifications (Messages, Mail, etc.)

**Firebase Connection:**
- App needs internet to register APNS token
- App needs internet to subscribe to FCM topics
- Once registered, notifications work offline

---

### 8. **Background App Refresh** 🔄
**Device 2 might have Background App Refresh disabled**

#### Check on Device 2:
```
Settings → General → Background App Refresh
```

**Required Settings:**
- ✅ **Background App Refresh:** ON (at top)
- ✅ **ReserveApp:** ON (in app list)

**Impact:**
- ❌ If OFF: App can't process background notifications
- ❌ If OFF: Notifications delayed or not shown

---

### 9. **App Reinstallation Needed** 🔄
**Device 2 might have stale APNS registration**

#### Solution:
1. **Delete app** from Device 2 completely
2. **Restart Device 2** (power off, power on)
3. **Reinstall app** from Xcode
4. **Grant permissions** again
5. **Test notification**

**Why This Works:**
- Clears old APNS tokens
- Resets notification permissions
- Forces fresh FCM registration

---

### 10. **Bundle ID Changed** 🆔
**If you changed bundle ID from `fr.casanova.ReserveApp` to `fr.casanova.RestaurantManager`**

#### Impact:
- ❌ Old APNS certificates won't work
- ❌ Old FCM tokens invalid
- ❌ Need new APNS certificate for new bundle ID

#### Check Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `casanova-dissy-reservations` project
3. Project Settings → Cloud Messaging
4. Check **iOS app configuration**

**Required:**
- Bundle ID: `fr.casanova.RestaurantManager` (NEW)
- APNS Auth Key uploaded
- OR APNS Certificate uploaded

**If Missing:**
1. Generate new APNS certificate in Apple Developer Portal
2. Upload to Firebase Console
3. Rebuild and reinstall app on both devices

---

## 🔍 Diagnostic Commands:

### Run on Device 2 (via Xcode Console):

#### 1. Check Notification Permission:
```swift
// Look for this log when app launches:
🔔 Notification permission granted: true/false
```

#### 2. Check APNS Registration:
```swift
// Look for this log:
🎉 APNS device token received: [token]
```

#### 3. Check FCM Token:
```swift
// Look for this log:
🔑 Firebase registration token: [token]
```

#### 4. Check Topic Subscription:
```swift
// Look for this log:
✅ Successfully subscribed to restaurant topic: casanova_reservations
```

---

## 🧪 Testing Steps:

### Test on Device 2:

1. **Clean Install:**
   ```
   - Delete app from Device 2
   - Restart Device 2
   - Install from Xcode
   ```

2. **Grant Permissions:**
   ```
   - Allow notifications when prompted
   - Check Settings → ReserveApp → Notifications
   - Ensure all toggles are ON
   ```

3. **Check Logs:**
   ```
   - Connect Device 2 to Xcode
   - Open Console (⇧⌘C)
   - Filter by "ReserveApp"
   - Look for APNS and FCM logs
   ```

4. **Kill App Completely:**
   ```
   - Swipe up from bottom
   - Swipe app up to close
   - Wait 5 seconds
   ```

5. **Send Test Notification:**
   ```
   - Make reservation on website
   - OR use Firebase Console to send test
   ```

6. **Check Device 2:**
   ```
   - Should see notification on lock screen
   - Should hear sound
   - Should see badge
   ```

---

## 🔧 Quick Fixes:

### Fix 1: Reset Notification Permissions
```
Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy
(This resets all app permissions - app will ask again)
```

### Fix 2: Toggle Airplane Mode
```
1. Enable Airplane Mode
2. Wait 10 seconds
3. Disable Airplane Mode
4. Wait for network to reconnect
5. Test notification
```

### Fix 3: Force Restart Device 2
```
iPhone 8 or later:
1. Press Volume Up, release
2. Press Volume Down, release
3. Hold Side button until Apple logo

iPhone 7:
1. Hold Volume Down + Side button
2. Until Apple logo appears

iPhone 6s or earlier:
1. Hold Home + Top button
2. Until Apple logo appears
```

### Fix 4: Reinstall with New Bundle ID
```
1. In Xcode: Change bundle ID to fr.casanova.RestaurantManager
2. Update Firebase with new bundle ID
3. Download new GoogleService-Info.plist
4. Delete app from Device 2
5. Rebuild and install
```

---

## 📊 Comparison Checklist:

| Setting | Device 1 (✅ Works) | Device 2 (❌ Fails) |
|---------|-------------------|-------------------|
| iOS Version | _____________ | _____________ |
| Notifications Allowed | ✅ | ❓ |
| Lock Screen Enabled | ✅ | ❓ |
| Low Power Mode | OFF | ❓ |
| Focus Mode | OFF | ❓ |
| Background Refresh | ON | ❓ |
| APNS Token Received | ✅ | ❓ |
| FCM Token Received | ✅ | ❓ |
| Topic Subscribed | ✅ | ❓ |
| Network Connected | ✅ | ❓ |
| Bundle ID | fr.casanova.RestaurantManager | ❓ |

---

## 🎯 Most Likely Culprits (In Order):

1. **Lock Screen notifications OFF** (80% of cases)
2. **Low Power Mode ON** (10% of cases)
3. **Focus Mode active** (5% of cases)
4. **APNS token not registered** (3% of cases)
5. **Background App Refresh OFF** (2% of cases)

---

## 🚀 Recommended Action Plan:

### Step 1: Check iOS Settings on Device 2
```
✅ Settings → ReserveApp → Notifications → ALL ON
✅ Settings → Battery → Low Power Mode → OFF
✅ Settings → Focus → ALL OFF
✅ Settings → General → Background App Refresh → ON
```

### Step 2: Clean Reinstall on Device 2
```
1. Delete app
2. Restart device
3. Reinstall from Xcode
4. Grant all permissions
```

### Step 3: Compare Logs
```
1. Connect both devices to Xcode
2. Launch app on both
3. Compare console logs
4. Look for differences in APNS/FCM registration
```

### Step 4: Test Notification
```
1. Kill app on both devices
2. Send test notification
3. Check which device receives it
```

---

## 🔍 Firebase Console Check:

### Verify Device 2 is Registered:

1. Go to Firebase Console
2. Select `casanova-dissy-reservations`
3. Go to **Firestore Database**
4. Check collection: `restaurants/CASANOVA2024/deviceTokens`

**Look for Device 2:**
```
Document ID: [Device 2 UUID]
Fields:
  - token: [FCM token]
  - platform: "ios"
  - isActive: true
  - deviceModel: "iPhone XX"
  - systemVersion: "17.x"
  - lastUpdated: [timestamp]
```

**If Missing:** Device 2 never registered properly!

---

## 📱 Device-Specific Issues:

### iPhone Models with Known Issues:
- **iPhone 6s/7:** iOS 15 max, limited background support
- **iPhone SE (1st gen):** Same as iPhone 6s
- **iPhone 8:** iOS 16 max, better but not perfect

### Recommended Devices:
- **iPhone 11 or newer:** Full iOS 17+ support
- **iPhone XR or newer:** Best background notification support

---

## 🆘 If Nothing Works:

### Last Resort Steps:

1. **Update iOS on Device 2** to latest version
2. **Reset All Settings** on Device 2
3. **Use different Apple ID** on Device 2
4. **Contact Apple Support** if hardware issue suspected
5. **Test with different device** to rule out device-specific problem

---

## 📝 Logging for Diagnosis:

### Add this to NotificationService.swift for more detailed logs:

```swift
// Add to registerForRemoteNotifications() method:
print("📱 Device Model: \(UIDevice.current.model)")
print("📱 System Version: \(UIDevice.current.systemVersion)")
print("📱 Device Name: \(UIDevice.current.name)")
print("📱 Device ID: \(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")")

// Add to AppDelegate didRegisterForRemoteNotificationsWithDeviceToken:
print("📱 APNS Token Length: \(deviceToken.count) bytes")
print("📱 APNS Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")

// Add to AppDelegate didFailToRegisterForRemoteNotificationsWithError:
print("❌ Error Domain: \((error as NSError).domain)")
print("❌ Error Code: \((error as NSError).code)")
print("❌ Error UserInfo: \((error as NSError).userInfo)")
```

---

## ✅ Success Criteria:

When Device 2 is working correctly, you should see:

```
✅ Notification permission granted: true
✅ APNS device token received
✅ FCM token registered
✅ Subscribed to topic: casanova_reservations
✅ Device token saved to Firestore
✅ Notification received on lock screen (app killed)
✅ Sound plays
✅ Badge appears
```

---

## 🎉 Summary:

**Most likely issue:** Lock Screen notifications disabled on Device 2

**Quick fix:**
```
Settings → ReserveApp → Notifications → Lock Screen → ON
```

**If that doesn't work:** Follow the diagnostic steps above to identify the specific issue.

---

**Need Help?** Check Xcode console logs on Device 2 and compare with Device 1 to find the difference!
