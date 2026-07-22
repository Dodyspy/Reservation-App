# TestFlight Notification Issue - CRITICAL FIX 🚨

## 🔴 The Problem:

**Device 1 (Xcode install):** ✅ Works - Uses **Development APNS**  
**Device 2 (TestFlight install):** ❌ Fails - Uses **Production APNS**

---

## 🎯 Root Cause:

### APNS has TWO environments:

1. **Development APNS** 
   - Used by Xcode debug builds
   - Uses Development provisioning profile
   - Uses Development APNS certificate

2. **Production APNS**
   - Used by TestFlight builds
   - Used by App Store builds
   - Uses Production APNS certificate
   - **REQUIRES Production APNS certificate in Firebase!**

---

## ⚠️ Why TestFlight Doesn't Work:

Your Firebase project likely only has the **Development APNS certificate** uploaded.

**TestFlight needs Production APNS certificate!**

---

## ✅ Solution: Upload Production APNS Certificate to Firebase

### Option A: Using APNS Auth Key (Recommended - Works for Both)

#### Step 1: Create APNS Auth Key in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles**
3. **Keys** (left sidebar)
4. Click **+** (Create a new key)
5. **Key Name:** "Casanova APNS Key"
6. **Enable:** Apple Push Notifications service (APNs)
7. Click **Continue**
8. Click **Register**
9. **Download the .p8 file** (you can only download once!)
10. **Note the Key ID** (e.g., ABC123DEF4)
11. **Note your Team ID** (top right, e.g., HV9UP5L8B3)

#### Step 2: Upload to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **casanova-dissy-reservations** project
3. **Project Settings** (gear icon)
4. **Cloud Messaging** tab
5. Scroll to **Apple app configuration**
6. Find your iOS app: `fr.casanova.RestaurantManager`
7. Under **APNs authentication key**:
   - Click **Upload**
   - Select the .p8 file you downloaded
   - Enter **Key ID** (from Step 1.10)
   - Enter **Team ID** (HV9UP5L8B3)
8. Click **Upload**

**✅ This works for BOTH Development AND Production!**

---

### Option B: Using APNS Certificates (Legacy - Need Both Dev & Prod)

#### Step 1: Create Production APNS Certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles**
3. **Identifiers** → Select your App ID: `fr.casanova.RestaurantManager`
4. Scroll to **Push Notifications**
5. Under **Production SSL Certificate**:
   - Click **Create Certificate**
   - Follow instructions to create CSR (Certificate Signing Request)
   - Upload CSR
   - Download the certificate (.cer file)

#### Step 2: Convert to .p12 Format

1. **Double-click** the .cer file to add to Keychain
2. Open **Keychain Access** app
3. Find the certificate: "Apple Push Services: fr.casanova.RestaurantManager"
4. **Right-click** → Export
5. Save as: **casanova_production_apns.p12**
6. Set a password (remember it!)

#### Step 3: Upload to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **casanova-dissy-reservations** project
3. **Project Settings** → **Cloud Messaging**
4. Find your iOS app
5. Under **APNs certificates**:
   - **Production:** Upload casanova_production_apns.p12
   - Enter the password you set
   - Click **Upload**

---

## 🔍 Check Current Firebase Configuration:

### In Firebase Console:

1. Go to **Project Settings** → **Cloud Messaging**
2. Check your iOS app configuration

**You should see ONE of:**

### ✅ Option A: APNS Auth Key (Best)
```
APNs authentication key
Key ID: ABC123DEF4
Team ID: HV9UP5L8B3
Status: Active
```

### ✅ Option B: APNS Certificates
```
APNs certificates
Development: ✅ Uploaded (expires: 2026-XX-XX)
Production: ✅ Uploaded (expires: 2026-XX-XX)
```

### ❌ Current (Likely):
```
APNs certificates
Development: ✅ Uploaded
Production: ❌ NOT UPLOADED ← THIS IS THE PROBLEM!
```

---

## 🧪 Testing After Fix:

### Test on TestFlight Device:

1. **Upload new build to TestFlight** (if you made changes)
2. **Wait 5-10 minutes** for Firebase to propagate changes
3. **Delete app** from TestFlight device
4. **Reinstall** from TestFlight
5. **Grant notification permissions**
6. **Kill the app** completely
7. **Send test notification** from website
8. **Check device** - should receive notification!

---

## 📱 Alternative: Install from Xcode on Both Devices

If you can't upload Production APNS certificate yet:

### Quick Workaround:

1. **Connect TestFlight device** to Mac via cable
2. **Open Xcode**
3. **Select the device** as target
4. **Build & Run** (⌘R)
5. **This installs Development build** (will work with Development APNS)

**Note:** This is temporary - for production/TestFlight, you NEED Production APNS!

---

## 🔧 Verify APNS Environment:

### Check Build Configuration:

1. In Xcode, select **ReserveApp** project
2. Select **ReserveApp** target
3. **Build Settings** tab
4. Search for: **"aps-environment"**

