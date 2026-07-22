# Casanova d'Issy Reservation App

iOS reservation management app for Casanova d'Issy, built with SwiftUI and Firebase.

## Requirements

- iOS 16.0+
- Xcode 15.0+ (project uses `fileSystemSynchronizedGroups`)
- Swift Package Manager (no CocoaPods)

## Setup

### 1. Firebase configuration

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with bundle ID `fr.casanova.RestaurantManager`.
3. Download `GoogleService-Info.plist` and place it in `ReserveApp/`.
4. **Do not commit this file** — it is listed in `.gitignore`.

### 2. App secrets

1. Copy `ReserveApp/Config.plist.example` to `ReserveApp/Config.plist`.
2. Fill in the required keys:
   - `CloudFunctionBaseURL`
   - `EmailJSServiceID`
   - `EmailJSTemplateID`
   - `EmailJSUserID`
3. **Do not commit `Config.plist`.**

### 3. Build

Open `ReserveApp.xcodeproj` in Xcode. Swift Package Manager resolves Firebase automatically.

```bash
xcodebuild -resolvePackageDependencies
```

## Features

- Real-time reservation list via Firestore
- Status workflow: En attente → Confirmée → Arrivée → Terminée / No-show / Annulée
- **Edit reservation** (name, email, phone, date, time, guests, special requests) from the reservation detail screen
- Manual reservation creation
- Customer tracking and history
- Table and zone management
- Time-slot extra covers
- Restaurant availability controls (full, closed, capacity override)
- Push notifications via Firebase Cloud Messaging
- User management and audit log

## Architecture

MVVM with SwiftUI:

- `Models/` — data structures (`Reservation`, `Restaurant`, `Customer`, etc.)
- `Views/` — SwiftUI screens
- `ViewModels/` — state and business logic
- `Services/` — Firebase, API, auth, notifications
- `Utilities/` — theme, formatters, config

## Data model

Reservations are stored per restaurant:

```
restaurants/{restaurantId}/reservations/{reservationId}
```

## Security reminder

The following files must stay out of version control:

- `ReserveApp/GoogleService-Info.plist`
- `ReserveApp/Config.plist`
- `AuthKey_*.p8` APNS auth keys

They are already in `.gitignore`. Double-check before committing.

## Documentation

Historical fix notes and setup guides were moved to `docs/` to keep the project root clean.

## API fallback

If Firebase is unavailable, the app can fall back to the REST API at `api.restaurantmanagerpro.fr/api`.
