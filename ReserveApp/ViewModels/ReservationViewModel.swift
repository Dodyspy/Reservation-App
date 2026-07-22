import Foundation
import SwiftUI
import FirebaseFirestore
import Combine
import UserNotifications
import UIKit

class ReservationViewModel: ObservableObject {
    @Published var reservations: [Reservation] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var dataSourceType: String = "Unknown"
    @Published var newReservationCount: Int = 0
    @Published var newReservations: [Reservation] = []
    
    private var listener: ListenerRegistration?
    private var useFirebase: Bool
    private var lastReservationCount: Int = 0
    private var hasInitialLoad: Bool = false
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    
    init() {
        // Determine if we should use Firebase based on configuration
        switch AppConfig.shared.dataSource {
        case .firebase:
            useFirebase = AppConfig.shared.isFirebaseConfigured()
            if !useFirebase {
                Logger.debug("Warning: Firebase is configured as the data source but GoogleService-Info.plist is missing")
            }
        case .api:
            useFirebase = false
        case .both:
            useFirebase = AppConfig.shared.isFirebaseConfigured()
        }
        
        dataSourceType = useFirebase ? "Firebase" : "API"
        fetchReservations()
    }
    
    deinit {
        listener?.remove()
    }
    
    func fetchReservations() {
        guard restaurantManager.restaurantCode != nil else {
            error = "Aucun restaurant configuré"
            return
        }
        
        // Check restaurant status and show warning if closed
        if let restaurant = restaurantManager.currentRestaurant {
            if let closureMessage = restaurant.getClosureMessage() {
                Logger.debug("⚠️ Restaurant status: \(closureMessage)")
            }
        }
        
        // Get restaurant document ID from UserDefaults
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            error = "Document ID manquant. Veuillez vous reconnecter."
            Logger.debug("❌ No restaurant document ID found. User needs to reconnect.")
            return
        }
        
        Logger.debug("📡 Fetching reservations for restaurant ID: \(restaurantId)")
        
        isLoading = true
        error = nil
        
