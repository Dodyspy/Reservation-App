# Fix for errSecInternalComponent Code Signing Error

## The Problem
Firebase's pre-compiled gRPC frameworks (`openssl_grpc.framework`, `grpcpp.framework`) fail to sign with `errSecInternalComponent` error when building for physical iOS devices.

## ✅ App Works Fine
The app **builds successfully for iOS Simulator** - the code is correct, it's purely a signing issue.

## Solution: Fix Keychain Access

### Option 1: Keychain Access GUI (RECOMMENDED)
1. Open **Keychain Access** app (Spotlight → "Keychain Access")
2. In the left sidebar, select **login** keychain
3. In the search box, type: `Apple Development: Stanciu Dragos`
4. Find your certificate and **double-click** it
5. Expand the **Trust** section
6. Set **Code Signing** to: **Always Trust**
7. Close the window (enter your password when prompted)
8. **Restart Xcode completely** (⌘Q)
9. Clean build folder and try again

### Option 2: Command Line Fix
Run this command to allow codesign tool access:

```bash
security set-key-partition-list -S apple-tool:,apple: -s -k <YOUR_KEYCHAIN_PASSWORD> ~/Library/Keychains/login.keychain-db
```

Replace `<YOUR_KEYCHAIN_PASSWORD>` with your Mac login password.

### Option 3: Re-download Certificate
1. Go to https://developer.apple.com
2. Account → Certificates, Identifiers & Profiles
3. **Revoke** the current "Apple Development: Stanciu Dragos" certificate
4. Create a **new** development certificate
5. Download and install it
6. In Xcode: Preferences → Accounts → Download Manual Profiles
7. Clean and rebuild

## After Fixing
1. Close Xcode (⌘Q)
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/ReserveApp-*`
3. Open Xcode
4. File → Packages → Reset Package Caches
5. Product → Clean Build Folder (⇧⌘K)
6. Build for your device (⌘B)

## Test on Simulator (Works Now)
If you want to test the app immediately:
1. In Xcode, select **any iPhone Simulator** as the destination
2. Product → Run (⌘R)
3. The app will launch in the simulator without signing issues

## Why This Happens
Firebase uses pre-compiled binary frameworks that require special keychain permissions. The `errSecInternalComponent` error means macOS Security is blocking the codesign tool from accessing your certificate's private key.
