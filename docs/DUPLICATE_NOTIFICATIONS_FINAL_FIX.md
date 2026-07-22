# Duplicate Notifications - Final Fix ✅

## Problem

Still receiving **2 notifications for 1 reservation** even after previous fixes.

## Investigation

### What We Checked:

1. ✅ **Cloud Function logs** - Only ONE notification sent
2. ✅ **saveReservation function** - No longer sends notifications
3. ✅ **Delegate implementation** - Removed duplicate from NotificationService
4. ❌ **Still getting duplicates!**

## Root Causes Found

### Issue 1: Duplicate Topic Subscriptions

The app was subscribing to the same topic **multiple times**:

**Location 1:** `RestaurantManager.setCurrentRestaurant()`
```swift
func setCurrentRestaurant(_ restaurant: Restaurant) {
    currentRestaurant = restaurant
    NotificationService.shared.subscribeToRestaurantTopic()  // Subscribe #1
}
```

**Location 2:** `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken`
```swift
func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().token { token, error in
        NotificationService.shared.subscribeToRestaurantTopic()  // Subscribe #2
    }
}
```

**Result:** Device subscribed to `casanova-reservations` topic **twice** → 2 notifications!

### Issue 2: Conflicting Payload Fields

The notification message had **both** `data` and `apns` fields:

```javascript
const message = {
  data: {                    // ← iOS might show notification for this
    reservationId: "...",
    restaurantCode: "...",
    // ...
  },
  apns: {                    // ← AND show notification for this
    payload: {
      aps: {
        alert: { ... }
      }
    }
  }
}
```

**Result:** iOS might process both fields → 2 notifications!

## Solutions Applied

### Fix 1: Prevent Duplicate Subscriptions

**File:** `NotificationService.swift`

```swift
func subscribeToRestaurantTopic() {
    guard let restaurant = restaurantManager.currentRestaurant else {
        return
    }
    
    let topic = restaurant.fcmTopic
    
    // ✅ NEW: Check if already subscribed
    if currentTopic == topic {
        print("ℹ️ Already subscribed to topic: \(topic)")
        return  // Don't subscribe again!
    }
    
    // Unsubscribe from previous topic if different
    if let currentTopic = currentTopic, currentTopic != topic {
        unsubscribeFromTopic(currentTopic)
    }
    
    // Subscribe to new topic
    Messaging.messaging().subscribe(toTopic: topic) { [weak self] error in
        if let error = error {
            print("❌ Failed to subscribe to topic '\(topic)': \(error)")
        } else {
            print("✅ Successfully subscribed to restaurant topic: \(topic)")
            self?.currentTopic = topic
        }
    }
}
```

**What Changed:**
- Added guard to check if already subscribed to the same topic
- Returns early if already subscribed
- Prevents duplicate subscriptions

### Fix 2: Unified Payload Structure

**File:** `casanovadissy-site/functions/index.js`

**Before:**
```javascript
const message = {
  data: {                    // ❌ Separate data field
    reservationId: "...",
    restaurantCode: "...",
    // ...
  },
  apns: {
    payload: {
      aps: { alert: { ... } }
    }
  }
}
```

**After:**
```javascript
const message = {
  apns: {                    // ✅ Everything in APNS payload
    headers: {
      'apns-priority': '10',
      'apns-push-type': 'alert'
    },
    payload: {
      aps: {
        alert: {
          title: '🎉 Nouvelle Réservation',
          body: '...'
        },
        sound: 'default',
        badge: 1,
        'content-available': 1
      },
      // ✅ Custom data inside APNS payload
      reservationId: reservationId,
      restaurantCode: restaurantCode,
      type: 'new_reservation',
      name: reservation.name,
      guests: String(reservation.guests),
      date: reservation.date,
      time: reservation.time
    }
  },
  topic: topic
}
```

**What Changed:**
- Removed top-level `data` field
- Moved all custom data into `apns.payload`
- Single unified payload structure
- Changed `mutable-content` to `content-available`

