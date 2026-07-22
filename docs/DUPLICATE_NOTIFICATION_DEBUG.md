# Duplicate Notification Debugging - Enhanced Logging 🔍

## Current Situation

**Problem:** All 3 devices receive 2 notifications for 1 reservation

**What We Know:**
- ✅ Only ONE Cloud Function execution per reservation (verified in Firebase logs)
- ✅ Only ONE notification sent to topic (verified in Firebase logs)
- ✅ Local notifications removed from iOS app
- ✅ No duplicate delegates
- ✅ Clean topic subscription
- ❌ Still receiving 2 notifications per device

## Enhanced Logging Added

### 1. Foreground Notification Handler

**File:** `ReserveAppApp.swift` - `willPresent`

**Logs:**
```
📬 ========== FOREGROUND NOTIFICATION ==========
📬 Identifier: [unique ID]
📬 Title: [notification title]
📬 Body: [notification body]
📬 UserInfo: [all notification data]
📬 =============================================
```

**What This Tells Us:**
- If this logs **TWICE** for same reservation → App is receiving notification twice from iOS
- If this logs **ONCE** but user sees 2 notifications → iOS is showing notification twice
- The **Identifier** will tell us if they're the same notification or different

### 2. Remote Notification Handler

**File:** `ReserveAppApp.swift` - `didReceiveRemoteNotification`

**Logs:**
```
🔔 ========== REMOTE NOTIFICATION RECEIVED ==========
🔔 App State: [0=active, 1=inactive, 2=background]
🔔 UserInfo: [notification data]
🔔 ===================================================
```

**What This Tells Us:**
- If this logs **TWICE** → Firebase is sending notification twice
- If this logs **ONCE** → Notification is being duplicated by iOS or app

### 3. Firebase Cloud Function

**Already logging:**
```
Notification sent successfully: projects/.../messages/[ID]
```

**What This Tells Us:**
- If we see **TWO** message IDs → Function firing twice
- If we see **ONE** message ID → Function only fires once (correct)

## Testing Instructions

### Step 1: Clean Slate

1. **Kill all 3 apps** completely
2. **Clear all notifications** from notification center
3. **Rebuild and install** the app on all 3 devices

### Step 2: Make Test Reservation

1. Go to **www.casanovadissy.fr**
2. Make a test reservation with unique name (e.g., "DEBUG TEST 1")
3. **Immediately check logs** on all 3 devices

### Step 3: Collect Logs

**For each device, collect:**

#### Device Logs (Xcode Console):
```
Look for:
📬 ========== FOREGROUND NOTIFICATION ==========
🔔 ========== REMOTE NOTIFICATION RECEIVED ==========
```

**Count how many times each appears!**

#### Firebase Logs:
```bash
firebase functions:log | grep "DEBUG TEST 1"
```

**Count how many "Notification sent successfully" messages!**

### Step 4: Analyze Results

## Possible Scenarios

### Scenario A: Function Fires Twice

**Firebase Logs:**
```
✅ Notification sent successfully: .../messages/123
✅ Notification sent successfully: .../messages/456  ← TWO MESSAGES!
```

**Device Logs:**
```
🔔 REMOTE NOTIFICATION RECEIVED (appears twice)
```

**Root Cause:** Firestore trigger firing twice
**Solution:** Check if reservation is being saved twice

---

### Scenario B: iOS Receives Twice

**Firebase Logs:**
```
✅ Notification sent successfully: .../messages/123  ← ONE MESSAGE
```

**Device Logs:**
```
🔔 REMOTE NOTIFICATION RECEIVED (appears twice)
```

**Root Cause:** iOS receiving same notification twice
**Solution:** Check APNS configuration or notification payload

---

### Scenario C: App Processes Twice

**Firebase Logs:**
```
✅ Notification sent successfully: .../messages/123  ← ONE MESSAGE
```

**Device Logs:**
```
🔔 REMOTE NOTIFICATION RECEIVED (appears once)
📬 FOREGROUND NOTIFICATION (appears twice)
```

**Root Cause:** App's notification handler being called twice
**Solution:** Check for duplicate delegates or handlers

---

### Scenario D: iOS Shows Twice

**Firebase Logs:**
```
✅ Notification sent successfully: .../messages/123  ← ONE MESSAGE
```

**Device Logs:**
```
🔔 REMOTE NOTIFICATION RECEIVED (appears once)
📬 FOREGROUND NOTIFICATION (appears once)
```

