# 📱 Restaurant Manager Pro - iOS App

**New Standalone Location:** `/Users/sxy/AppTest/ReservationApp`

---

## ✅ App Successfully Isolated

The iOS reservation app has been moved from:
- **Old:** `/Users/sxy/AppTest/Casanovadissy/ReserveApp_Backup`
- **New:** `/Users/sxy/AppTest/ReservationApp`

This separates the iOS app from restaurant-specific projects, making it a standalone component of the SaaS platform.

---

## 📁 Project Structure

```
/Users/sxy/AppTest/ReservationApp/
├── ReserveApp.xcodeproj          # Xcode project file
├── ReserveApp/                    # Source code
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   └── Services/
├── ReserveAppTests/               # Unit tests
├── ReserveAppUITests/             # UI tests
└── Documentation/                 # Various MD files
```

---

## 🔧 Configuration

### **Project Details:**
- **Bundle ID:** `fr.casanova.ReserveApp`
- **Team ID:** `HV9UP5L8B3`
- **Deployment Target:** iOS 16.0+
- **Dependencies:** Swift Package Manager (Firebase 12.0.0)

### **Firebase Configuration:**
- **Project:** `casanova-dissy-reservations`
- **Restaurant Code:** `CASANOVA2024` (multi-tenant support)

### **Features:**
- ✅ Multi-tenant restaurant system
- ✅ Real-time Firestore sync
- ✅ Push notifications (background + killed app)
- ✅ Restaurant branding system
- ✅ Table management
- ✅ Customer tracking

---

## 🚀 How to Build

### **1. Open in Xcode:**
```bash
cd /Users/sxy/AppTest/ReservationApp
open ReserveApp.xcodeproj
```

### **2. If SPM cache issues:**
- File → Packages → Reset Package Caches
- Product → Clean Build Folder (⇧⌘K)
- Product → Build (⌘B)

### **3. Run on Device:**
- Select your device
- Click Run (⌘R)

---

## ⚠️ Important Notes

### **DO NOT:**
- ❌ Use CocoaPods (project uses SPM only)
- ❌ Open `.xcworkspace` (doesn't exist)
- ❌ Mix SPM and CocoaPods
- ❌ Run `pod install`

### **Dependencies (SPM):**
- FirebaseAnalytics
- FirebaseFirestore
- FirebaseMessaging

---

## 🔐 Push Notifications

### **APNS Configuration:**
- **Auth Key:** `AuthKey_8CC36M94AV.p8` (in project root)
- **Key ID:** `8CC36M94AV`
- **Team ID:** `HV9UP5L8B3`

### **Firebase Cloud Messaging:**
- Configured and working
- Notifications work when app is killed
- Real-time updates via Firestore listeners

---

## 📊 Architecture

### **Data Flow:**
```
iOS App (ReservationApp)
    ↓
Firebase Firestore
    ↓
Multi-tenant structure: /restaurants/{code}/reservations/
    ↓
Backoffice (app.restaurantmanagerpro.fr)
    ↓
Widget (widget.restaurantmanagerpro.fr)
```

---

## 🎯 Multi-Tenant System

The app supports multiple restaurants:
- Each restaurant has a unique code (e.g., `CASANOVA2024`)
- Staff enters code on first launch
- App connects to that restaurant's data
- Separate collections per restaurant in Firestore

---

## 📖 Additional Documentation

See the various `.md` files in this directory for:
- APNS setup guides
- Push notification troubleshooting
- Performance fixes
- UI improvements
- Manual reservation features
- And more...

---

## 🔄 Recent Changes

**January 4, 2026:**
- Moved from `/Users/sxy/AppTest/Casanovadissy/ReserveApp_Backup`
- Now standalone at `/Users/sxy/AppTest/ReservationApp`
- Part of SaaS platform isolation project

---

## 🎉 Status

**✅ Fully Functional**
- All features working
- Push notifications operational
- Multi-tenant system ready
- Production-ready for App Store

---

## 📞 Related Projects

This iOS app is part of the Restaurant Manager Pro SaaS platform:

| Component | Location |
|-----------|----------|
| **iOS App** | `/Users/sxy/AppTest/ReservationApp` |
| **API Backend** | `/Users/sxy/AppTest/SaaS Reservations/restaurant-manager-api` |
| **Backoffice** | `/Users/sxy/AppTest/SaaS Reservations/restaurant-manager-backoffice` |
| **Widget** | `/Users/sxy/AppTest/SaaS Reservations/reservation-widget` |
| **Marketing** | `/Users/sxy/AppTest/SaaS Reservations/restaurant-manager-marketing` |
