# Clear Duplicate Topic Subscription

## Problem

You're still receiving 2 notifications because your device is likely subscribed to the `casanova-reservations` topic **twice** from previous app sessions.

## Solution

### Option 1: Rebuild and Reinstall App (Recommended)

This will force a clean subscription:

1. **Delete the app** from your device
2. **Clean build folder** in Xcode (Cmd+Shift+K)
3. **Rebuild** the app (Cmd+B)
4. **Install** on device
5. **Enter restaurant code** again
6. **Test** with new reservation

The new code will:
- Unsubscribe from topic first
- Then subscribe fresh
- Ensures only ONE subscription

### Option 2: Manual Unsubscribe via Settings

If you don't want to reinstall:

1. **Rebuild the app** (Cmd+B)
2. **Install** on device
3. **Open the app**
4. **Go to Settings** (if you have a settings screen)
5. **Disconnect from restaurant**
6. **Reconnect with restaurant code**

This will trigger the unsubscribe/resubscribe logic.

### Option 3: Wait for Topic Cleanup

Firebase automatically cleans up duplicate subscriptions after 24-48 hours, but this is too slow.

## What Changed in Code

### Before:
```swift
func subscribeToRestaurantTopic() {
    let topic = restaurant.fcmTopic
    
    // Only checks if currentTopic matches
    if currentTopic == topic {
        return  // But currentTopic might be nil after app restart!
    }
    
    // Subscribe (might create duplicate)
    Messaging.messaging().subscribe(toTopic: topic)
}
```

**Problem:** `currentTopic` is not persisted, so after app restart it's `nil`, allowing duplicate subscriptions.

### After:
```swift
func subscribeToRestaurantTopic() {
    let topic = restaurant.fcmTopic
    
    if currentTopic == topic {
        return
    }
    
    // ✅ ALWAYS unsubscribe first to clear duplicates
    Messaging.messaging().unsubscribe(fromTopic: topic) { error in
        // Then subscribe fresh
        Messaging.messaging().subscribe(toTopic: topic)
    }
}
```

**Fix:** Always unsubscribe before subscribing, ensuring clean state.

## Testing

After reinstalling/rebuilding:

1. **Check logs** for:
   ```
   🔄 Unsubscribing from topic 'casanova-reservations' to clear any duplicates...
   ✅ Unsubscribed from topic: casanova-reservations
   🔄 Subscribing to topic 'casanova-reservations'...
   ✅ Successfully subscribed to restaurant topic: casanova-reservations
   ```

2. **Make test reservation**

3. **Check device**:
   - Should receive **1 notification** ✅
   - Not 2 notifications ❌

## Why This Happens

### Firebase Topic Subscription Behavior:

Firebase allows the **same device** to subscribe to the **same topic multiple times**:

```
Device subscribes to "casanova-reservations"  → Subscription #1
App restarts
Device subscribes to "casanova-reservations"  → Subscription #2
```

**Result:** Device receives notification **twice** (once per subscription)!

### Why Previous Fix Didn't Work:

The guard check `if currentTopic == topic` only works **within the same app session**:

- App starts: `currentTopic = nil`
- Subscribe: `currentTopic = "casanova-reservations"`
- App restarts: `currentTopic = nil` (not persisted!)
- Subscribe again: Creates duplicate!

### Why New Fix Works:

**Always unsubscribe first:**
- Removes ALL existing subscriptions to the topic
- Then creates ONE fresh subscription
- No duplicates possible!

## Important Notes

### Must Rebuild App!

The code changed, so you MUST:
1. Clean build (Cmd+Shift+K)
2. Rebuild (Cmd+B)
3. Install on device

### Best Approach: Delete & Reinstall

For cleanest state:
1. Delete app from device
2. Rebuild in Xcode
3. Install fresh
4. Enter restaurant code
5. Test

This ensures:
- No old subscriptions
- No cached state
- Clean Firebase connection
- ONE subscription only

## Verification

### Check Logs:

You should see this sequence:
```
🔄 Unsubscribing from topic 'casanova-reservations' to clear any duplicates...
✅ Unsubscribed from topic: casanova-reservations
🔄 Subscribing to topic 'casanova-reservations'...
✅ Successfully subscribed to restaurant topic: casanova-reservations
```

### Check Notifications:

Make 3 test reservations in a row:
- Should receive **3 notifications** (one per reservation) ✅
- Should NOT receive **6 notifications** (two per reservation) ❌

## Summary

**Problem:** Device subscribed to topic multiple times
**Cause:** `currentTopic` not persisted across app restarts
**Solution:** Always unsubscribe before subscribing
**Action:** Delete app, rebuild, reinstall, test

This should finally fix the duplicate notifications! 🎉
