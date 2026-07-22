# ReservationApp Audit Report

Date: 2026-07-22
Scope: `/Users/sxy/AppTest/ReservationApp` — Casanova d'Issy iOS reservation app.

---

## 1. Edit Reservation Feature

**Status: Implemented.**

- UI: `ReserveApp/Views/EditReservationView.swift`
- Entry points: `ReserveApp/Views/ReservationDetailView.swift` (toolbar button + action sheet button)
- ViewModel method: `ReservationViewModel.updateReservation(original:updated:completion:)`
- Editable fields: customer name, email, phone, number of guests, date, time, special requests.
- Status is intentionally not editable in this screen; status changes use the dedicated action sheet.

### Issues found

1. **Firebase-only update.** ~~`updateReservation` writes directly to Firestore and does not use the `ReservationAPIService` fallback.~~ **Fixed** — now routes through `RestaurantService` or `ReservationAPIService` based on `useFirebase`.
2. **No availability recalculation.** ~~Changing the date/time/guests does not trigger the `recalculateAvailability` Cloud Function.~~ **Fixed** — `RestaurantService.updateReservation` triggers recalculation when date/time/guests change.
3. **No customer notification.** Editing a reservation does not send an email/SMS update to the customer.
4. **No staff notification on edits.** ~~Editing a reservation did not alert other connected staff.~~ **Fixed** — Firestore `onUpdate` Cloud Function `sendUpdatedReservationNotification` sends an FCM push to the restaurant topic; the iOS notification handler distinguishes `reservation_updated` from `new_reservation`.
5. **No audit trail for edits.** ~~The app did not track who modified a reservation or what changed.~~ **Fixed** — `RestaurantService.updateReservation` stores `modifiedBy`, `modifiedByName`, `modifiedByEmail`, `modifiedAt` on the reservation document, writes an `AuditService.updateReservation` entry, and `ReservationDetailView` displays the modifier and timestamp.
6. **Hard-coded time slots.** Both `AddReservationView` and `EditReservationView` use the same fixed `timeSlots` array (`12:00`–`14:30`, `19:00`–`22:00`). They should be driven by the restaurant's configured opening hours.

### Changes made

- Added `RestaurantService.updateReservation(original:updated:restaurantCode:modifiedBy:completion:)` in `ReserveApp/Services/RestaurantService.swift`.
- Added `ReservationAPIService.updateReservation(_:modifiedBy:completion:)` in `ReserveApp/Services/ReservationAPIService.swift`.
- Refactored `ReservationViewModel.updateReservation(original:updated:completion:)` to choose the correct backend and pass the current authenticated user.
- Updated `EditReservationView.saveChanges` to pass both the original and updated reservations.
- Added `modifiedBy`, `modifiedByName`, `modifiedByEmail`, `modifiedAt` fields to `Reservation.swift` model and `ReservationDetailView` UI.
- Added `sendUpdatedReservationNotification` Firestore `onUpdate` Cloud Function in `/Users/sxy/AppTest/Casanovadissy/casanovadissy-site/functions/index.js` to push staff notifications on reservation edits.
- Updated iOS notification deduplication in `ReserveAppApp.swift` to include notification type, preventing new and update notifications for the same reservation from suppressing each other.

---

## 2. Dead Code Archived

The following files were not referenced anywhere in the project (only self-references/previews). They were moved to `_archive/` to clean the build without deleting them.

- `ReserveApp/Services/FirebaseService.swift` — legacy single-tenant Firestore wrapper.
- `ReserveApp/Services/DataMigrationService.swift` — unused migration helper.
- `ReserveApp/Services/RestaurantSetupService.swift` — unused sample-data seeder.
- `ReserveApp/Views/FirebaseTestView.swift` — unused debug view.

> The project uses Xcode's `fileSystemSynchronizedGroups`, so removing these files from the folder removes them from the build automatically.

---

## 3. Project Structure

- **Pattern**: MVVM + SwiftUI.
- **Sync**: Firestore real-time listeners per restaurant (`restaurants/{id}/reservations`).
- **Build system**: Swift Package Manager (Firebase Analytics, AnalyticsCore, Firestore, Messaging, Auth).
- **Deployment target**: iOS 16.0 (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`).
- **Bundle ID**: `fr.casanova.RestaurantManager`.

### Fixed README inaccuracies

- iOS requirement was listed as 15.0+; project targets 16.0.
- Dependency manager was listed as CocoaPods; project uses SPM.
- Missing mention of the edit-reservation feature.
- Missing data-model path (`restaurants/{id}/reservations`).

---

## 4. Security & Configuration

- Git repository exists and is pushed to `https://github.com/Dodyspy/Reservation-App`.
- **Sensitive files present** (must stay in `.gitignore` and never be shared):
  - `ReserveApp/GoogleService-Info.plist`
  - `ReserveApp/Config.plist`
  - `AuthKey_8CC36M94AV.p8`
- API fallback uses a hard-coded `x-api-key: casanova-reserve-app-key` in `ReservationAPIService.swift`. Rotate this if it is a real secret.

---

## 5. Code Quality

- **Excessive logging**: ~411 `print()` / `NSLog()` calls across the codebase. Remove or wrap with a debug flag before App Store submission.
- **Force-unwrap / `try?`**: Several `try?` decodes silently drop failures (e.g., `FirebaseService.getReservations`). Prefer explicit error handling.
- **Massive view files**: `ReservationListView.swift` (~41 KB), `CustomerProfileView.swift` (~31 KB), `ReserveAppApp.swift` (~20 KB). Consider splitting into smaller subviews for maintainability.
- **State duplication**: `RestaurantManager`, `AuthenticationService`, and several view models all read/write `UserDefaults` keys. Centralize persistence.

---

## 6. Testing

- `ReserveAppTests/` contains a single nearly-empty file.
- `ReserveAppUITests/` exists but was not reviewed.
- **Recommendation**: Add unit tests for `ReservationViewModel` status transitions, `RestaurantService` collection paths, and date parsing edge cases.

---

## 7. Known Pending Items (from previous notes)

- Empty circle on navigation bar (cosmetic).
- Customer detail view loading issue.
- Duplicate notification cleanup.
- Build and test on a physical device.

---

## 8. Cleanup Done

- Moved 41 historical fix/setup markdown files from project root to `docs/`.
- Archived 4 unused Swift files to `_archive/`.
- Rewrote `README.md` with accurate requirements, setup steps, and architecture.

---

## 9. Recommended Next Steps

1. ~~Put this folder under Git and commit the cleanup.~~ Done.
2. ~~Add edit-reservation API support and trigger availability recalculation.~~ Done.
3. **Deploy the `sendUpdatedReservationNotification` Cloud Function** in `/Users/sxy/AppTest/Casanovadissy/casanovadissy-site/functions/index.js` so staff receive real-time notifications.
4. **Add customer notification** on reservation edits (email/SMS with updated details).
5. **Remove or wrap debug logs** before release.
6. **Add unit tests** for core ViewModel and Service logic.
7. **Test edit flow on device** after cleanup to ensure archiving did not break references.