**You should see:**
- **Debug:** development
- **Release:** production ← TestFlight uses this!

---

## 📋 Checklist for TestFlight Notifications:

- [ ] Production APNS certificate uploaded to Firebase
  - [ ] OR APNS Auth Key uploaded (works for both)
- [ ] Bundle ID matches: `fr.casanova.RestaurantManager`
- [ ] GoogleService-Info.plist is correct
- [ ] Push Notifications capability enabled in Xcode
- [ ] TestFlight build uses Release configuration
- [ ] Device has notification permissions enabled
- [ ] Device has Lock Screen notifications enabled
- [ ] Low Power Mode is OFF
- [ ] Focus Mode is OFF

---

## 🎯 Recommended Solution:

**Use APNS Auth Key (Option A)** because:

✅ Works for Development AND Production  
✅ Never expires (certificates expire yearly)  
✅ Easier to manage  
✅ One upload instead of two  
✅ More secure  

---

## 🚀 Step-by-Step Fix (APNS Auth Key):

### 1. Create APNS Auth Key (5 minutes)
```
Apple Developer Portal → Keys → Create Key
- Name: Casanova APNS
- Enable: APNs
- Download .p8 file
- Note Key ID and Team ID
```

### 2. Upload to Firebase (2 minutes)
```
Firebase Console → Project Settings → Cloud Messaging
- Upload .p8 file
- Enter Key ID
- Enter Team ID: HV9UP5L8B3
```

### 3. Wait for Propagation (5-10 minutes)
```
Firebase needs time to update APNS configuration
```

### 4. Test on TestFlight Device
```
- Delete app
- Reinstall from TestFlight
- Grant permissions
- Kill app
- Send test notification
- ✅ Should work!
```

---

## ⚠️ Important Notes:

### APNS Auth Key:
- **Can only download ONCE** - save it securely!
- **Works forever** - doesn't expire
- **Max 2 keys** per Apple Developer account
- **Revoke old keys** if you create new ones

### APNS Certificates:
- **Expire after 1 year** - need to renew
- **Need separate Dev & Prod** certificates
- **More work** to maintain

---

## 🔍 Debugging TestFlight Notifications:

### Without Xcode Console, Check:

1. **iOS Settings:**
   ```
   Settings → ReserveApp → Notifications
   - All toggles ON
   - Lock Screen: ON ← Critical!
   ```

2. **Firebase Console:**
   ```
   Firestore → restaurants/CASANOVA2024/deviceTokens
   - Check if TestFlight device is registered
   - Look for device with TestFlight build version
   ```

3. **Send Test from Firebase:**
   ```
   Firebase Console → Cloud Messaging → Send test message
   - Enter FCM token from Firestore
   - Send notification
   - Check if device receives it
   ```

4. **Check App Badge:**
   ```
   If app icon shows badge number, Firebase is working
   But notifications might be blocked by iOS settings
   ```

---

## 📊 Comparison:

| Feature | Development APNS | Production APNS |
|---------|-----------------|-----------------|
| **Xcode Builds** | ✅ Works | ❌ Doesn't work |
| **TestFlight** | ❌ Doesn't work | ✅ Works |
| **App Store** | ❌ Doesn't work | ✅ Works |
| **Certificate Type** | Development | Production |
| **Firebase Upload** | Optional | **REQUIRED** |

---

## 🎉 After Fix:

Once Production APNS is configured:

✅ Xcode builds work (Development APNS)  
✅ TestFlight builds work (Production APNS)  
✅ App Store builds work (Production APNS)  
✅ All devices receive notifications when app is killed  

---

## 🆘 If Still Not Working After Upload:

1. **Wait 10-15 minutes** - Firebase needs time to propagate
2. **Delete & reinstall** app from TestFlight
3. **Restart device** - clears APNS cache
4. **Check Firebase logs** - Cloud Messaging → Reports
5. **Try sending from Firebase Console** directly
6. **Verify Key ID and Team ID** are correct

---

## 📞 Quick Reference:

**Your Details:**
- Bundle ID: `fr.casanova.RestaurantManager`
- Team ID: `HV9UP5L8B3`
- Firebase Project: `casanova-dissy-reservations`

**What You Need:**
- APNS Auth Key (.p8 file) from Apple Developer Portal
- OR Production APNS Certificate (.p12 file)

**Where to Upload:**
- Firebase Console → Project Settings → Cloud Messaging

---

## ✅ Success Criteria:

After uploading Production APNS, TestFlight device should:

```
✅ Register for notifications
✅ Receive FCM token
✅ Subscribe to topic: casanova_reservations
✅ Receive notifications when app is killed
✅ Show notifications on lock screen
✅ Play sound
✅ Show badge
```

---

**Bottom Line:** TestFlight requires Production APNS certificate/key in Firebase. Upload it and notifications will work! 🚀
