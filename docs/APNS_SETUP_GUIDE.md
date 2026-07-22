# 🔔 APNS Setup Guide for Push Notifications

## Current Status
✅ **Code Implementation**: All push notification code is implemented and ready
✅ **Entitlements File**: ReserveApp.entitlements is created with `aps-environment: development`
✅ **Firebase Configuration**: Firebase Messaging is properly configured
❌ **Xcode Project Setup**: APNS capability needs to be enabled in Xcode

## 🎯 What You Need to Do in Xcode

### Step 1: Enable Push Notifications Capability
1. **Open ReserveApp.xcodeproj in Xcode**
2. **Select the ReserveApp target** (main app target)
3. **Go to "Signing & Capabilities" tab**
4. **Click the "+ Capability" button**
5. **Search for and add "Push Notifications"**
6. **Verify the capability appears in the list**

### Step 2: Link the Entitlements File
1. **Still in "Signing & Capabilities" tab**
2. **Look for "Code Signing Entitlements" field**
3. **Set it to**: `ReserveApp/ReserveApp.entitlements`
4. **Verify the file path is correct**

### Step 3: Apple Developer Portal Setup
1. **Go to**: https://developer.apple.com/account/
2. **Navigate to**: Certificates, Identifiers & Profiles
3. **Select your App ID** (com.casanovadissy.ReserveApp or similar)
4. **Edit the App ID**
5. **Enable "Push Notifications" service**
6. **Save the changes**

### Step 4: Provisioning Profile Update
1. **In Apple Developer Portal**
2. **Go to Provisioning Profiles**
3. **Find your development profile for this app**
4. **Edit and regenerate the profile** (to include push notifications)
5. **Download the new profile**
6. **In Xcode**: Go to Preferences → Accounts → Download Manual Profiles

### Step 5: Test Push Notifications
1. **Build and run the app on a REAL DEVICE** (push notifications don't work in simulator)
2. **Accept notification permissions when prompted**
3. **Check the Xcode console for**:
   - ✅ "APNS device token registered successfully"
   - ✅ "Successfully subscribed to topic: reservations"
4. **Make a test reservation on the website**
5. **Kill the iOS app completely**
6. **You should receive a push notification even when the app is killed**

## 🐛 Troubleshooting

### If APNS Token Registration Fails:
- **Check**: Push Notifications capability is enabled in Xcode
- **Check**: Entitlements file is properly linked
- **Check**: App ID has Push Notifications enabled in Developer Portal
- **Check**: Provisioning profile includes push notifications
- **Check**: Running on real device (not simulator)

### If No Push Notifications Received:
- **Check**: Notification permissions are granted
- **Check**: Firebase project has APNS certificates configured
- **Check**: Website push notification API is working (check browser console)
- **Check**: Device is subscribed to "reservations" topic

## 🔧 Current Implementation Details

### Push Notification Flow:
1. **Website**: New reservation → calls `/api/send-push-notification`
2. **Server**: Sends push notification via Firebase Admin SDK
3. **iOS App**: Receives push notification even when killed
4. **User**: Taps notification → app opens to reservations list

### Notification Content:
- **Title**: "Nouvelle réservation"
- **Body**: "[Customer Name] - [Party Size] personnes - [Date] à [Time]"
- **Badge**: Shows count of unread notifications
- **Sound**: Default notification sound

## ✅ Expected Results After Setup

Once properly configured, you should see:
- 🔔 **Push notifications work when app is killed**
- 📱 **Notification bell menu shows list of new reservations**
- 🔴 **Badge count on notification bell**
- 📋 **Tap notification to view reservation details**
- ✨ **Mark individual notifications as read**
- 🧹 **"Mark all as read" functionality**

## 🚀 Ready to Test!

After completing the Xcode setup:
1. **Build and run on real device**
2. **Accept notification permissions**
3. **Make a test reservation on website**
4. **Kill the app completely**
5. **Verify push notification arrives**
6. **Tap notification bell to see notifications menu**

The code is ready - you just need to complete the Xcode/Apple Developer setup! 🎉