**But user sees 2 notifications!**

**Root Cause:** iOS notification system showing notification twice
**Solution:** Check notification identifier or iOS notification settings

## What to Look For

### 1. Notification Identifiers

If you see:
```
📬 Identifier: FCM_MSG_1234567890
📬 Identifier: FCM_MSG_1234567890  ← SAME ID
```
**→ Same notification being processed twice**

If you see:
```
📬 Identifier: FCM_MSG_1234567890
📬 Identifier: FCM_MSG_0987654321  ← DIFFERENT ID
```
**→ Two different notifications being sent**

### 2. Notification Content

Check if the two notifications have:
- **Same title?** (both "🎉 Nouvelle Réservation")
- **Same body?** (same name, date, time)
- **Same userInfo?** (same reservationId)

If **identical** → Duplicate of same notification
If **different** → Two separate notifications

### 3. Timing

Check timestamps:
```
2025-11-28 19:19:47.015 - First notification
2025-11-28 19:19:47.016 - Second notification (1ms later)
```

If **milliseconds apart** → Same notification processed twice
If **seconds apart** → Two separate notifications

## Next Steps Based on Results

### If Function Fires Twice:
1. Check if website is calling `saveReservation` twice
2. Check for duplicate form submissions
3. Add idempotency check in Cloud Function

### If iOS Receives Twice:
1. Check APNS configuration in Firebase Console
2. Verify notification payload format
3. Check for duplicate FCM tokens

### If App Processes Twice:
1. Check for duplicate delegate implementations
2. Verify notification center delegate is set only once
3. Check for multiple notification observers

### If iOS Shows Twice:
1. Check notification identifier uniqueness
2. Verify notification request isn't added twice
3. Check iOS notification settings

## Debugging Commands

### Watch Firebase Logs in Real-Time:
```bash
cd /Users/sxy/AppTest/Casanovadissy/casanovadissy-site
firebase functions:log --only sendNewReservationNotification
```

### Check Recent Notifications:
```bash
firebase functions:log | grep "Notification sent" | tail -10
```

### Count Notifications for Specific Reservation:
```bash
firebase functions:log | grep "DEBUG TEST 1" | grep "Notification sent" | wc -l
```

## Expected Correct Behavior

### Firebase Logs:
```
New reservation created for CASANOVA2024: [ID]
Sending notification to topic: casanova-reservations
Notification sent successfully: .../messages/[ID]
Function execution took 1500 ms, finished with status: 'ok'
```
**Count: 1 execution, 1 notification sent**

### Device 1 Logs (App Killed):
```
🔔 REMOTE NOTIFICATION RECEIVED
🔔 App State: 2 (background)
```
**Count: 1 notification received**

### Device 2 Logs (App Backgrounded):
```
🔔 REMOTE NOTIFICATION RECEIVED
🔔 App State: 2 (background)
```
**Count: 1 notification received**

### Device 3 Logs (App in Foreground):
```
📬 FOREGROUND NOTIFICATION
📬 Identifier: FCM_MSG_[unique]
📬 Title: 🎉 Nouvelle Réservation
```
**Count: 1 notification received**

### User Experience:
- ✅ Each device shows **1 notification**
- ✅ All 3 devices receive notification (correct multi-device behavior)
- ✅ Notification appears on lock screen
- ✅ Tapping notification opens app to reservation

## Test Checklist

- [ ] Rebuild app with new logging
- [ ] Install on all 3 devices
- [ ] Kill all apps
- [ ] Clear all notifications
- [ ] Make test reservation
- [ ] Collect Firebase logs
- [ ] Collect device logs from all 3 devices
- [ ] Count notifications in Firebase logs
- [ ] Count notifications in device logs
- [ ] Count notifications user sees
- [ ] Check notification identifiers
- [ ] Check notification content
- [ ] Check timestamps
- [ ] Share logs for analysis

## Important Notes

1. **Multi-device is correct:** All 3 devices SHOULD receive the notification
2. **One per device is correct:** Each device should show only 1 notification
3. **Same notification is correct:** All devices should show the same notification content

**The problem is:** Each device is showing 2 notifications instead of 1

**We need to find:** Where the duplication happens in the flow from Firebase → iOS → User

---

**Rebuild the app and run the test. Share the logs and we'll identify exactly where the duplication occurs!** 🔍
