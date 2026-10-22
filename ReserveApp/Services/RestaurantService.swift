import Foundation
import Firebase
import FirebaseFirestore

class RestaurantService {
    static let shared = RestaurantService()
    
    private let db = Firestore.firestore()
    private let restaurantsCollection = "restaurants"
    
    private init() {}
    
    // MARK: - Restaurant Management
    
    func getRestaurantByCode(_ code: String, completion: @escaping (Restaurant?, String?, Error?) -> Void) {
        Logger.debug("🔍 Looking up restaurant with code: \(code)")
        
        db.collection(restaurantsCollection)
            .whereField("code", isEqualTo: code.uppercased())
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.debug("❌ Error fetching restaurant: \(error.localizedDescription)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    Logger.debug("❌ No restaurant found with code: \(code)")
                    let notFoundError = NSError(
                        domain: "RestaurantService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Code restaurant invalide. Vérifiez le code et réessayez."]
                    )
                    completion(nil, nil, notFoundError)
                    return
                }
                
                do {
                    let restaurant = try document.data(as: Restaurant.self)
                    let documentId = document.documentID
                    Logger.debug("✅ Found restaurant: \(restaurant.name)")
                    Logger.debug("📄 Document ID: \(documentId)")
                    completion(restaurant, documentId, nil)
                } catch {
                    Logger.debug("❌ Error decoding restaurant: \(error)")
                    completion(nil, nil, error)
                }
            }
    }
    
    func getRestaurantById(_ documentId: String, completion: @escaping (Restaurant?, Error?) -> Void) {
        Logger.debug("🔍 Looking up restaurant by document ID: \(documentId)")
        
        db.collection(restaurantsCollection)
            .document(documentId)
            .getDocument { snapshot, error in
                if let error = error {
                    Logger.debug("❌ Error fetching restaurant by ID: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    Logger.debug("❌ No restaurant found with ID: \(documentId)")
                    let notFoundError = NSError(
                        domain: "RestaurantService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Restaurant non trouvé."]
                    )
                    completion(nil, notFoundError)
                    return
                }
                
                do {
                    let restaurant = try snapshot.data(as: Restaurant.self)
                    Logger.debug("✅ Found restaurant by ID: \(restaurant.name)")
                    completion(restaurant, nil)
                } catch {
                    Logger.debug("❌ Error decoding restaurant: \(error)")
                    completion(nil, error)
                }
            }
    }
    
    // MARK: - Real-time Restaurant Settings Listener
    
    func listenToRestaurantSettings(restaurantId: String, completion: @escaping (Restaurant?, Error?) -> Void) -> ListenerRegistration {
        Logger.debug("🎧 Setting up real-time listener for restaurant settings: \(restaurantId)")
        
        return db.collection(restaurantsCollection)
            .document(restaurantId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.debug("❌ Restaurant settings listener error: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    Logger.debug("⚠️ Restaurant document no longer exists")
                    let notFoundError = NSError(
                        domain: "RestaurantService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Restaurant not found"]
                    )
                    completion(nil, notFoundError)
                    return
                }
                
                do {
                    let restaurant = try snapshot.data(as: Restaurant.self)
                    Logger.debug("✅ Restaurant settings updated: \(restaurant.name)")
                    Logger.debug("📊 Status - Closed: \(restaurant.isTemporarilyClosed), Full: \(restaurant.isRestaurantFull)")
                    completion(restaurant, nil)
                } catch {
                    Logger.debug("❌ Error decoding restaurant settings: \(error)")
                    completion(nil, error)
                }
            }
    }
    
    func createRestaurant(_ restaurant: Restaurant, completion: @escaping (String?, Error?) -> Void) {
        do {
            let documentRef = try db.collection(restaurantsCollection).addDocument(from: restaurant)
            documentRef.getDocument { _, error in
                if let error = error {
                    Logger.debug("❌ Error creating restaurant: \(error.localizedDescription)")
                    completion(nil, error)
                } else {
                    Logger.debug("✅ Restaurant created successfully")
                    completion(documentRef.documentID, nil)
                }
            }
        } catch {
            Logger.debug("❌ Error encoding restaurant: \(error)")
            completion(nil, error)
        }
    }
    
    func updateRestaurant(_ restaurant: Restaurant, completion: @escaping (Error?) -> Void) {
        guard let restaurantId = restaurant.id else {
            completion(NSError(domain: "RestaurantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Restaurant ID is missing"]))
            return
        }
        
        do {
            try db.collection(restaurantsCollection).document(restaurantId).setData(from: restaurant) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Multi-Tenant Data Access
    
    func getReservationsCollection(for restaurantId: String) -> CollectionReference {
        return db.collection("restaurants")
                 .document(restaurantId)
                 .collection("reservations")
    }
    
    func getCustomersCollection(for restaurantId: String) -> CollectionReference {
        return db.collection("restaurants")
                 .document(restaurantId)
                 .collection("customers")
    }
    
    func getDeviceTokensCollection(for restaurantId: String) -> CollectionReference {
        return db.collection("restaurants")
                 .document(restaurantId)
                 .collection("deviceTokens")
    }
    
    // MARK: - Sample Restaurant Creation (for testing)
    
    func createCasanovaRestaurant(completion: @escaping (String?, Error?) -> Void) {
        let casanova = Restaurant(
            code: "CASANOVA2024",
            name: "Casanova d'Issy",
            displayName: "Casanova d'Issy",
            website: "https://www.casanovadissy.fr",
            email: "contact@casanovadissy.fr",
            phone: "01 46 42 43 44",
            address: "1 Avenue Victor Cresson, 92130 Issy-les-Moulineaux",
            branding: RestaurantBranding.casanovaDefault,
            fcmTopic: "casanova-dissy-reservations",
            isActive: true,
            subscriptionTier: .premium
        )
        
        createRestaurant(casanova, completion: completion)
    }
    
    // MARK: - Reservation Management
    
    func getReservations(for restaurantCode: String, completion: @escaping ([Reservation]?, Error?) -> Void) {
        let collection = getReservationsCollection(for: restaurantCode)
        
        collection
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let reservations = documents.compactMap { document -> Reservation? in
                    try? document.data(as: Reservation.self)
                }
                
                completion(reservations, nil)
            }
    }
    
    func listenForReservations(for restaurantCode: String, completion: @escaping ([Reservation]?, Error?) -> Void) -> ListenerRegistration {
        let collection = getReservationsCollection(for: restaurantCode)
        
        Logger.debug("🎧 Setting up listener on path: restaurants/\(restaurantCode)/reservations")
        
        return collection
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.debug("❌ Listener error: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Logger.debug("⚠️ Listener received empty snapshot")
                    completion([], nil)
                    return
                }
                
                Logger.debug("📦 Listener received \(documents.count) documents from Firestore")
                
                let reservations = documents.compactMap { document -> Reservation? in
                    do {
                        let reservation = try document.data(as: Reservation.self)
                        Logger.debug("✅ Parsed reservation: \(reservation.name) - \(reservation.date)")
                        return reservation
                    } catch {
                        Logger.debug("❌ Failed to parse reservation document \(document.documentID): \(error)")
                        return nil
                    }
                }
                
                Logger.debug("🎯 Returning \(reservations.count) parsed reservations to listener callback")
                completion(reservations, nil)
            }
    }
    
    func updateReservationStatus(reservationId: String, status: ReservationStatus, restaurantCode: String, completion: @escaping (Error?) -> Void) {
        let collection = getReservationsCollection(for: restaurantCode)
        
        var updateData: [String: Any] = ["status": status.rawValue]
        
        // Add timestamps based on status
        if status == .arrived {
            updateData["arrivedAt"] = FieldValue.serverTimestamp()
        } else if status == .completed {
            updateData["finishedAt"] = FieldValue.serverTimestamp()
            
            // Trigger Cloud Function to recalculate availability
            triggerAvailabilityRecalculation(restaurantCode: restaurantCode, reservationId: reservationId)
        } else if status == .noShow {
            // No-show also frees up the reserved seats
            triggerAvailabilityRecalculation(restaurantCode: restaurantCode, reservationId: reservationId)
        }
        
        collection
            .document(reservationId)
            .updateData(updateData) { error in
                completion(error)
            }
    }
    
    private func triggerAvailabilityRecalculation(restaurantCode: String, reservationId: String) {
        // Call Cloud Function to recalculate availability when reservation is finished
        let baseURL = AppConfig.shared.cloudFunctionBaseURL
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/recalculateAvailability") else {
            Logger.debug("⚠️ Invalid Cloud Function base URL in Config.plist")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "restaurantCode": restaurantCode,
            "reservationId": reservationId
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.debug("⚠️ Failed to trigger availability recalculation: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Availability recalculation triggered")
            }
        }.resume()
    }
    
    func deleteReservation(reservationId: String, restaurantCode: String, completion: @escaping (Error?) -> Void) {
        let collection = getReservationsCollection(for: restaurantCode)
        
        Logger.debug("🗑️ Attempting to delete reservation: \(reservationId)")
        Logger.debug("📍 Delete path: restaurants/\(restaurantCode)/reservations/\(reservationId)")
        
        collection
            .document(reservationId)
            .delete { error in
                if let error = error {
                    Logger.debug("❌ Failed to delete reservation: \(error.localizedDescription)")
                } else {
                    Logger.debug("✅ Successfully deleted reservation: \(reservationId)")
                }
                completion(error)
            }
    }
    
    func createReservation(_ reservation: Reservation, restaurantCode: String, completion: @escaping (Error?) -> Void) {
        let collection = getReservationsCollection(for: restaurantCode)
        
        do {
            try collection.addDocument(from: reservation) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    func updateReservation(
        original: Reservation,
        updated: Reservation,
        restaurantCode: String,
        modifiedBy: RestaurantUser? = nil,
        completion: @escaping (Error?) -> Void
    ) {
        guard let reservationId = updated.id else {
            completion(NSError(domain: "RestaurantService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing reservation ID"]))
            return
        }
        
        let collection = getReservationsCollection(for: restaurantCode)
        let documentRef = collection.document(reservationId)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Paris")
        dateFormatter.locale = Locale(identifier: "fr_FR")
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        isoFormatter.timeZone = TimeZone(identifier: "Europe/Paris")
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let noonDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: updated.date) ?? updated.date
        
        var updatedFields: [String: Any] = [
            "name": updated.name,
            "email": updated.email,
            "phone": updated.phone,
            "guests": updated.numberOfPeople,
            "date": isoFormatter.string(from: updated.date),
            "dateISO": isoFormatter.string(from: updated.date),
            "dateTimestamp": Timestamp(date: noonDate),
            "time": updated.time,
            "notes": updated.specialRequests ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let customerId = updated.customerId {
            updatedFields["customerId"] = customerId
        }
        if let modifier = modifiedBy {
            updatedFields["modifiedBy"] = modifier.firebaseUid
            updatedFields["modifiedByName"] = modifier.displayName
            updatedFields["modifiedByEmail"] = modifier.email
            updatedFields["modifiedAt"] = FieldValue.serverTimestamp()
        }
        
        documentRef.updateData(updatedFields) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // Keep availability counters in sync when date/time/guests change.
            // The recalculateAvailability Cloud Function uses the reservation's
            // current date, so this recalculates the new date/time slot.
            let detailsChanged = !Calendar.current.isDate(original.date, inSameDayAs: updated.date)
                || original.time != updated.time
                || original.numberOfPeople != updated.numberOfPeople
            
            if detailsChanged {
                self?.triggerAvailabilityRecalculation(restaurantCode: restaurantCode, reservationId: reservationId)
            }
            
            // Audit trail: who changed what
            if let modifier = modifiedBy {
                var auditDetails: [String: String] = [
                    "reservationId": reservationId,
                    "customerName": updated.name,
                    "guests": "\(updated.numberOfPeople)"
                ]
                if !Calendar.current.isDate(original.date, inSameDayAs: updated.date) {
                    auditDetails["oldDate"] = dateFormatter.string(from: original.date)
                    auditDetails["newDate"] = dateFormatter.string(from: updated.date)
                }
                if original.time != updated.time {
                    auditDetails["oldTime"] = original.time
                    auditDetails["newTime"] = updated.time
                }
                if original.numberOfPeople != updated.numberOfPeople {
                    auditDetails["oldGuests"] = "\(original.numberOfPeople)"
                    auditDetails["newGuests"] = "\(updated.numberOfPeople)"
                }
                if original.name != updated.name {
                    auditDetails["oldName"] = original.name
                    auditDetails["newName"] = updated.name
                }
                
                AuditService.shared.log(
                    action: .updateReservation,
                    user: modifier,
                    details: auditDetails
                )
            }
            
            completion(nil)
        }
    }
    
    func getCustomerHistory(email: String, phone: String, restaurantCode: String, completion: @escaping (CustomerHistory) -> Void) {
        let collection = RestaurantService.shared.getCustomersCollection(for: restaurantCode)
        
        // First try to find by email
        collection
            .whereField("primary_email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.debug("❌ Firestore query error: \(error)")
                }
                
                if let customer = snapshot?.documents.first {
                    do {
                        let customerData = try customer.data(as: Customer.self)
                        completion(CustomerHistory(customer: customerData))
                        return
                    } catch {
                        Logger.debug("❌ Error decoding customer by email: \(error)")
                    }
                }
                
                // If not found by email, try by phone
                collection
                    .whereField("primary_phone", isEqualTo: phone)
                    .limit(to: 1)
                    .getDocuments { snapshot, error in
                        if let customer = snapshot?.documents.first {
                            do {
                                let customerData = try customer.data(as: Customer.self)
                                completion(CustomerHistory(customer: customerData))
                                return
                            } catch {
                                Logger.debug("❌ Error decoding customer by phone: \(error)")
                            }
                        }
                        
                        // Customer not found - return new customer history
                        completion(CustomerHistory(customer: nil))
                    }
            }
    }
    
    // MARK: - Per-Date Service Status Management
    
    func getServiceStatus(
        restaurantId: String,
        date: String, // "YYYY-MM-DD"
        service: ServiceType,
        completion: @escaping (ServiceStatus?, Error?) -> Void
    ) {
        db.collection(restaurantsCollection)
            .document(restaurantId)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let closedServices = data["closedServices"] as? [String: [String: [String: Any]]],
                      let dateServices = closedServices[date],
                      let serviceData = dateServices[service.rawValue] else {
                    // No closure data for this date/service - default to open
                    completion(ServiceStatus(isClosed: false), nil)
                    return
                }
                
                let isClosed = serviceData["isClosed"] as? Bool ?? false
                let reason = serviceData["reason"] as? String
                
                completion(ServiceStatus(isClosed: isClosed, reason: reason), nil)
            }
    }
    
    func toggleServiceStatus(
        restaurantId: String,
        date: String, // "YYYY-MM-DD"
        service: ServiceType,
        reason: String = "",
        completion: @escaping (Bool, Error?) -> Void // Returns new status (true = closed)
    ) {
        // First, get current status
        getServiceStatus(restaurantId: restaurantId, date: date, service: service) { currentStatus, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            let newStatus = !(currentStatus?.isClosed ?? false)
            
            let fieldPath = "closedServices.\(date).\(service.rawValue)"
            let updates: [String: Any] = [
                "\(fieldPath).isClosed": newStatus,
                "\(fieldPath).reason": reason
            ]
            
            self.db.collection(self.restaurantsCollection)
                .document(restaurantId)
                .updateData(updates) { error in
                    if let error = error {
                        Logger.debug("❌ Failed to toggle \(service.displayName) for \(date): \(error.localizedDescription)")
                        completion(false, error)
                    } else {
                        Logger.debug("✅ \(service.displayName) for \(date) set to: \(newStatus ? "closed" : "open")")
                        completion(newStatus, nil)
                    }
                }
        }
    }
    
    func updateServiceStatus(
        restaurantId: String,
        date: String,
        service: ServiceType,
        isClosed: Bool,
        reason: String = "",
        completion: @escaping (Error?) -> Void
    ) {
        let fieldPath = "closedServices.\(date).\(service.rawValue)"
        let updates: [String: Any] = [
            "\(fieldPath).isClosed": isClosed,
            "\(fieldPath).reason": reason
        ]
        
        db.collection(restaurantsCollection)
            .document(restaurantId)
            .updateData(updates) { error in
                if let error = error {
                    Logger.debug("❌ Failed to update \(service.displayName) for \(date): \(error.localizedDescription)")
                } else {
                    Logger.debug("✅ \(service.displayName) for \(date) set to: \(isClosed ? "closed" : "open")")
                }
                completion(error)
            }
    }
    
}
