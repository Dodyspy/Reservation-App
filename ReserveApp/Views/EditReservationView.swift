import SwiftUI

struct EditReservationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ReservationViewModel
    let reservation: Reservation

    // Form fields — pre-filled from existing reservation
    @State private var customerName: String
    @State private var customerEmail: String
    @State private var customerPhone: String
    @State private var numberOfGuests: Int
    @State private var reservationDate: Date
    @State private var reservationTime: String
    @State private var specialRequests: String

    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false

    private let timeSlots = [
        "12:00", "12:30", "13:00", "13:30", "14:00", "14:30",
        "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00"
    ]

    init(reservation: Reservation, viewModel: ReservationViewModel) {
        self.reservation = reservation
        self.viewModel = viewModel
        _customerName    = State(initialValue: reservation.name)
        _customerEmail   = State(initialValue: reservation.email == "noemail@restaurant.com" ? "" : reservation.email)
        _customerPhone   = State(initialValue: reservation.phone == "0000000000" ? "" : reservation.phone)
        _numberOfGuests  = State(initialValue: reservation.numberOfPeople)
        _reservationDate = State(initialValue: reservation.date)
        _reservationTime = State(initialValue: reservation.time)
        _specialRequests = State(initialValue: reservation.specialRequests ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
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

                Section(header: Text("Détails de la Réservation").foregroundColor(AppTheme.gold)) {
                    DatePicker("Date", selection: $reservationDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    Picker("Heure", selection: $reservationTime) {
                        ForEach(timeSlots, id: \.self) { time in
                            Text(time).tag(time)
                        }
                    }

                    Stepper("Nombre de convives: \(numberOfGuests)", value: $numberOfGuests, in: 1...20)
                }

                Section(header: Text("Demandes Spéciales").foregroundColor(AppTheme.gold)) {
                    TextEditor(text: $specialRequests)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }

                Section(header: Text("Statut actuel").foregroundColor(AppTheme.gold)) {
                    HStack {
                        Text("Statut")
                        Spacer()
                        StatusBadgeView(status: reservation.status)
                    }
                    Text("Le statut ne peut pas être modifié ici — utilisez les boutons d'action.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Modifier la Réservation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveChanges) {
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
            .alert("Modification", isPresented: $showingAlert) {
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
        let hasName = !customerName.trimmingCharacters(in: .whitespaces).isEmpty
        let emailValid = customerEmail.isEmpty || isValidEmail(customerEmail)
        return hasName && emailValid
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    // MARK: - Save

    private func saveChanges() {
        guard isFormValid else {
            alertMessage = "Veuillez remplir tous les champs obligatoires."
            showingAlert = true
            return
        }

        isSaving = true

        let finalEmail = customerEmail.trimmingCharacters(in: .whitespaces).isEmpty
            ? "noemail@restaurant.com"
            : customerEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let finalPhone = customerPhone.trimmingCharacters(in: .whitespaces).isEmpty
            ? "0000000000"
            : customerPhone.trimmingCharacters(in: .whitespaces)

        let noonDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: reservationDate) ?? reservationDate

        var updated = Reservation(
            name: customerName.trimmingCharacters(in: .whitespaces),
            email: finalEmail,
            phone: finalPhone,
            numberOfPeople: numberOfGuests,
            date: noonDate,
            time: reservationTime,
            specialRequests: specialRequests.isEmpty ? nil : specialRequests,
            status: reservation.status,
            customerId: reservation.customerId
        )
        // Preserve the existing Firestore document ID so updateReservation targets the right doc
        updated.id = reservation.id

        viewModel.updateReservation(original: reservation, updated: updated) { success, error in
            isSaving = false
            if success {
                alertMessage = "Réservation modifiée avec succès."
            } else {
                alertMessage = "Erreur lors de la modification : \(error?.localizedDescription ?? "inconnue")"
            }
            showingAlert = true
        }
    }
}

struct EditReservationView_Previews: PreviewProvider {
    static var previews: some View {
        EditReservationView(
            reservation: Reservation(
                name: "Jean Dupont",
                email: "jean@test.com",
                phone: "0600000000",
                numberOfPeople: 2,
                date: Date(),
                time: "20:00",
                status: .confirmed
            ),
            viewModel: ReservationViewModel()
        )
    }
}
