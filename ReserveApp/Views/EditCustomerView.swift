import SwiftUI

struct EditCustomerView: View {
    let customer: Customer
    let customerViewModel: CustomerViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var primaryName: String
    @State private var primaryEmail: String
    @State private var primaryPhone: String
    @State private var vipStatus: Customer.VIPStatus
    @State private var notes: String
    @State private var birthday: Date?
    @State private var anniversary: Date?
    @State private var showingDeleteConfirmation = false
    
    // Preferences
    @State private var preferredSeating: Table.TableLocation?
    @State private var dietaryRestrictions: String = ""
    @State private var allergies: String = ""
    @State private var communicationPreference: Customer.CustomerPreferences.CommunicationPreference = .both
    
    init(customer: Customer, customerViewModel: CustomerViewModel) {
        self.customer = customer
        self.customerViewModel = customerViewModel
        
        self._primaryName = State(initialValue: customer.primary_name ?? "")
        self._primaryEmail = State(initialValue: customer.primary_email)
        self._primaryPhone = State(initialValue: customer.primary_phone)
        self._vipStatus = State(initialValue: customer.vip_status ?? .regular)
        self._notes = State(initialValue: customer.notes ?? "")
        self._birthday = State(initialValue: customer.birthday)
        self._anniversary = State(initialValue: customer.anniversary)
        
        // Initialize preferences
        if let prefs = customer.preferences {
            self._preferredSeating = State(initialValue: prefs.preferred_seating)
            self._dietaryRestrictions = State(initialValue: prefs.dietary_restrictions?.joined(separator: ", ") ?? "")
            self._allergies = State(initialValue: prefs.allergies?.joined(separator: ", ") ?? "")
            self._communicationPreference = State(initialValue: prefs.communication_preference ?? .both)
        }
    }
    
    private var isValid: Bool {
        !primaryEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        primaryEmail.contains("@") &&
        !primaryPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations personnelles") {
                    HStack {
                        Text("Nom")
                        Spacer()
                        TextField("Nom du client", text: $primaryName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        TextField("email@exemple.com", text: $primaryEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Téléphone")
                        Spacer()
                        TextField("06 12 34 56 78", text: $primaryPhone)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Statut client") {
                    Picker("Statut VIP", selection: $vipStatus) {
                        ForEach(Customer.VIPStatus.allCases, id: \.self) { status in
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    
                    HStack {
                        Text("Réservations totales")
                        Spacer()
                        Text("\(customer.total_reservations)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("No-shows")
                        Spacer()
                        Text("\(customer.no_show_count)")
                            .foregroundColor(customer.no_show_count > 0 ? .red : .secondary)
                    }
                }
                
                Section("Préférences") {
                    Picker("Placement préféré", selection: $preferredSeating) {
                        Text("Aucune préférence").tag(nil as Table.TableLocation?)
                        ForEach(Table.TableLocation.allCases.filter { $0 != .custom }, id: \.self) { location in
                            HStack {
                                Image(systemName: location.icon)
                                Text(location.displayName)
                            }
                            .tag(location as Table.TableLocation?)
                        }
                    }
                    
                    Picker("Communication", selection: $communicationPreference) {
                        ForEach(Customer.CustomerPreferences.CommunicationPreference.allCases, id: \.self) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restrictions alimentaires")
                        TextField("Végétarien, sans gluten, etc.", text: $dietaryRestrictions, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Allergies")
                        TextField("Fruits à coque, lactose, etc.", text: $allergies, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                
                Section("Dates importantes") {
                    DatePicker("Anniversaire", selection: Binding(
                        get: { birthday ?? Date() },
                        set: { birthday = $0 }
                    ), displayedComponents: .date)
                    .disabled(birthday == nil)
                    
                    Toggle("Anniversaire renseigné", isOn: Binding(
                        get: { birthday != nil },
                        set: { if !$0 { birthday = nil } else { birthday = Date() } }
                    ))
                    
                    DatePicker("Anniversaire de mariage", selection: Binding(
                        get: { anniversary ?? Date() },
                        set: { anniversary = $0 }
                    ), displayedComponents: .date)
                    .disabled(anniversary == nil)
                    
                    Toggle("Anniversaire de mariage renseigné", isOn: Binding(
                        get: { anniversary != nil },
                        set: { if !$0 { anniversary = nil } else { anniversary = Date() } }
                    ))
                }
                
                Section("Notes") {
                    TextField("Notes sur le client...", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section {
                    Button("Supprimer le client", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Modifier Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveCustomer()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .alert("Supprimer le client", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                customerViewModel.deleteCustomer(customer)
                dismiss()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer ce client ? Cette action supprimera toutes ses données mais conservera ses réservations.")
        }
    }
    
    private func saveCustomer() {
        var updatedCustomer = customer
        
        // Update basic info
        updatedCustomer.primary_name = primaryName.isEmpty ? nil : primaryName
        updatedCustomer.primary_email = primaryEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCustomer.primary_phone = primaryPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCustomer.vip_status = vipStatus
        updatedCustomer.notes = notes.isEmpty ? nil : notes
        updatedCustomer.birthday = birthday
        updatedCustomer.anniversary = anniversary
        
        // Update preferences
        let preferences = Customer.CustomerPreferences(
            preferred_seating: preferredSeating,
            dietary_restrictions: dietaryRestrictions.isEmpty ? nil : dietaryRestrictions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            favorite_dishes: customer.preferences?.favorite_dishes,
            allergies: allergies.isEmpty ? nil : allergies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            special_occasions: customer.preferences?.special_occasions,
            communication_preference: communicationPreference
        )
        updatedCustomer.preferences = preferences
        
        customerViewModel.updateCustomer(updatedCustomer)
        dismiss()
    }
}

#Preview {
    EditCustomerView(
        customer: Customer(
            primary_email: "test@example.com",
            primary_phone: "0612345678",
            total_reservations: 5,
            no_show_count: 1
        ),
        customerViewModel: CustomerViewModel()
    )
}
