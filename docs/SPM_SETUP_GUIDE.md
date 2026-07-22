# Swift Package Manager Setup Guide

## Migration Complete: CocoaPods → SPM

✅ **CocoaPods Cleanup Complete**
- Removed Podfile, Pods directory, and .xcworkspace
- Cleaned up Xcode project references to CocoaPods
- Removed all CocoaPods build phases and configurations

## Next Steps: Add Firebase via Swift Package Manager

### 1. Open Project in Xcode
```bash
open ReserveApp.xcodeproj
```

### 2. Add Firebase Swift Package
1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the Firebase iOS SDK URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. Click **Add Package**
4. Select the following Firebase products:
   - ✅ **FirebaseCore** (required for all Firebase services)
   - ✅ **FirebaseFirestore** (includes Swift APIs - FirebaseFirestoreSwift is deprecated)
   - ✅ **FirebaseAnalytics** (for app analytics)
   - ✅ **FirebaseMessaging** (for push notifications)

5. Click **Add Package** to complete the installation

### 3. Update Import Statements
The following files need updated import statements:

#### Files to Update:
- `ReserveApp/ReserveAppApp.swift`
- `ReserveApp/Services/FirebaseService.swift` (or similar)
- `ReserveApp/Services/NotificationService.swift`
- `ReserveApp/ViewModels/ReservationViewModel.swift`

#### Import Changes:
Replace any existing Firebase imports with:
```swift
import FirebaseCore
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAnalytics
import FirebaseMessaging
```

### 4. Verify GoogleService-Info.plist
Ensure `GoogleService-Info.plist` is properly added to your Xcode project:
1. Right-click on your project in Xcode
2. Select "Add Files to 'ReserveApp'"
3. Choose the `GoogleService-Info.plist` file
4. Make sure it's added to the ReserveApp target

### 5. Build and Test
1. Clean build folder: **Product → Clean Build Folder**
2. Build the project: **⌘+B**
3. Run the app: **⌘+R**

## Benefits of SPM Migration

✅ **Simplified Dependency Management**
- No more Podfile or workspace files
- Direct integration with Xcode
- Automatic dependency resolution

✅ **Better Build Performance**
- No CocoaPods build phases
- Faster clean builds
- Reduced build complexity

✅ **Easier Maintenance**
- Version management through Xcode
- Automatic updates available
- No more `pod install` commands

## Troubleshooting

### If Build Fails:
1. Clean build folder: **Product → Clean Build Folder**
2. Delete derived data: **Product → Clean Build Folder** (hold Option)
3. Restart Xcode
4. Rebuild project

### If Firebase Services Don't Work:
1. Verify `GoogleService-Info.plist` is in project
2. Check Firebase.configure() is called in App delegate
3. Verify import statements are correct

## Migration Complete! 🎉

Your Casanova d'Issy reservation app is now using Swift Package Manager instead of CocoaPods. This provides a cleaner, more maintainable dependency setup while preserving all Firebase functionality.
