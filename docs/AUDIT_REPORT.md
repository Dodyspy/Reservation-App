# ReservationApp Audit Report

Date: 2026-07-22
Scope: `/Users/sxy/AppTest/ReservationApp` — Casanova d'Issy iOS reservation app.

---

## 1. Edit Reservation Feature

**Status: Implemented.**

- UI: `ReserveApp/Views/EditReservationView.swift`
- Entry points: `ReserveApp/Views/ReservationDetailView.swift` (toolbar button + action sheet button)
- ViewModel method: `ReservationViewModel.updateReservation(_:completion:)`
- Editable fields: customer name, email, phone, number of guests, date, time, special requests.
- Status is intentionally not editable in this screen; status changes use the dedicated action sheet.

### Issues found

1. **Firebase-only update.** `updateReservation` writes directly to Firestore and does not use the `ReservationAPIService` fallback. If Firebase is unavailable and the app is in API mode, edits will fail.
2. **No availability recalculation.** Changing the date/time/guests does not trigger the `recalculateAvailability` Cloud Function. This can leave availability counters out of sync.
3. **No customer notification.** Editing a reservation does not send an email/SMS update to the customer.
4. **Hard-coded time slots.** Both `AddReservationView` and `EditReservationView` use the same fixed `timeSlots` array (`12:00`–`14:30`, `19:00`–`22:00`). They should be driven by the restaurant's configured opening hours.

### Recommendation

Route edits through the same backend path as creation (`save-reservation` Cloud Function / API) so availability, customer notification, and audit logic are handled consistently.

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

- **No Git repository** in this folder (`git status` fails). Ensure this is backed up / versioned elsewhere.
- **Sensitive files present**:
  - `ReserveApp/GoogleService-Info.plist`
  - `ReserveApp/Config.plist`
  - `AuthKey_8CC36M94AV.p8`
- All three are in `.gitignore`, but verify they are never committed or shared.
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

1. **Put this folder under Git** and commit the cleanup.
2. **Add edit-reservation API support** and trigger availability recalculation.
3. **Add customer notification** on reservation edits.
4. **Remove or wrap debug logs** before release.
5. **Add unit tests** for core ViewModel and Service logic.
6. **Test edit flow on device** after cleanup to ensure archiving did not break references.
