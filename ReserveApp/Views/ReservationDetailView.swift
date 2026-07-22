import SwiftUI

struct ReservationDetailView: View {
    let reservation: Reservation
    @ObservedObject var viewModel: ReservationViewModel
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingStatusDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var showingEditSheet = false
    @State private var isCancelling = false
    @State private var isDeleting = false
    
    enum AlertType: Identifiable {
        case delete
        case cancel
        
        var id: String {
            switch self {
            case .delete: return "delete"
            case .cancel: return "cancel"
            }
        }
    }
    @State private var activeAlert: AlertType?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    private let modifiedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        return formatter
    }()
    
    private func formatModifiedAt(_ date: Date) -> String {
        modifiedAtFormatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            ZStack {
                // Background
                AppTheme.anthracite.edgesIgnoringSafeArea(.all)
            VStack(alignment: .leading, spacing: 16) {
                // Header with status badge and no-show flag
                HStack {
                    Text("Détails de la Réservation")
                        .font(.custom("Didot", size: AppTheme.titleFontSize))
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.gold)
                    
                    Spacer()
                    
                    // Red flag for no-show
                    if reservation.status == .noShow {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    
                    StatusBadgeView(status: reservation.status)
                }
                .padding(.bottom, 8)
                
                // Customer info section with clickable contact buttons
                GroupBox(label: Label("Informations Client", systemImage: "person.fill")
                    .foregroundColor(AppTheme.gold)) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Nom", value: reservation.name)
                        
                        // Clickable email
                        HStack(alignment: .top) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.gold)
                                .frame(width: 110, alignment: .leading)
                            
                            Button(action: {
                                if let url = URL(string: "mailto:\(reservation.email)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text(reservation.email)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.cream)
                                    Image(systemName: "envelope")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.gold.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Clickable phone
                        HStack(alignment: .top) {
                            Text("Téléphone")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.gold)
                                .frame(width: 110, alignment: .leading)
                            
                            Button(action: {
                                if let url = URL(string: "tel:\(reservation.phone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text(reservation.phone)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.cream)
                                    Image(systemName: "phone")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.gold.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Customer history section
                CustomerHistoryDetailView(reservation: reservation)
                
                // Reservation details section
                GroupBox(label: Label("Détails Réservation", systemImage: "calendar")
                    .foregroundColor(AppTheme.gold)) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Date", value: dateFormatter.string(from: reservation.date))
                        DetailRow(title: "Heure", value: reservation.time)
                        DetailRow(title: "Couverts", value: "\(reservation.numberOfPeople) personnes")
                        
                        if let specialRequests = reservation.specialRequests, !specialRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Demandes Spéciales")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.cream)
                                
                                Text(specialRequests)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.darkGray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Last modification audit trail
                if let modifierName = reservation.modifiedByName, !modifierName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.caption)
                        Text("Modifié par \(modifierName)")
                            .font(.caption)
                        if let modifiedAt = reservation.modifiedAt {
                            Text("le \(formatModifiedAt(modifiedAt))")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                    .padding(.horizontal, 4)
                }
                
                // Action buttons
                GroupBox(label: Label("Actions", systemImage: "slider.horizontal.3")
                    .foregroundColor(AppTheme.gold)) {
                    VStack(spacing: 12) {
                        Button(action: {
                            showingStatusDialog = true
                        }) {
                            Label("Modifier le Statut", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GoldButtonStyle())
                        
                        Button(action: { showingEditSheet = true }) {
                            Label("Modifier la Réservation", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .foregroundColor(AppTheme.gold)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        
                        // Cancel Reservation button (for restaurant to cancel on behalf of customer)
                        if reservation.status != .cancelled && reservation.status != .noShow {
                            Button(action: {
                                activeAlert = .cancel
                            }) {
                                HStack {
                                    if isCancelling {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Label(isCancelling ? "Annulation..." : "Annuler la Réservation", systemImage: "xmark.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .disabled(isCancelling)
                        }
                        
                        // No Show button
                        if reservation.status != .noShow && reservation.status != .cancelled {
                            Button(action: {
                                updateStatus(.noShow)
                            }) {
                                Label("Marquer No-show", systemImage: "exclamationmark.triangle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                        
                        // Delete button - only for owner and manager
                        if authService.currentUser?.hasPermission(.deleteReservations) == true {
                            Button(action: {
                                print("🔴 DELETE BUTTON PRESSED - Showing confirmation alert")
                                activeAlert = .delete
                            }) {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Label(isDeleting ? "Suppression..." : "Supprimer la Réservation", systemImage: "trash")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red)
                            .cornerRadius(8)
                            .disabled(isDeleting)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            }
        }
        .navigationTitle("Réservation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Label("Modifier", systemImage: "pencil")
                        .foregroundColor(AppTheme.gold)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditReservationView(reservation: reservation, viewModel: viewModel)
        }
        .confirmationDialog("Modifier le statut", isPresented: $showingStatusDialog, titleVisibility: .visible) {
            Button("Confirmée") {
                updateStatus(.confirmed)
            }
            Button("Arrivé ✓") {
                updateStatus(.arrived)
            }
            Button("Terminée") {
                updateStatus(.completed)
            }
            Button("No-show 🚩") {
                updateStatus(.noShow)
            }
            Button("Annulée", role: .destructive) {
                updateStatus(.cancelled)
            }
            Button("Retour", role: .cancel) {}
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .delete:
                return Alert(
                    title: Text("Supprimer la Réservation"),
                    message: Text("Êtes-vous sûr de vouloir supprimer cette réservation ? Cette action est irréversible."),
                    primaryButton: .destructive(Text("Supprimer")) {
                        print("🔴 ALERT: Delete button tapped in confirmation dialog")
                        deleteReservation()
                    },
                    secondaryButton: .cancel {
                        print("ℹ️ ALERT: Delete cancelled by user")
                    }
                )
            case .cancel:
                return Alert(
                    title: Text("Annuler la Réservation"),
                    message: Text("Le client recevra un email de confirmation d'annulation. Voulez-vous continuer ?"),
                    primaryButton: .destructive(Text("Annuler")) {
                        cancelReservation()
                    },
                    secondaryButton: .cancel(Text("Retour"))
                )
            }
        }
    }
    
    private func updateStatus(_ status: ReservationStatus) {
        viewModel.updateReservationStatus(reservation: reservation, status: status)
    }
    
    private func deleteReservation() {
        print("🔴 DELETE BUTTON TAPPED - deleteReservation() called")
        print("🔴 Reservation: \(reservation.name), ID: \(reservation.id ?? "nil")")
        
        isDeleting = true
        
        guard let id = reservation.id else {
            print("❌ Reservation ID is nil - cannot delete")
            isDeleting = false
            return
        }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            print("❌ Restaurant document ID not found in UserDefaults")
            isDeleting = false
            return
        }
        
        print("✅ Starting delete for ID: \(id), Restaurant: \(restaurantId)")
        
        RestaurantService.shared.deleteReservation(reservationId: id, restaurantCode: restaurantId) { error in
            DispatchQueue.main.async {
                isDeleting = false
                
                if let error = error {
                    print("❌ DetailView: Delete failed: \(error.localizedDescription)")
                    // Could show an error alert here
                } else {
                    print("✅ DetailView: Delete successful, dismissing view")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func cancelReservation() {
        guard let reservationId = reservation.id,
              let restaurantCode = RestaurantManager.shared.restaurantCode else {
            return
        }
        
        isCancelling = true
        
        // Call the cancelReservation Cloud Function
        let baseURL = AppConfig.shared.cloudFunctionBaseURL
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/cancelReservation") else {
            isCancelling = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "reservationId": reservationId,
            "restaurantCode": restaurantCode,
            "cancelledBy": "restaurant"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isCancelling = false
                
                if let error = error {
                    print("❌ Error cancelling reservation: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ Reservation cancelled successfully")
                    // Update local status
                    updateStatus(.cancelled)
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("❌ Failed to cancel reservation")
                }
            }
        }.resume()
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.gold)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(AppTheme.cream)
            
            Spacer()
        }
    }
}
