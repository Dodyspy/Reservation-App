import SwiftUI

struct TestReservationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    
    @State private var customerName = ""
    @State private var customerEmail = ""
    @State private var customerPhone = ""
    @State private var numberOfPeople = 2
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var specialRequests = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Test Reservation")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Restaurant: \(restaurantManager.restaurantName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Form
                    VStack(spacing: 15) {
                        // Customer Info
                        Group {
                            TextField("Nom complet", text: $customerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Email", text: $customerEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            TextField("Téléphone", text: $customerPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                        
                        // Number of people
                        HStack {
                            Text("Nombre de personnes:")
                            Spacer()
                            Stepper(value: $numberOfPeople, in: 1...20) {
                                Text("\(numberOfPeople)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Date selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Date de réservation:")
                                .font(.headline)
                            
                            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                        .padding(.horizontal)
                        
                        // Time selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Heure:")
                                .font(.headline)
                            
                            DatePicker("Heure", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                        .padding(.horizontal)
                        
                        // Special requests
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Demandes spéciales (optionnel):")
                                .font(.headline)
                            
                            TextEditor(text: $specialRequests)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    
                    // Submit button
                    Button(action: createTestReservation) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Création en cours...")
                            }
                        } else {
                            Text("Créer la réservation test")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Test Reservation")
            .navigationBarItems(
                leading: Button("Annuler") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Succès", isPresented: $showSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Réservation test créée avec succès!")
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !customerName.isEmpty && 
        !customerEmail.isEmpty && 
        !customerPhone.isEmpty &&
        numberOfPeople > 0
    }
    
    private func createTestReservation() {
        guard let restaurantCode = restaurantManager.restaurantCode else {
            errorMessage = "Aucun restaurant configuré"
            showError = true
            return
        }
        
        isLoading = true
        
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var finalComponents = DateComponents()
        finalComponents.year = dateComponents.year
        finalComponents.month = dateComponents.month
        finalComponents.day = dateComponents.day
        finalComponents.hour = timeComponents.hour
        finalComponents.minute = timeComponents.minute
        
        guard let reservationDateTime = calendar.date(from: finalComponents) else {
            errorMessage = "Erreur de date invalide"
            showError = true
            isLoading = false
            return
        }
        
        // Create reservation
        let reservation = Reservation(
            name: customerName,
            email: customerEmail,
            phone: customerPhone,
            numberOfPeople: numberOfPeople,
            date: reservationDateTime,
            time: timeFormatter.string(from: reservationDateTime),
            specialRequests: specialRequests.isEmpty ? nil : specialRequests,
            status: .confirmed,
            customerId: nil
        )
        
        // Save to restaurant-specific collection
        RestaurantService.shared.createReservation(reservation, restaurantCode: restaurantCode) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Erreur lors de la création: \(error.localizedDescription)"
                    showError = true
                } else {
                    showSuccess = true
                }
            }
        }
    }
}

#Preview {
    TestReservationView()
}