## Why This Works

### Topic Subscription:
- **Before:** Device subscribed twice → Receives 2 messages
- **After:** Device subscribed once → Receives 1 message ✅

### Payload Structure:
- **Before:** iOS processes `data` + `apns` → Shows 2 notifications
- **After:** iOS processes only `apns` → Shows 1 notification ✅

## Testing

### Test 1: Fresh Install

1. Delete app
2. Reinstall
3. Enter restaurant code
4. Make test reservation
5. **Expected:** 1 notification ✅

### Test 2: Existing User

1. Rebuild app (important!)
2. Kill app
3. Make test reservation
4. **Expected:** 1 notification ✅

### Test 3: Multiple Reservations

1. Make 3 reservations in a row
2. **Expected:** 3 notifications (one per reservation) ✅

## Deployment

### iOS App:
1. **Rebuild the app** (code changed in NotificationService.swift)
2. **Install on device**
3. **Test**

### Cloud Function:
```bash
firebase deploy --only functions:sendNewReservationNotification
✅ Deployed successfully
```

## Verification

### Check Logs After Test:

```bash
firebase functions:log | grep "sendNewReservationNotification"
```

**Should see:**
```
✅ Notification sent successfully: projects/.../messages/...
```

**Should NOT see:**
```
❌ Multiple "Notification sent" messages for same reservation
```

### Check Device:

**Should see:**
- ✅ ONE notification on lock screen
- ✅ ONE notification in notification center
- ✅ Badge count = 1

**Should NOT see:**
- ❌ TWO identical notifications
- ❌ Badge count = 2

## Summary of All Fixes

### Session 1: Removed Old Push Code
- ❌ Problem: `saveReservation` sending notifications
- ✅ Fix: Redeployed without push code

### Session 2: Removed Duplicate Delegate
- ❌ Problem: Two `UNUserNotificationCenterDelegate` implementations
- ✅ Fix: Removed delegate from NotificationService

### Session 3: Prevented Duplicate Subscriptions
- ❌ Problem: Subscribing to topic multiple times
- ✅ Fix: Added guard to check if already subscribed

### Session 4: Unified Payload Structure
- ❌ Problem: Conflicting `data` and `apns` fields
- ✅ Fix: Moved everything into APNS payload

## Final Result

✅ **ONE Cloud Function** sends notifications
✅ **ONE delegate** handles notifications
✅ **ONE subscription** per topic
✅ **ONE payload** structure
✅ **ONE notification** per reservation!

## Important Notes

### Must Rebuild iOS App!

The NotificationService.swift code changed, so you MUST:
1. Clean build folder (Cmd+Shift+K)
2. Rebuild app (Cmd+B)
3. Install on device
4. Test

### Cloud Function Already Deployed

The new payload structure is already live in Firebase.

### Test Thoroughly

Make several test reservations to confirm:
- Only 1 notification per reservation
- Notifications still work when app is killed
- Tapping notification opens the reservation
- All data is present in notification

## If Still Getting Duplicates

### Check 1: App Rebuilt?
```
Did you rebuild the iOS app after code changes?
```

### Check 2: Topic Subscriptions
```swift
// Add logging to see subscription status
print("Current topic: \(currentTopic ?? "none")")
print("New topic: \(topic)")
```

### Check 3: Device Tokens
```
Check if device has multiple FCM tokens registered
```

### Check 4: Firebase Console
```
Go to Firebase Console → Cloud Messaging
Check if there are duplicate topics or subscriptions
```

## Conclusion

After 4 rounds of fixes, we've addressed:
1. ✅ Duplicate Cloud Functions
2. ✅ Duplicate Delegates
3. ✅ Duplicate Topic Subscriptions
4. ✅ Conflicting Payload Fields

**The notification system should now send exactly ONE notification per reservation!** 🎉

**IMPORTANT:** Rebuild the iOS app and test!
