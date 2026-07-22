# iOS App Interface Improvements

## Issues Identified

### 1. ❌ Empty Circle on Top Left (Reservations Tab)
**Location:** Line 266 in `ReservationListView.swift`
```swift
.navigationBarItems(
    leading: HStack { EmptyView() },  // ← This creates empty space
```

**Problem:** Creates an empty HStack that shows as a blank circle/space
**Fix:** Remove the empty leading item

---

### 2. ❌ Customer Detail View - Empty Page / Slow Loading
**Problem:** When clicking on a customer, page appears empty initially
**Root Cause:** 
- `CustomerDetailView` wraps content in `NavigationView` (line 377)
- Already inside a `NavigationView` from parent
- Double navigation causes rendering issues

**Fix:** Remove the nested `NavigationView` from `CustomerDetailView`

---

### 3. ❌ No Delete Customer Option
**Problem:** Cannot delete customers from the app
**Solution:** Add swipe-to-delete and delete button in customer detail view

---

### 4. ❌ No Manual Reservation Creation
**Problem:** Cannot add reservations manually from the app
**Solution:** Add "+" button to create reservations manually

---

### 5. ❌ No Reservation Modification
**Problem:** Cannot edit existing reservations
**Solution:** Add edit button in reservation detail view

---

## Implementation Plan

### Fix 1: Remove Empty Circle (EASY - 2 minutes)
**File:** `Views/ReservationListView.swift`
**Line:** 266

**Change:**
```swift
// BEFORE
.navigationBarItems(
    leading: HStack { EmptyView() },
    trailing: HStack {
        // ... buttons
    }
)

// AFTER
.navigationBarItems(
    trailing: HStack {
        // ... buttons
    }
)
```

---

### Fix 2: Customer Detail Loading Issue (EASY - 5 minutes)
**File:** `Views/CustomerProfileView.swift`
**Line:** 377

**Change:**
```swift
// BEFORE
var body: some View {
    NavigationView {
        ScrollView {
            // ... content
        }
    }
}

// AFTER
var body: some View {
    ScrollView {
        // ... content
    }
    .navigationTitle(customer.primary_name ?? "Client")
    .navigationBarTitleDisplayMode(.inline)
}
```

---

### Fix 3: Add Delete Customer (MEDIUM - 30 minutes)

#### A. Add Swipe-to-Delete in Customer List
**File:** `Views/CustomerProfileView.swift`
**Location:** Around line 200 (in the List)

**Add:**
```swift
List {
    ForEach(filteredAndSortedCustomers) { customer in
        Button(action: {
            selectedCustomer = customer
            showingCustomerDetail = true
        }) {
            CustomerRowView(customer: customer)
        }
    }
    .onDelete(perform: deleteCustomers)  // ← ADD THIS
}
```

**Add function:**
```swift
private func deleteCustomers(at offsets: IndexSet) {
    for index in offsets {
        let customer = filteredAndSortedCustomers[index]
        customerViewModel.deleteCustomer(customer)
    }
}
```

#### B. Add Delete Button in Customer Detail
**File:** `Views/CustomerProfileView.swift`
**Location:** In `CustomerDetailView` navigation bar

**Add:**
```swift
.navigationBarItems(trailing: Button(action: {
    // Show confirmation alert
    showingDeleteAlert = true
}) {
    Image(systemName: "trash")
        .foregroundColor(.red)
})
.alert("Supprimer le client", isPresented: $showingDeleteAlert) {
    Button("Annuler", role: .cancel) { }
    Button("Supprimer", role: .destructive) {
        customerViewModel.deleteCustomer(customer)
        dismiss()
    }
} message: {
    Text("Êtes-vous sûr de vouloir supprimer ce client ? Cette action est irréversible.")
}
```

#### C. Add Delete Function to CustomerViewModel
**File:** `ViewModels/CustomerViewModel.swift`

**Add:**
```swift
func deleteCustomer(_ customer: Customer) {
    guard let customerId = customer.id,
          let restaurantCode = RestaurantManager.shared.restaurantCode else {
        return
    }
    
    let db = Firestore.firestore()
    db.collection("restaurants")
        .document(restaurantCode)
        .collection("customers")
        .document(customerId)
        .delete() { error in
            if let error = error {
                print("❌ Error deleting customer: \(error)")
            } else {
                print("✅ Customer deleted successfully")
            }
        }
}
```

---

### Fix 4: Add Manual Reservation Creation (COMPLEX - 2-3 hours)

