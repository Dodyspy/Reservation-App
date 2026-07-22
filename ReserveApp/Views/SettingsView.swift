import SwiftUI
import FirebaseFirestore

struct SettingsView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    // Availability controls
    @State private var isFull = false
    @State private var isClosed = false
    @State private var capacityOverride: Int = 30
    @State private var showCapacityPicker = false
    @State private var availabilityMessage = ""
    @State private var showAvailabilityAlert = false
    
    // User management
    @State private var showUserManagement = false
    @State private var showAuditLog = false
    @State private var showTimeSlotManagement = false
    
    var body: some View {
        NavigationView {
            Form {
                // AVAILABILITY CONTROL SECTION
                Section(header: Text("🪑 Contrôle de Disponibilité")) {
                    // Only owner/manager can toggle availability controls
                    if authService.currentUser?.hasPermission(.manageServices) == true {
                        Toggle(isOn: $isFull) {
                            VStack(alignment: .leading) {
                                Text("Restaurant Complet")
                                    .font(.headline)
                                Text("Bloquer toutes les réservations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: isFull) { newValue in
                            toggleFull(isFull: newValue)
                        }
                        
                        Toggle(isOn: $isClosed) {
                            VStack(alignment: .leading) {
                                Text("Fermé Temporairement")
                                    .font(.headline)
                                Text("Fermer les réservations temporairement")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: isClosed) { newValue in
                            toggleClosed(isClosed: newValue)
                        }
                        
                        // Capacity Override
                        Button(action: {
                            showCapacityPicker = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Capacité Aujourd'hui")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Limiter à \(capacityOverride) personnes par créneau")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Time Slot Extra Covers
                        Button(action: {
                            showTimeSlotManagement = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Créneaux Horaires")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Couverts supplémentaires par créneau")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "clock.badge.plus")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Status indicator (visible to all)
                    HStack {
                        Text("Statut")
                            .font(.headline)
                        Spacer()
                        if isClosed {
                            Label("Fermé", systemImage: "xmark.circle.fill")
                                .foregroundColor(.orange)
                        } else if isFull {
                            Label("Complet", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        } else {
                            Label("Ouvert", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Authentication Section
                Section(header: Text("👤 Compte")) {
                    if let user = authService.currentUser {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Label(user.role.displayName, systemImage: "person.badge.key")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            authService.signOut { _ in }
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Se déconnecter")
                                Spacer()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                // User Management Section (Owner only)
                if let user = authService.currentUser, user.canManageUsers() {
                    Section(header: Text("👥 Gestion des Utilisateurs")) {
                        Button(action: {
                            showUserManagement = true
                        }) {
                            HStack {
                                Image(systemName: "person.2")
                                Text("Gérer les Utilisateurs")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            showAuditLog = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Audit Log")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Restaurant Info Section
                Section(header: Text("ℹ️ Informations Restaurant")) {
                    if let restaurant = RestaurantManager.shared.currentRestaurant {
                        HStack {
                            Text("Restaurant")
                            Spacer()
                            Text(restaurant.name)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Code")
                            Spacer()
                            Text(restaurant.code)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Logout Section
                Section(header: Text("🚪 Déconnexion")) {
                    Button(action: {
                        // Sign out from Firebase auth first
                        authService.signOut { _ in
                            // Unsubscribe from notifications
                            if let restaurantCode = RestaurantManager.shared.restaurantCode {
                                let topicName = "\(restaurantCode.lowercased())-reservations"
                                NotificationService.shared.unsubscribeFromTopic(topicName)
                            }
                            
                            // Clear restaurant data and return to setup
                            UserDefaults.standard.removeObject(forKey: "selectedRestaurantCode")
                            UserDefaults.standard.removeObject(forKey: "restaurantDocumentId")
                            RestaurantManager.shared.currentRestaurant = nil
                            RestaurantManager.shared.isConfigured = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                            Text("Se Déconnecter")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load availability status
                loadAvailabilityStatus()
            }
            .alert(isPresented: $showAvailabilityAlert) {
                Alert(
                    title: Text("Disponibilité"),
                    message: Text(availabilityMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showCapacityPicker) {
                CapacityPickerView(capacity: $capacityOverride, onSave: {
                    setCapacityOverride(maxGuests: capacityOverride)
                })
            }
            .sheet(isPresented: $showUserManagement) {
                UserManagementView()
            }
            .sheet(isPresented: $showAuditLog) {
                AuditLogView()
            }
            .sheet(isPresented: $showTimeSlotManagement) {
                TimeSlotManagementView()
            }
        }
    }
    
    // MARK: - Availability Control Functions
    
    private func loadAvailabilityStatus() {
        guard RestaurantManager.shared.currentRestaurant?.code != nil else { return }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for loading availability")
            return
        }
        
        let db = Firestore.firestore()
        let restaurantRef = db.collection("restaurants").document(restaurantId)
        
        restaurantRef.getDocument { snapshot, error in
            if let error = error {
                print("Error loading availability: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            DispatchQueue.main.async {
                self.isFull = data["isFull"] as? Bool ?? false
                self.isClosed = data["temporarilyClosed"] as? Bool ?? false
                
                if let override = data["capacityOverride"] as? [String: Any],
                   let maxGuests = override["maxGuests"] as? Int {
                    self.capacityOverride = maxGuests
                } else {
                    self.capacityOverride = data["maxGuestsPerSlot"] as? Int ?? 30
                }
            }
        }
    }
    
    private func toggleFull(isFull: Bool) {
        guard RestaurantManager.shared.currentRestaurant?.code != nil else { return }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for toggling full status")
            return
        }
        
        let db = Firestore.firestore()
        let restaurantRef = db.collection("restaurants").document(restaurantId)
        
        let updates: [String: Any] = [
            "isFull": isFull,
            "fullReason": isFull ? "Restaurant complet" : NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        restaurantRef.updateData(updates) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.availabilityMessage = "Erreur: \(error.localizedDescription)"
                } else {
                    self.availabilityMessage = isFull ? "✅ Restaurant marqué comme complet" : "✅ Restaurant ouvert aux réservations"
                }
                self.showAvailabilityAlert = true
            }
        }
    }
    
    private func toggleClosed(isClosed: Bool) {
        guard RestaurantManager.shared.currentRestaurant?.code != nil else { return }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for toggling closed status")
            return
        }
        
        let db = Firestore.firestore()
        let restaurantRef = db.collection("restaurants").document(restaurantId)
        
        let updates: [String: Any] = [
            "temporarilyClosed": isClosed,
            "closedReason": isClosed ? "Fermé temporairement" : NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        restaurantRef.updateData(updates) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.availabilityMessage = "Erreur: \(error.localizedDescription)"
                } else {
                    self.availabilityMessage = isClosed ? "✅ Restaurant fermé temporairement" : "✅ Restaurant réouvert"
                }
                self.showAvailabilityAlert = true
            }
        }
    }
    
    private func setCapacityOverride(maxGuests: Int) {
        guard RestaurantManager.shared.currentRestaurant?.code != nil else { return }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for setting capacity override")
            return
        }
        
        let db = Firestore.firestore()
        let restaurantRef = db.collection("restaurants").document(restaurantId)
        
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        
        let override: [String: Any] = [
            "date": String(today),
            "maxGuests": maxGuests,
            "setAt": FieldValue.serverTimestamp()
        ]
        
        let updates: [String: Any] = [
            "capacityOverride": override,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        restaurantRef.updateData(updates) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.availabilityMessage = "Erreur: \(error.localizedDescription)"
                } else {
                    self.availabilityMessage = "✅ Capacité limitée à \(maxGuests) personnes pour aujourd'hui"
                }
                self.showAvailabilityAlert = true
            }
        }
    }
}

// MARK: - Capacity Picker View

struct CapacityPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var capacity: Int
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Capacité Maximum par Créneau")
                    .font(.headline)
                    .padding(.top)
                
                Picker("Capacité", selection: $capacity) {
                    ForEach([10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100], id: \.self) { value in
                        Text("\(value) personnes").tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                
                Text("Cette limite s'applique uniquement pour aujourd'hui")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Capacité")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Annuler") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Appliquer") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    SettingsView()
}
