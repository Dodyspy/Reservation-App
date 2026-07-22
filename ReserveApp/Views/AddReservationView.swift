import SwiftUI

struct AddReservationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ReservationViewModel
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    
    // Form fields
    @State private var customerName = ""
    @State private var customerEmail = ""
    @State private var customerPhone = ""
    @State private var numberOfGuests = 2
    @State private var reservationDate = Date()
    @State private var reservationTime = "19:00"
    @State private var specialRequests = ""
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    // Time slots
    private let timeSlots = [
        "12:00", "12:30", "13:00", "13:30", "14:00", "14:30",
        "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Restaurant Status Warning
                if let restaurant = restaurantManager.currentRestaurant,
                   let message = restaurant.getClosureMessage() {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Attention")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Les nouvelles réservations ne peuvent pas être créées pour le moment.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                // Customer Information Section
                Section(header: Text("Informations Client").foregroundColor(AppTheme.gold)) {
                    TextField("Nom complet *", text: $customerName)
                        .textContentType(.name)
                    
                    TextField("Email (optionnel)", text: $customerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Téléphone (optionnel)", text: $customerPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                // Reservation Details Section
                Section(header: Text("Détails de la Réservation").foregroundColor(AppTheme.gold)) {
                    // Date picker
                    DatePicker("Date", selection: $reservationDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    // Time picker
                    Picker("Heure", selection: $reservationTime) {
                        ForEach(timeSlots, id: \.self) { time in
                            Text(time).tag(time)
                        }
                    }
                    
                    // Number of guests stepper
                    Stepper("Nombre de convives: \(numberOfGuests)", value: $numberOfGuests, in: 1...20)
                }
                
                // Special Requests Section
                Section(header: Text("Demandes Spéciales").foregroundColor(AppTheme.gold)) {
                    TextEditor(text: $specialRequests)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Restaurant Info
                if let restaurant = restaurantManager.currentRestaurant {
                    Section(header: Text("Restaurant").foregroundColor(AppTheme.gold)) {
                        HStack {
                            Text("Restaurant:")
                            Spacer()
                            Text(restaurant.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle Réservation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveReservation) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.gold)
                        }
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            .alert("Réservation", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("succès") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        // Only name is required
        let hasName = !customerName.trimmingCharacters(in: .whitespaces).isEmpty
        
        // If email is provided, it must be valid
        let emailValid = customerEmail.isEmpty || isValidEmail(customerEmail)
        
        return hasName && emailValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Save Reservation
    
    private func saveReservation() {
        guard isFormValid else {
            alertMessage = "Veuillez remplir tous les champs obligatoires avec des informations valides."
            showingAlert = true
            return
        }
        
        isSaving = true
        
        // Create reservation object
        // Use placeholder values if email/phone not provided
        let finalEmail = customerEmail.trimmingCharacters(in: .whitespaces).isEmpty ? "noemail@restaurant.com" : customerEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let finalPhone = customerPhone.trimmingCharacters(in: .whitespaces).isEmpty ? "0000000000" : customerPhone.trimmingCharacters(in: .whitespaces)
        
        // Normalize to noon to avoid timezone boundary issues
        let normalizedDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: reservationDate) ?? reservationDate
        
        let reservation = Reservation(
            name: customerName.trimmingCharacters(in: .whitespaces),
            email: finalEmail,
            phone: finalPhone,
            numberOfPeople: numberOfGuests,
            date: normalizedDate,
            time: reservationTime,
            specialRequests: specialRequests.isEmpty ? nil : specialRequests,
            status: .confirmed // Manual reservations are auto-confirmed
        )
        
        // Save to Firestore
        viewModel.addReservation(reservation) { success, error in
            isSaving = false
            
            if success {
                Logger.debug("✅ Manual reservation added successfully")
                alertMessage = "Réservation créée avec succès pour \(customerName) le \(formatDate(reservationDate)) à \(reservationTime)."
                showingAlert = true
                
                // Track customer only if real email/phone provided
                if !customerEmail.isEmpty || !customerPhone.isEmpty {
                    viewModel.trackCustomer(
                        email: reservation.email,
                        phone: reservation.phone,
                        name: reservation.name
                    )
                }
            } else {
                Logger.debug("❌ Failed to add manual reservation: \(error?.localizedDescription ?? "Unknown error")")
                alertMessage = "Erreur lors de la création de la réservation. Veuillez réessayer."
                showingAlert = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct AddReservationView_Previews: PreviewProvider {
    static var previews: some View {
        AddReservationView(viewModel: ReservationViewModel())
    }
}