#### A. Create AddReservationView
**New File:** `Views/AddReservationView.swift`

```swift
import SwiftUI

struct AddReservationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReservationViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedDate = Date()
    @State private var time = ""
    @State private var guests = 2
    @State private var notes = ""
    @State private var status: ReservationStatus = .pending
    
    private let timeSlots = [
        "12:00", "12:30", "13:00", "13:30", "14:00",
        "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informations Client")) {
                    TextField("Nom", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Détails de la Réservation")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Heure", selection: $time) {
                        Text("Sélectionner").tag("")
                        ForEach(timeSlots, id: \.self) { slot in
                            Text(slot).tag(slot)
                        }
                    }
                    
                    Stepper("Nombre de personnes: \(guests)", value: $guests, in: 1...20)
                    
                    Picker("Statut", selection: $status) {
                        ForEach(ReservationStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Nouvelle Réservation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        createReservation()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !email.isEmpty && !time.isEmpty
    }
    
    private func createReservation() {
        guard let restaurantCode = RestaurantManager.shared.restaurantCode else {
            return
        }
        
        let reservation = Reservation(
            id: nil,
            name: name,
            email: email,
            phone: phone,
            date: selectedDate,
            time: time,
            guests: guests,
            notes: notes.isEmpty ? nil : notes,
            status: status,
            createdAt: Date()
        )
        
        // Save to Firestore
        RestaurantService.shared.createReservation(reservation, restaurantCode: restaurantCode) { error in
            if let error = error {
                print("❌ Error creating reservation: \(error)")
            } else {
                print("✅ Reservation created successfully")
                dismiss()
            }
        }
    }
}
```

#### B. Add "+" Button to Reservations Tab
**File:** `Views/ReservationListView.swift`
**Location:** Line 291-300 (in navigationBarItems trailing)

**Change:**
```swift
.navigationBarItems(
    trailing: HStack {
        // ADD THIS - Manual reservation button
        Button(action: {
            showingAddReservation = true
        }) {
            Image(systemName: "plus.circle")
                .foregroundColor(AppTheme.gold)
        }
        .accessibilityLabel("Créer une réservation")
        
        // ... existing buttons (notifications, test, disconnect, settings)
    }
)
```

**Add state variable:**
```swift
@State private var showingAddReservation = false
```

**Add sheet:**
```swift
.sheet(isPresented: $showingAddReservation) {
    AddReservationView(viewModel: viewModel)
}
```

#### C. Add Create Function to RestaurantService
**File:** `Services/RestaurantService.swift`

**Add:**
```swift
func createReservation(_ reservation: Reservation, restaurantCode: String, completion: @escaping (Error?) -> Void) {
    let db = Firestore.firestore()
    
    var reservationData: [String: Any] = [
        "name": reservation.name,
        "email": reservation.email,
        "phone": reservation.phone,
        "date": Timestamp(date: reservation.date),
        "time": reservation.time,
        "guests": reservation.guests,
        "status": reservation.status.rawValue,
        "createdAt": Timestamp(date: Date())
    ]
    
    if let notes = reservation.notes {
        reservationData["notes"] = notes
    }
    
    db.collection("restaurants")
        .document(restaurantCode)
        .collection("reservations")
        .addDocument(data: reservationData) { error in
            completion(error)
        }
}
```

---

### Fix 5: Add Reservation Modification (COMPLEX - 2-3 hours)

#### A. Create EditReservationView
**New File:** `Views/EditReservationView.swift`

Similar to `AddReservationView` but pre-fills with existing data:

```swift
import SwiftUI

struct EditReservationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReservationViewModel
    let reservation: Reservation
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var selectedDate: Date
    @State private var time: String
    @State private var guests: Int
    @State private var notes: String
    @State private var status: ReservationStatus
    
    init(reservation: Reservation, viewModel: ReservationViewModel) {
        self.reservation = reservation
        self.viewModel = viewModel
        
        // Initialize state with existing values
        _name = State(initialValue: reservation.name)
        _email = State(initialValue: reservation.email)
        _phone = State(initialValue: reservation.phone)
        _selectedDate = State(initialValue: reservation.date)
        _time = State(initialValue: reservation.time)
        _guests = State(initialValue: reservation.guests)
        _notes = State(initialValue: reservation.notes ?? "")
        _status = State(initialValue: reservation.status)
    }
    
    // ... similar body to AddReservationView but with "Modifier" button
    
    private func updateReservation() {
        guard let reservationId = reservation.id,
              let restaurantCode = RestaurantManager.shared.restaurantCode else {
            return
        }
        
        let updatedReservation = Reservation(
            id: reservationId,
            name: name,
            email: email,
            phone: phone,
            date: selectedDate,
            time: time,
            guests: guests,
            notes: notes.isEmpty ? nil : notes,
            status: status,
            createdAt: reservation.createdAt
        )
        
        RestaurantService.shared.updateReservation(updatedReservation, restaurantCode: restaurantCode) { error in
            if let error = error {
                print("❌ Error updating reservation: \(error)")
            } else {
                print("✅ Reservation updated successfully")
                dismiss()
            }
        }
    }
}
```