        if useFirebase {
            // Use restaurant-specific Firebase collections with document ID
            listener?.remove()
            listener = RestaurantService.shared.listenForReservations(for: restaurantId) { [weak self] reservations, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        Logger.debug("❌ Firebase listener error: \(error.localizedDescription)")
                        self?.error = "Failed to load reservations: \(error.localizedDescription)"
                        self?.fallbackToAPI()
                        return
                    }
                    
                    if let reservations = reservations {
                        Logger.debug("🔔 Listener triggered with \(reservations.count) reservations")
                        Logger.debug("📍 Listening on path: restaurants/\(restaurantId)/reservations")
                        self?.handleReservationsUpdate(reservations)
                    }
                }
            }
        } else {
            // Fallback to API
            ReservationAPIService.shared.getReservations { [weak self] reservations, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = "Failed to load reservations: \(error.localizedDescription)"
                        return
                    }
                    
                    if let reservations = reservations {
                        self?.handleReservationsUpdate(reservations)
                    }
                }
            }
        }
    }
    
    private func fallbackToAPI() {
        useFirebase = false
        fetchReservations()
    }
    
    func updateReservationStatus(reservation: Reservation, status: ReservationStatus) {
        guard let id = reservation.id,
              restaurantManager.restaurantCode != nil,
              let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else { return }
        
        if useFirebase {
            // Use restaurant-specific update with document ID
            RestaurantService.shared.updateReservationStatus(reservationId: id, status: status, restaurantCode: restaurantId) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.error = "Failed to update reservation: \(error.localizedDescription)"
                    }
                } else {
                    DispatchQueue.main.async {
                        Logger.debug("Reservation status updated successfully to: \(status.rawValue)")
                    }
                    // Increment no_show_count on the customer document
                    if status == .noShow {
                        self?.incrementCustomerNoShow(email: reservation.email, restaurantId: restaurantId, reservationDate: reservation.date)
                    }
                }
            }
        } else {
            ReservationAPIService.shared.updateReservationStatus(reservation: reservation, status: status) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.error = "Failed to update reservation: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func deleteReservation(reservation: Reservation) {
        Logger.debug("🗑️ ViewModel: deleteReservation called for: \(reservation.name)")
        
        guard let id = reservation.id else {
            Logger.debug("❌ ViewModel: Reservation ID is nil")
            return
        }
        
        guard restaurantManager.restaurantCode != nil else {
            Logger.debug("❌ ViewModel: Restaurant code is nil")
            return
        }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            Logger.debug("❌ ViewModel: Restaurant document ID is nil")
            return
        }
        
        Logger.debug("✅ ViewModel: All required data present - ID: \(id), RestaurantId: \(restaurantId)")
        Logger.debug("🔄 ViewModel: useFirebase = \(useFirebase)")
        
        if useFirebase {
            RestaurantService.shared.deleteReservation(reservationId: id, restaurantCode: restaurantId) { [weak self] error in
                if let error = error {
                    Logger.debug("❌ ViewModel: Delete failed with error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.error = "Failed to delete reservation: \(error.localizedDescription)"
                    }
                } else {
                    Logger.debug("✅ ViewModel: Delete completed successfully")
                }
            }
        } else {
            ReservationAPIService.shared.deleteReservation(reservationId: id) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.error = "Failed to delete reservation: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func getReservationsForDate(_ date: Date) -> [Reservation] {
        let calendar = Calendar.current
        return reservations.filter { reservation in
            calendar.isDate(reservation.date, inSameDayAs: date)
        }
    }
    
    // MARK: - Notification System
    
    private func handleReservationsUpdate(_ newReservations: [Reservation]) {
        let previousCount = reservations.count
        Logger.debug("🔄 handleReservationsUpdate called - Previous: \(previousCount), New: \(newReservations.count)")
        Logger.debug("🔄 hasInitialLoad: \(hasInitialLoad)")
        reservations = newReservations
        
        // Only trigger notifications after initial load
        if hasInitialLoad {
            let currentCount = newReservations.count
            
            // Check for new reservations
            if currentCount > previousCount {
                let newCount = currentCount - previousCount
                newReservationCount += newCount
                
                // Find the new reservations (most recent ones)
                let sortedReservations = newReservations.sorted { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast }
                let newReservationsArray = Array(sortedReservations.prefix(newCount))
                
                // Add new reservations to the notifications list
                self.newReservations.append(contentsOf: newReservationsArray)
                
                // NOTE: Local notifications disabled - using Firebase push notifications instead
                // Push notifications are sent by the Cloud Function when reservation is created
                
                // Update app badge
                updateAppBadge()
            }
        } else {
            // Mark initial load as complete
            hasInitialLoad = true
        }
    }
    
    // DISABLED: Local notifications - using Firebase push notifications instead
    // This function is no longer needed as push notifications are sent by Cloud Function
    /*
    private func triggerNewReservationNotification(_ reservation: Reservation) {
        let content = UNMutableNotificationContent()
        content.title = "Nouvelle Réservation"
        content.body = "\(reservation.name) - \(formatReservationDate(reservation.date)) à \(reservation.time)"
        content.sound = .default
        content.badge = NSNumber(value: newReservationCount)
        
        // Create a unique identifier for this notification
        let identifier = "new_reservation_\(reservation.id ?? UUID().uuidString)"
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.debug("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                Logger.debug("Notification scheduled for new reservation: \(reservation.name)")
            }
        }
    }
    */
    
    private func updateAppBadge() {
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(self.newReservationCount) { error in
                    if let error = error {
                        Logger.debug("Failed to set badge count: \(error.localizedDescription)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = self.newReservationCount
            }
        }
    }
    
    private func formatReservationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    func markNotificationsAsRead() {
        newReservationCount = 0
        newReservations.removeAll()
        updateAppBadge()
        
        // Remove all delivered notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func markNotificationAsRead(for reservationId: String) {
        // Remove the specific reservation from new reservations
        newReservations.removeAll { $0.id == reservationId }
        newReservationCount = newReservations.count
        updateAppBadge()
        
        // Remove specific notification if possible
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reservationId])
    }
    
    func markAllNotificationsAsRead() {
        markNotificationsAsRead()
    }
    
    func clearData() {
        // Stop listening to Firebase updates
        listener?.remove()
        listener = nil
        
        // Clear all cached data
        reservations.removeAll()
        newReservations.removeAll()
        error = nil
        isLoading = false
        newReservationCount = 0
        updateAppBadge()
        
        Logger.debug("🧹 Cleared all cached reservation data")
    }
    
    // MARK: - Add Reservation
    
    func addReservation(_ reservation: Reservation, completion: @escaping (Bool, Error?) -> Void) {
        guard restaurantManager.restaurantCode != nil else {
            completion(false, NSError(domain: "ReservationViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No restaurant configured"]))
            return
        }
        
        // Check if restaurant can accept reservations
        guard let restaurant = restaurantManager.currentRestaurant else {
            completion(false, NSError(domain: "ReservationViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Restaurant data not loaded"]))
            return
        }
        
        // Validate restaurant status
        if !restaurant.canAcceptReservations {
            let message = restaurant.getClosureMessage() ?? "Restaurant cannot accept reservations"
            completion(false, NSError(domain: "ReservationViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            return
        }
        
        // Get restaurant document ID from UserDefaults (same as fetchReservations)
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            completion(false, NSError(domain: "ReservationViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document ID manquant. Veuillez vous reconnecter."]))
            Logger.debug("❌ No restaurant document ID found for adding reservation. User needs to reconnect.")
            return
        }
        
        let db = Firestore.firestore()
        let reservationsRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("reservations")
        
        Logger.debug("📝 Adding reservation to path: restaurants/\(restaurantId)/reservations")
        Logger.debug("📝 Reservation details: \(reservation.name) on \(reservation.date) at \(reservation.time)")
        
        // Format date for Firestore
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Paris")
        dateFormatter.locale = Locale(identifier: "fr_FR")
        let dateString = dateFormatter.string(from: reservation.date)
        
        // Use noon to avoid timezone boundary issues (same as decoder)
        let noonDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: reservation.date) ?? reservation.date
        
        // Create Firestore document data
        let data: [String: Any] = [
            "name": reservation.name,
            "email": reservation.email,
            "phone": reservation.phone,
            "guests": reservation.numberOfPeople,
            "date": dateString,
            "dateTimestamp": Timestamp(date: noonDate),
            "time": reservation.time,
            "notes": reservation.specialRequests ?? "Aucune note",
            "status": reservation.status.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "customerId": reservation.customerId as Any
        ]
        
        // Add to Firestore
        reservationsRef.addDocument(data: data) { [weak self] error in
            if let error = error {
                Logger.debug("❌ Error adding reservation to Firestore: \(error.localizedDescription)")
                completion(false, error)
            } else {
                Logger.debug("✅ Reservation added successfully to Firestore")
                Logger.debug("📊 Current reservation count before listener update: \(self?.reservations.count ?? 0)")
                Logger.debug("🔔 Listener should trigger automatically with new data...")
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Update Reservation
    
    func updateReservation(original: Reservation, updated: Reservation, completion: @escaping (Bool, Error?) -> Void) {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"),
              !restaurantId.isEmpty else {
            completion(false, NSError(domain: "ReservationViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Données manquantes pour la mise à jour."]))
            return
        }
        
        let currentUser = AuthenticationService.shared.currentUser
        
        if useFirebase {
            RestaurantService.shared.updateReservation(
                original: original,
                updated: updated,
                restaurantCode: restaurantId,
                modifiedBy: currentUser
            ) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.debug("❌ Failed to update reservation: \(error.localizedDescription)")
                        completion(false, error)
                    } else {
                        Logger.debug("✅ Reservation updated successfully: \(updated.id ?? "unknown")")
                        completion(true, nil)
                    }
                }
            }
        } else {
            ReservationAPIService.shared.updateReservation(
                updated,
                modifiedBy: currentUser
            ) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.debug("❌ Failed to update reservation via API: \(error.localizedDescription)")
                        completion(false, error)
                    } else {
                        Logger.debug("✅ Reservation updated via API: \(updated.id ?? "unknown")")
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Customer Tracking
    
    func trackCustomer(email: String, phone: String, name: String) {
        guard restaurantManager.restaurantCode != nil else {
            Logger.debug("❌ Cannot track customer: No restaurant configured")
            return
        }
        
        // Get restaurant document ID from UserDefaults (same as addReservation)
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            Logger.debug("❌ No restaurant document ID found for tracking customer. User needs to reconnect.")
            return
        }
        
        let db = Firestore.firestore()
        let customersRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("customers")
        
        // Query for existing customer by email
        customersRef.whereField("primary_email", isEqualTo: email).getDocuments { snapshot, error in
            if let error = error {
                Logger.debug("❌ Error checking for existing customer: \(error.localizedDescription)")
                return
            }
            
            if let existingCustomer = snapshot?.documents.first {
                // Update existing customer
                let customerRef = existingCustomer.reference
                customerRef.updateData([
                    "total_reservations": FieldValue.increment(Int64(1)),
                    "updated_at": FieldValue.serverTimestamp(),
                    "primary_name": name
                ]) { error in
                    if let error = error {
                        Logger.debug("❌ Error updating customer: \(error.localizedDescription)")
                    } else {
                        Logger.debug("✅ Updated existing customer: \(email)")
                    }
                }
            } else {
                // Create new customer
                let customerData: [String: Any] = [
                    "primary_email": email,
                    "primary_phone": phone,
                    "primary_name": name,
                    "total_reservations": 1,
                    "no_show_count": 0,
                    "created_at": FieldValue.serverTimestamp(),
                    "updated_at": FieldValue.serverTimestamp()
                ]
                
                customersRef.addDocument(data: customerData) { error in
                    if let error = error {
                        Logger.debug("❌ Error creating customer: \(error.localizedDescription)")
                    } else {
                        Logger.debug("✅ Created new customer: \(email)")
                    }
                }
            }
        }
    }
    
    // MARK: - No-Show Tracking
    
    private func incrementCustomerNoShow(email: String, restaurantId: String, reservationDate: Date) {
        let db = Firestore.firestore()
        let customersRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("customers")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Paris")
        dateFormatter.locale = Locale(identifier: "fr_FR")
        let dateString = dateFormatter.string(from: reservationDate)
        
        customersRef.whereField("primary_email", isEqualTo: email).getDocuments { snapshot, error in
            if let error = error {
                Logger.debug("❌ Error finding customer for no-show increment: \(error.localizedDescription)")
                return
            }
            
            if let existingCustomer = snapshot?.documents.first {
                existingCustomer.reference.updateData([
                    "no_show_count": FieldValue.increment(Int64(1)),
                    "last_no_show_date": dateString,
                    "updated_at": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        Logger.debug("❌ Error incrementing no_show_count: \(error.localizedDescription)")
                    } else {
                        Logger.debug("✅ Incremented no_show_count for customer: \(email)")
                    }
                }
            } else {
                Logger.debug("⚠️ No customer document found for email: \(email) — no_show_count not updated")
            }
        }
    }
}
