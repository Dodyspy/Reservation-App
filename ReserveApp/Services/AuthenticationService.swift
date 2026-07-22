import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: RestaurantUser?
    @Published var isAuthenticated = false
    @Published var authenticationMode: AuthMode = .anonymous
    
    private let db = Firestore.firestore()
    private var authStateListener: NSObjectProtocol?
    
    enum AuthMode {
        case anonymous
        case emailPassword
    }
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            if let user = user {
                if user.isAnonymous {
                    self.authenticationMode = .anonymous
                    self.isAuthenticated = true
                    print("✅ Anonymous user authenticated")
                } else {
                    self.authenticationMode = .emailPassword
                    self.loadUserProfile(firebaseUid: user.uid) { result in
                        switch result {
                        case .success:
                            print("✅ User profile loaded from auth state listener")
                        case .failure(let error):
                            print("❌ Failed to load user profile from auth state listener: \(error.localizedDescription)")
                            // If user profile can't be loaded, show error state so user isn't stuck
                            DispatchQueue.main.async {
                                RestaurantManager.shared.setLoadingFailed(true)
                            }
                        }
                    }
                }
            } else {
                self.isAuthenticated = false
                self.currentUser = nil
                self.authenticationMode = .anonymous
                print("⚠️ No user authenticated")
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String, completion: @escaping (Result<RestaurantUser, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                print("❌ Sign in failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                completion(.failure(error))
                return
            }
            
            // Check email verification (required by backoffice signup flow)
            if !firebaseUser.isEmailVerified {
                print("⚠️ Email not verified for: \(firebaseUser.email ?? "unknown")")
                try? Auth.auth().signOut()
                let error = NSError(domain: "AuthenticationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Veuillez vérifier votre email avant de vous connecter. Consultez votre boîte de réception."])
                completion(.failure(error))
                return
            }
            
            print("✅ Firebase sign in successful: \(firebaseUser.uid)")
            self?.loadUserProfile(firebaseUid: firebaseUser.uid) { result in
                switch result {
                case .success(let user):
                    self?.logAudit(action: .login, user: user)
                    completion(.success(user))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func createAccount(email: String, password: String, displayName: String, restaurantId: String, completion: @escaping (Result<RestaurantUser, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                print("❌ Account creation failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                completion(.failure(error))
                return
            }
            
            print("✅ Firebase account created: \(firebaseUser.uid)")
            
            // Create user profile in Firestore
            let user = RestaurantUser(
                firebaseUid: firebaseUser.uid,
                email: email,
                displayName: displayName,
                role: .owner,
                restaurantId: restaurantId,
                createdAt: Date()
            )
            
            self?.createUserProfile(user: user, completion: completion)
        }
    }
    
    func signOut(completion: @escaping (Error?) -> Void) {
        if let user = currentUser {
            logAudit(action: .logout, user: user)
        }
        
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.authenticationMode = .anonymous
            print("✅ User signed out")
            completion(nil)
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("❌ Password reset failed: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Password reset email sent")
                completion(nil)
            }
        }
    }
    
    // MARK: - User Profile Management
    
    private func loadUserProfile(firebaseUid: String, completion: ((Result<RestaurantUser, Error>) -> Void)? = nil) {
        let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") ?? ""
        
        // Step 1: Check top-level 'users/' collection (backoffice-created users)
        print("🔍 Looking for user in top-level users/ collection: \(firebaseUid)")
        db.collection("users")
            .document(firebaseUid)
            .getDocument { [weak self] document, error in
                if let document = document, document.exists, let data = document.data() {
                    print("✅ Found user in top-level users/ collection")
                    print("📋 User document fields: \(data.keys.sorted())")
                    
                    // Map backoffice user format to RestaurantUser
                    let role = self?.mapBackofficeRole(data["role"] as? String ?? "staff") ?? .staff
                    var userRestaurantId = data["restaurantId"] as? String ?? restaurantId
                    let userRestaurantCode = data["restaurantCode"] as? String ?? ""
                    
                    // For platform_owner: restaurantId may be empty, try restaurants array
                    if userRestaurantId.isEmpty {
                        if let restaurants = data["restaurants"] as? [String],
                           let firstRestaurant = restaurants.first,
                           firstRestaurant != "*" {
                            userRestaurantId = firstRestaurant
                            print("📋 Using first restaurant from array: \(userRestaurantId)")
                        }
                    }
                    
                    print("📋 restaurantId: '\(userRestaurantId)', restaurantCode: '\(userRestaurantCode)', role: \(data["role"] as? String ?? "unknown")")
                    
                    let user = RestaurantUser(
                        id: document.documentID,
                        firebaseUid: firebaseUid,
                        email: data["email"] as? String ?? "",
                        displayName: data["name"] as? String ?? data["displayName"] as? String ?? "",
                        role: role,
                        restaurantId: userRestaurantId,
                        isActive: data["status"] as? String != "disabled",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        lastLogin: Date()
                    )
                    
                    // Update last login
                    document.reference.updateData(["lastLogin": FieldValue.serverTimestamp()])
                    
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    print("✅ User profile loaded (backoffice): \(user.displayName) (\(user.role.displayName))")
                    
                    // Auto-configure restaurant from user profile
                    if !userRestaurantId.isEmpty {
                        self?.autoConfigureRestaurant(restaurantId: userRestaurantId)
                    } else if !userRestaurantCode.isEmpty {
                        // Fallback: look up restaurant by code
                        print("🔄 No restaurantId, looking up by code: \(userRestaurantCode)")
                        self?.autoConfigureRestaurantByCode(code: userRestaurantCode)
                    } else {
                        // Platform owner with no specific restaurant — find first available
                        print("🔄 Platform owner with no restaurant — finding first available")
                        self?.autoConfigureFirstAvailableRestaurant()
                    }
                    
                    completion?(.success(user))
                    return
                }
                
                // Step 2: Fall back to restaurant subcollection (iOS-created users)
                print("🔍 Not found in top-level, checking restaurants/\(restaurantId)/users/")
                guard !restaurantId.isEmpty else {
                    print("❌ No restaurant ID found")
                    let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No restaurant configured"])
                    completion?(.failure(error))
                    return
                }
                
                self?.db.collection("restaurants")
                    .document(restaurantId)
                    .collection("users")
                    .whereField("firebaseUid", isEqualTo: firebaseUid)
                    .limit(to: 1)
                    .getDocuments { [weak self] snapshot, error in
                        if let error = error {
                            print("❌ Failed to load user profile: \(error.localizedDescription)")
                            completion?(.failure(error))
                            return
                        }
                        
                        guard let document = snapshot?.documents.first else {
                            print("❌ User profile not found for UID: \(firebaseUid)")
                            let error = NSError(domain: "AuthenticationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profil utilisateur non trouvé. Contactez votre administrateur."])
                            completion?(.failure(error))
                            return
                        }
                        
                        do {
                            var user = try document.data(as: RestaurantUser.self)
                            
                            if !user.isActive {
                                print("❌ User account is deactivated")
                                let error = NSError(domain: "AuthenticationService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Compte désactivé"])
                                completion?(.failure(error))
                                return
                            }
                            
                            // Update last login
                            document.reference.updateData(["lastLogin": FieldValue.serverTimestamp()])
                            user.lastLogin = Date()
                            
                            self?.currentUser = user
                            self?.isAuthenticated = true
                            print("✅ User profile loaded (restaurant): \(user.displayName) (\(user.role.displayName))")
                            completion?(.success(user))
                        } catch {
                            print("❌ Failed to decode user profile: \(error)")
                            completion?(.failure(error))
                        }
                    }
            }
    }
    
    // MARK: - Auto Restaurant Configuration
    
    private func autoConfigureRestaurant(restaurantId: String, retryCount: Int = 0) {
        print("🔄 Auto-configuring restaurant from user profile: \(restaurantId) (attempt \(retryCount + 1))")
        
        // Store the document ID
        UserDefaults.standard.set(restaurantId, forKey: "restaurantDocumentId")
        
        RestaurantService.shared.getRestaurantById(restaurantId) { [weak self] restaurant, error in
            DispatchQueue.main.async {
                if let restaurant = restaurant {
                    // Store the restaurant code too
                    UserDefaults.standard.set(restaurant.code, forKey: "selectedRestaurantCode")
                    RestaurantManager.shared.setCurrentRestaurant(restaurant)
                    print("✅ Restaurant auto-configured: \(restaurant.name) (\(restaurant.code))")
                } else {
                    print("❌ Failed to auto-configure restaurant: \(error?.localizedDescription ?? "Unknown error")")
                    
                    // Retry up to 3 times with increasing delay
                    if retryCount < 3 {
                        let delay = Double(retryCount + 1) * 2.0
                        print("🔄 Retrying in \(delay) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self?.autoConfigureRestaurant(restaurantId: restaurantId, retryCount: retryCount + 1)
                        }
                    } else {
                        print("❌ All retries failed for restaurant auto-configuration")
                        RestaurantManager.shared.setLoadingFailed(true)
                    }
                }
            }
        }
    }
    
    private func autoConfigureRestaurantByCode(code: String) {
        print("🔄 Auto-configuring restaurant by code: \(code)")
        
        RestaurantService.shared.getRestaurantByCode(code) { restaurant, documentId, error in
            DispatchQueue.main.async {
                if let restaurant = restaurant, let documentId = documentId {
                    UserDefaults.standard.set(documentId, forKey: "restaurantDocumentId")
                    UserDefaults.standard.set(restaurant.code, forKey: "selectedRestaurantCode")
                    RestaurantManager.shared.setCurrentRestaurant(restaurant)
                    print("✅ Restaurant auto-configured by code: \(restaurant.name)")
                } else {
                    print("❌ Failed to find restaurant by code '\(code)': \(error?.localizedDescription ?? "Unknown")")
                    RestaurantManager.shared.setLoadingFailed(true)
                }
            }
        }
    }
    
    private func autoConfigureFirstAvailableRestaurant() {
        print("🔄 Finding first available restaurant for platform owner...")
        
        db.collection("restaurants")
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let document = snapshot?.documents.first {
                        do {
                            let restaurant = try document.data(as: Restaurant.self)
                            let documentId = document.documentID
                            UserDefaults.standard.set(documentId, forKey: "restaurantDocumentId")
                            UserDefaults.standard.set(restaurant.code, forKey: "selectedRestaurantCode")
                            RestaurantManager.shared.setCurrentRestaurant(restaurant)
                            print("✅ Platform owner auto-configured with first restaurant: \(restaurant.name) (\(documentId))")
                        } catch {
                            print("❌ Failed to decode restaurant: \(error)")
                            RestaurantManager.shared.setLoadingFailed(true)
                        }
                    } else {
                        print("❌ No active restaurants found: \(error?.localizedDescription ?? "Empty")")
                        RestaurantManager.shared.setLoadingFailed(true)
                    }
                }
            }
    }
    
    // Map backoffice role strings to iOS UserRole enum
    private func mapBackofficeRole(_ roleString: String) -> UserRole {
        switch roleString {
        case "platform_owner", "super_admin", "restaurant_owner", "owner":
            return .owner
        case "manager":
            return .manager
        case "staff":
            return .staff
        default:
            return .staff
        }
    }
    
    func createUserProfile(user: RestaurantUser, completion: @escaping (Result<RestaurantUser, Error>) -> Void) {
        do {
            let userRef = db.collection("restaurants")
                .document(user.restaurantId)
                .collection("users")
                .document()
            
            var newUser = user
            newUser.id = userRef.documentID
            
            try userRef.setData(from: newUser) { error in
                if let error = error {
                    print("❌ Failed to create user profile: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ User profile created: \(newUser.displayName)")
                    self.currentUser = newUser
                    self.isAuthenticated = true
                    
                    if let currentUser = self.currentUser {
                        self.logAudit(action: .createUser, user: currentUser, details: ["newUser": newUser.email])
                    }
                    
                    completion(.success(newUser))
                }
            }
        } catch {
            print("❌ Failed to encode user profile: \(error)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Anonymous to Email Migration
    
    func upgradeAnonymousToEmail(email: String, password: String, displayName: String, completion: @escaping (Result<RestaurantUser, Error>) -> Void) {
        guard let currentFirebaseUser = Auth.auth().currentUser, currentFirebaseUser.isAnonymous else {
            let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not an anonymous user"])
            completion(.failure(error))
            return
        }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No restaurant configured"])
            completion(.failure(error))
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        currentFirebaseUser.link(with: credential) { [weak self] authResult, error in
            if let error = error {
                print("❌ Failed to upgrade anonymous account: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                let error = NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                completion(.failure(error))
                return
            }
            
            print("✅ Anonymous account upgraded to email/password")
            
            let user = RestaurantUser(
                firebaseUid: firebaseUser.uid,
                email: email,
                displayName: displayName,
                role: .owner,
                restaurantId: restaurantId,
                createdAt: Date()
            )
            
            self?.createUserProfile(user: user, completion: completion)
        }
    }
    
    // MARK: - Audit Logging
    
    private func logAudit(action: AuditAction, user: RestaurantUser, details: [String: String] = [:]) {
        AuditService.shared.log(
            action: action,
            user: user,
            details: details
        )
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