#### B. Add Edit Button to ReservationDetailView
**File:** `Views/ReservationDetailView.swift`

**Add:**
```swift
@State private var showingEditReservation = false

// In navigation bar
.navigationBarItems(trailing: Button(action: {
    showingEditReservation = true
}) {
    Image(systemName: "pencil")
        .foregroundColor(AppTheme.gold)
})
.sheet(isPresented: $showingEditReservation) {
    EditReservationView(reservation: reservation, viewModel: viewModel)
}
```

#### C. Add Update Function to RestaurantService
**File:** `Services/RestaurantService.swift`

**Add:**
```swift
func updateReservation(_ reservation: Reservation, restaurantCode: String, completion: @escaping (Error?) -> Void) {
    guard let reservationId = reservation.id else {
        completion(NSError(domain: "ReservationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reservation ID is missing"]))
        return
    }
    
    let db = Firestore.firestore()
    
    var reservationData: [String: Any] = [
        "name": reservation.name,
        "email": reservation.email,
        "phone": reservation.phone,
        "date": Timestamp(date: reservation.date),
        "time": reservation.time,
        "guests": reservation.guests,
        "status": reservation.status.rawValue,
        "updatedAt": Timestamp(date: Date())
    ]
    
    if let notes = reservation.notes {
        reservationData["notes"] = notes
    }
    
    db.collection("restaurants")
        .document(restaurantCode)
        .collection("reservations")
        .document(reservationId)
        .updateData(reservationData) { error in
            completion(error)
        }
}
```

---

## Priority Order

### Immediate (Do Now - 15 minutes)
1. ✅ Remove empty circle (2 min)
2. ✅ Fix customer detail loading (5 min)
3. ✅ Add delete customer option (8 min)

### Short Term (This Week - 4-6 hours)
4. ⏳ Add manual reservation creation (2-3 hours)
5. ⏳ Add reservation modification (2-3 hours)

### Additional Improvements (Optional)
- Add bulk delete for customers
- Add customer import/export
- Add reservation templates
- Add quick actions (swipe gestures)
- Add reservation duplication
- Add customer merge functionality

---

## Testing Checklist

### After Fix 1 (Empty Circle)
- [ ] Open app
- [ ] Go to Reservations tab
- [ ] Verify no empty space/circle on top left

### After Fix 2 (Customer Detail)
- [ ] Go to Clients tab
- [ ] Tap on a customer
- [ ] Verify detail page loads immediately
- [ ] Verify all information displays correctly

### After Fix 3 (Delete Customer)
- [ ] Go to Clients tab
- [ ] Swipe left on a customer
- [ ] Verify delete button appears
- [ ] Delete a test customer
- [ ] Verify customer is removed from list
- [ ] Open customer detail
- [ ] Tap trash icon
- [ ] Confirm deletion
- [ ] Verify customer is deleted

### After Fix 4 (Add Reservation)
- [ ] Go to Reservations tab
- [ ] Tap "+" button
- [ ] Fill in all fields
- [ ] Create reservation
- [ ] Verify reservation appears in list
- [ ] Verify reservation syncs to Firestore

### After Fix 5 (Edit Reservation)
- [ ] Open a reservation
- [ ] Tap edit button
- [ ] Modify fields
- [ ] Save changes
- [ ] Verify changes appear in list
- [ ] Verify changes sync to Firestore

---

## Estimated Time

- **Immediate Fixes:** 15 minutes
- **Full Implementation:** 6-8 hours
- **Testing:** 1-2 hours
- **Total:** ~8-10 hours

---

Would you like me to implement these fixes now? I recommend starting with the immediate fixes (1-3) which will take only 15 minutes.
