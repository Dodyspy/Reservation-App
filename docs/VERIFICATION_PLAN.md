# ReservationApp Verification Plan

Use this checklist after the edit-reservation backend refactor to confirm nothing is broken.

## 1. Build verification

1. Open `/Users/sxy/AppTest/ReservationApp/ReserveApp.xcodeproj` in Xcode.
2. Select a simulator (e.g., iPhone 15 Pro).
3. Press **Cmd+B** to build.

Expected result: build succeeds with no errors. If you see a compiler error around `updateReservation(original:updated:)`, it means a call site was missed.

## 2. Edit-reservation happy path

1. Log in and select a restaurant.
2. Open an existing reservation from the list.
3. Tap **Modifier la Réservation**.
4. Change only the customer name and save.

Expected result:
- Success alert appears.
- The reservation detail shows the new name.
- Firestore document is updated.
- `updatedAt` is set.
- `modifiedBy`, `modifiedByName`, `modifiedByEmail`, and `modifiedAt` are written to the reservation document.
- An `updateReservation` audit log entry is created in `restaurants/{id}/audit_logs`.

## 3. Edit date/time/guests (availability sync)

1. Open a reservation.
2. Change the **date** or **time** or **number of guests**.
3. Save.

Expected result:
- Success alert.
- Firestore document is updated.
- The `recalculateAvailability` Cloud Function is triggered (check Firebase Functions logs).
- The widget/backoffice for the new date/time reflects the updated reservation.

## 4. Move reservation to a different day

1. Edit a reservation and change its date to tomorrow.
2. Save.

Expected result:
- The reservation appears under the new date in the app.
- The Cloud Function recalculates availability for the new date.
- Note: the original date's availability is not automatically recalculated with the current endpoint. Trigger a manual recalc or add a backend endpoint that accepts a specific date if this matters for your workflow.

## 5. API fallback mode

1. In `AppConfig.swift` or UserDefaults, set the data source to `.api` (or temporarily disable Firebase in the scheme).
2. Restart the app.
3. Edit a reservation and save.

Expected result:
- `ReservationAPIService.updateReservation` is called.
- Network traffic shows a `POST` to `api.restaurantmanagerpro.fr/api/save-reservation`.
- Request body includes the updated reservation fields **and** `modifiedBy`, `modifiedByName`, `modifiedByEmail`.

## 6. Staff notification on edit

1. Deploy `sendUpdatedReservationNotification` Cloud Function in `/Users/sxy/AppTest/Casanovadissy/casanovadissy-site/functions/index.js`:
   ```bash
   cd /Users/sxy/AppTest/Casanovadissy/casanovadissy-site/functions
   firebase deploy --only functions:sendUpdatedReservationNotification
   ```
2. Log in to the app on two different devices or simulator instances (same restaurant, different staff accounts).
3. On device A, edit a reservation and save.

Expected result:
- Device B receives a push notification with title **“✏️ Réservation modifiée”**.
- Notification body contains the modifier name (e.g., `John a modifie la reservation de ...`).
- Tapping the notification opens the reservation detail.
- The deduplication logic in `ReserveAppApp.swift` does **not** suppress the update because the dedup key includes the notification type.

## 7. Modified-by display

1. Open a reservation that has been edited.

Expected result:
- Below the reservation details, a caption shows **“Modifié par {name} le {date} {time}”** if `modifiedByName` and `modifiedAt` are present.

## 8. Offline/error handling

1. Edit a reservation.
2. Turn on airplane mode or use a bad network link conditioner.
3. Save.

Expected result:
- Error alert is shown.
- The edit view stays open so the user can retry.

## 9. Regression: status change still works

1. Open a reservation.
2. Tap **Modifier le Statut**.
3. Set it to **Arrivé** or **Terminée**.

Expected result:
- Status updates in Firestore.
- `arrivedAt` or `finishedAt` is set.
- `recalculateAvailability` is triggered when marking **Terminée** or **No-show**.

## 10. Regression: add new reservation

1. Tap the add button and create a new reservation.

Expected result:
- Reservation is created.
- No compiler errors or runtime crashes.

## 11. Automated tests to add

- `ReservationViewModel.updateReservation` routes to `RestaurantService` when `useFirebase == true`.
- `ReservationViewModel.updateReservation` routes to `ReservationAPIService` when `useFirebase == false`.
- `RestaurantService.updateReservation` calls `triggerAvailabilityRecalculation` when date/time/guests change.
- `RestaurantService.updateReservation` writes `modifiedBy`, `modifiedByName`, `modifiedByEmail`, and `modifiedAt` when a modifier is provided.
- `RestaurantService.updateReservation` writes an `AuditService.updateReservation` entry after a successful update.
