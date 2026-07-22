import Foundation
import FirebaseFirestore

class AuditService {
    static let shared = AuditService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func log(action: AuditAction, user: RestaurantUser, details: [String: String] = [:]) {
        let entry = AuditLogEntry(
            userId: user.firebaseUid,
            userName: user.displayName,
            userEmail: user.email,
            action: action,
            details: details,
            timestamp: Date(),
            restaurantId: user.restaurantId
        )
        
        do {
            try db.collection("restaurants")
                .document(user.restaurantId)
                .collection("auditLog")
                .addDocument(from: entry) { error in
                    if let error = error {
                        print("❌ Failed to log audit entry: \(error.localizedDescription)")
                    } else {
                        print("📝 Audit logged: \(action.displayName) by \(user.displayName)")
                    }
                }
        } catch {
            print("❌ Failed to encode audit entry: \(error)")
        }
    }
    
    func getAuditLog(restaurantId: String, limit: Int = 100, completion: @escaping ([AuditLogEntry]?, Error?) -> Void) {
        db.collection("restaurants")
            .document(restaurantId)
            .collection("auditLog")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch audit log: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let entries = documents.compactMap { document -> AuditLogEntry? in
                    try? document.data(as: AuditLogEntry.self)
                }
                
                print("✅ Fetched \(entries.count) audit log entries")
                completion(entries, nil)
            }
    }
    
    func listenToAuditLog(restaurantId: String, limit: Int = 100, completion: @escaping ([AuditLogEntry]?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("restaurants")
            .document(restaurantId)
            .collection("auditLog")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Audit log listener error: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let entries = documents.compactMap { document -> AuditLogEntry? in
                    try? document.data(as: AuditLogEntry.self)
                }
                
                completion(entries, nil)
            }
    }
    
    func deleteOldLogs(restaurantId: String, olderThanDays: Int = 90, completion: @escaping (Error?) -> Void) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        db.collection("restaurants")
            .document(restaurantId)
            .collection("auditLog")
            .whereField("timestamp", isLessThan: cutoffDate)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch old logs: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(nil)
                    return
                }
                
                let batch = self.db.batch()
                documents.forEach { batch.deleteDocument($0.reference) }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ Failed to delete old logs: \(error.localizedDescription)")
                    } else {
                        print("✅ Deleted \(documents.count) old audit log entries")
                    }
                    completion(error)
                }
            }
    }
}
