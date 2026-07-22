import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class UserService {
    static let shared = UserService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Management
    
    func getUsers(restaurantId: String, completion: @escaping ([RestaurantUser]?, Error?) -> Void) {
        db.collection("restaurants")
            .document(restaurantId)
            .collection("users")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch users: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let users = documents.compactMap { document -> RestaurantUser? in
                    try? document.data(as: RestaurantUser.self)
                }
                
                print("✅ Fetched \(users.count) users")
                completion(users, nil)
            }
    }
    
    func listenToUsers(restaurantId: String, completion: @escaping ([RestaurantUser]?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("restaurants")
            .document(restaurantId)
            .collection("users")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Users listener error: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let users = documents.compactMap { document -> RestaurantUser? in
                    try? document.data(as: RestaurantUser.self)
                }
                
                completion(users, nil)
            }
    }
    
    func createUser(email: String, displayName: String, role: UserRole, restaurantId: String, createdBy: RestaurantUser, completion: @escaping (Result<RestaurantUser, Error>) -> Void) {
        guard createdBy.canManageUsers() else {
            let error = NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Insufficient permissions"])
            completion(.failure(error))
            return
        }
        
        let temporaryPassword = generateTemporaryPassword()
        
        Auth.auth().createUser(withEmail: email, password: temporaryPassword) { authResult, error in
            if let error = error {
                print("❌ Failed to create Firebase user: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                completion(.failure(error))
                return
            }
            
            let user = RestaurantUser(
                firebaseUid: firebaseUser.uid,
                email: email,
                displayName: displayName,
                role: role,
                restaurantId: restaurantId,
                createdAt: Date(),
                createdBy: createdBy.firebaseUid
            )
            
            do {
                let userRef = self.db.collection("restaurants")
                    .document(restaurantId)
                    .collection("users")
                    .document()
                
                var newUser = user
                newUser.id = userRef.documentID
                
                try userRef.setData(from: newUser) { error in
                    if let error = error {
                        print("❌ Failed to create user profile: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("✅ User created: \(newUser.displayName)")
                        
                        AuditService.shared.log(
                            action: .createUser,
                            user: createdBy,
                            details: [
                                "newUser": newUser.email,
                                "role": newUser.role.rawValue
                            ]
                        )
                        
                        Auth.auth().sendPasswordReset(withEmail: email) { _ in
                            print("📧 Password reset email sent to \(email)")
                        }
                        
                        completion(.success(newUser))
                    }
                }
            } catch {
                print("❌ Failed to encode user: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func updateUser(userId: String, restaurantId: String, updates: [String: Any], updatedBy: RestaurantUser, completion: @escaping (Error?) -> Void) {
        guard updatedBy.canManageUsers() else {
            let error = NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Insufficient permissions"])
            completion(error)
            return
        }
        
        db.collection("restaurants")
            .document(restaurantId)
            .collection("users")
            .document(userId)
            .updateData(updates) { error in
                if let error = error {
                    print("❌ Failed to update user: \(error.localizedDescription)")
                    completion(error)
                } else {
                    print("✅ User updated")
                    
                    AuditService.shared.log(
                        action: .updateUser,
                        user: updatedBy,
                        details: ["userId": userId]
                    )
                    
                    completion(nil)
                }
            }
    }
    
    func deactivateUser(userId: String, restaurantId: String, deactivatedBy: RestaurantUser, completion: @escaping (Error?) -> Void) {
        guard deactivatedBy.canManageUsers() else {
            let error = NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Insufficient permissions"])
            completion(error)
            return
        }
        
        updateUser(userId: userId, restaurantId: restaurantId, updates: ["isActive": false], updatedBy: deactivatedBy) { error in
            if error == nil {
                AuditService.shared.log(
                    action: .deleteUser,
                    user: deactivatedBy,
                    details: ["userId": userId, "action": "deactivated"]
                )
            }
            completion(error)
        }
    }
    
    func reactivateUser(userId: String, restaurantId: String, reactivatedBy: RestaurantUser, completion: @escaping (Error?) -> Void) {
        guard reactivatedBy.canManageUsers() else {
            let error = NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Insufficient permissions"])
            completion(error)
            return
        }
        
        updateUser(userId: userId, restaurantId: restaurantId, updates: ["isActive": true], updatedBy: reactivatedBy, completion: completion)
    }
    
    // MARK: - Helper Methods
    
    private func generateTemporaryPassword() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<16).map { _ in characters.randomElement()! })
    }
}
