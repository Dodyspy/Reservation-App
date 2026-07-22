import Foundation
import FirebaseFirestore

struct Restaurant: Identifiable, Codable {
    @DocumentID var id: String?
    var code: String                    // Unique restaurant code (e.g., "CASANOVA2024")
    var name: String                   // Display name
    var displayName: String            // Formatted display name
    var website: String                // Restaurant website URL
    var email: String                  // Contact email
    var phone: String                  // Contact phone
    var address: String                // Full address
    
    // Branding configuration
    var branding: RestaurantBranding
    
    // Notification settings
    var fcmTopic: String              // Firebase topic for push notifications
    
    // Business settings
    var isActive: Bool
    var subscriptionTier: SubscriptionTier
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    
    // Availability settings (from dashboard)
    var temporarilyClosed: Bool?
    var closedReason: String?
    var isFull: Bool?
    var fullReason: String?
    var openingHours: [String: DayHours]?
    var closedDates: [ClosedDate]?
    var timeSlots: [String]?
    var maxGuestsPerSlot: Int?
    var reservationsThisMonth: Int?
    var subscriptionStatus: String?
    var paymentStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id, code, name, displayName, website, email, phone, address
        case branding, fcmTopic, isActive, subscriptionTier, createdAt, updatedAt
        case temporarilyClosed, closedReason, isFull, fullReason
        case openingHours, closedDates, timeSlots, maxGuestsPerSlot
        case reservationsThisMonth, subscriptionStatus, paymentStatus
    }
    
    // Regular initializer for creating new restaurants
    init(code: String, name: String, displayName: String, website: String, email: String, phone: String, address: String, branding: RestaurantBranding, fcmTopic: String, isActive: Bool, subscriptionTier: SubscriptionTier) {
        self.code = code
        self.name = name
        self.displayName = displayName
        self.website = website
        self.email = email
        self.phone = phone
        self.address = address
        self.branding = branding
        self.fcmTopic = fcmTopic
        self.isActive = isActive
        self.subscriptionTier = subscriptionTier
        self.createdAt = nil // Will be set by Firebase
        self.updatedAt = nil // Will be set by Firebase
        
        // Initialize optional availability settings
        self.temporarilyClosed = nil
        self.closedReason = nil
        self.isFull = nil
        self.fullReason = nil
        self.openingHours = nil
        self.closedDates = nil
        self.timeSlots = nil
        self.maxGuestsPerSlot = nil
        self.reservationsThisMonth = nil
        self.subscriptionStatus = nil
        self.paymentStatus = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields - use defaults to prevent decoding failures on new/incomplete documents
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Restaurant"
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? name
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        branding = try container.decodeIfPresent(RestaurantBranding.self, forKey: .branding) ?? RestaurantBranding.casanovaDefault
        fcmTopic = try container.decodeIfPresent(String.self, forKey: .fcmTopic) ?? "restaurant-reservations"
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        subscriptionTier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .subscriptionTier) ?? .free
        
        // Optional timestamp fields
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        // Optional availability settings
        temporarilyClosed = try container.decodeIfPresent(Bool.self, forKey: .temporarilyClosed)
        closedReason = try container.decodeIfPresent(String.self, forKey: .closedReason)
        isFull = try container.decodeIfPresent(Bool.self, forKey: .isFull)
        fullReason = try container.decodeIfPresent(String.self, forKey: .fullReason)
        openingHours = try container.decodeIfPresent([String: DayHours].self, forKey: .openingHours)
        closedDates = try container.decodeIfPresent([ClosedDate].self, forKey: .closedDates)
        timeSlots = try container.decodeIfPresent([String].self, forKey: .timeSlots)
        maxGuestsPerSlot = try container.decodeIfPresent(Int.self, forKey: .maxGuestsPerSlot)
        reservationsThisMonth = try container.decodeIfPresent(Int.self, forKey: .reservationsThisMonth)
        subscriptionStatus = try container.decodeIfPresent(String.self, forKey: .subscriptionStatus)
        paymentStatus = try container.decodeIfPresent(String.self, forKey: .paymentStatus)
        
        // DocumentID
        _id = try DocumentID(from: decoder)
    }
    
    // Helper computed properties
    var isTemporarilyClosed: Bool {
        return temporarilyClosed ?? false
    }
    
    var isRestaurantFull: Bool {
        return isFull ?? false
    }
    
    var canAcceptReservations: Bool {
        guard !isTemporarilyClosed && !isRestaurantFull else { return false }
        
        // Check subscription status
        if let status = subscriptionStatus, status != "active" {
            return false
        }
        
        // Check payment status
        if let payment = paymentStatus, payment == "overdue" {
            return false
        }
        
        return true
    }
    
    func getClosureMessage() -> String? {
        if isTemporarilyClosed {
            return closedReason ?? "Restaurant temporairement fermé"
        }
        if isRestaurantFull {
            return fullReason ?? "Restaurant complet pour aujourd'hui"
        }
        if let status = subscriptionStatus, status != "active" {
            return "Service non disponible"
        }
        if let payment = paymentStatus, payment == "overdue" {
            return "Service non disponible"
        }
        return nil
    }
}

// MARK: - Service Type
enum ServiceType: String, Codable, CaseIterable {
    case lunch = "lunch"
    case dinner = "dinner"
    
    var displayName: String {
        switch self {
        case .lunch: return "Déjeuner"
        case .dinner: return "Dîner"
        }
    }
    
    var timeRange: String {
        switch self {
        case .lunch: return "12h-15h"
        case .dinner: return "19h-23h"
        }
    }
    
    var icon: String {
        switch self {
        case .lunch: return "🍽️"
        case .dinner: return "🌙"
        }
    }
    
    // Determine service type from time slot
    static func from(timeSlot: String) -> ServiceType {
        let hour = Int(timeSlot.prefix(2)) ?? 0
        return hour < 16 ? .lunch : .dinner
    }
}

// MARK: - Service Status
struct ServiceStatus: Codable {
    var isClosed: Bool
    var reason: String?
    
    init(isClosed: Bool = false, reason: String? = nil) {
        self.isClosed = isClosed
        self.reason = reason
    }
}

// MARK: - Opening Hours
struct DayHours: Codable {
    var open: String
    var close: String
    var closed: Bool
    
    init(open: String = "12:00", close: String = "23:00", closed: Bool = false) {
        self.open = open
        self.close = close
        self.closed = closed
    }
}

// MARK: - Closed Date
struct ClosedDate: Codable {
    var date: String  // Format: "YYYY-MM-DD"
    var reason: String?
    
    init(date: String, reason: String? = nil) {
        self.date = date
        self.reason = reason
    }
}

struct RestaurantBranding: Codable {
    var primaryColor: String           // Hex color (e.g., "#D4AF37")
    var backgroundColor: String        // Hex color (e.g., "#2C2C2C")
    var accentColor: String           // Hex color for highlights
    var logoUrl: String?              // Optional logo URL
    var fontFamily: String?           // Optional custom font
    
    // Default Casanova d'Issy branding
    static let casanovaDefault = RestaurantBranding(
        primaryColor: "#D4AF37",      // Gold
        backgroundColor: "#2C2C2C",   // Anthracite
        accentColor: "#F5F5DC",       // Beige
        logoUrl: nil,
        fontFamily: "Georgia"
    )
    
    init(primaryColor: String, backgroundColor: String, accentColor: String, logoUrl: String? = nil, fontFamily: String? = nil) {
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.logoUrl = logoUrl
        self.fontFamily = fontFamily
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor) ?? "#D4AF37"
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "#2C2C2C"
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "#F5F5DC"
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
    }
}

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    case enterprise = "enterprise"
    
    var displayName: String {
        switch self {
        case .free: return "Gratuit"
        case .basic: return "Basique"
        case .premium: return "Premium"
        case .enterprise: return "Entreprise"
        }
    }
    
    var maxReservationsPerMonth: Int {
        return -1  // Unlimited for all tiers
    }
}

// MARK: - Restaurant Manager for Current Session
class RestaurantManager: ObservableObject {
    static let shared = RestaurantManager()
    
    @Published var currentRestaurant: Restaurant?
    @Published var isConfigured: Bool = false
    @Published var loadingFailed: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let restaurantCodeKey = "selectedRestaurantCode"
    private var hasInitialized = false
    private var restaurantSettingsListener: ListenerRegistration?
    
    private init() {
        // Don't load restaurant immediately - wait for Firebase to be configured
        Logger.debug("🏪 RestaurantManager initialized - waiting for Firebase configuration")
    }
    
    func setLoadingFailed(_ failed: Bool) {
        DispatchQueue.main.async {
            self.loadingFailed = failed
        }
    }
    
    func loadSavedRestaurantAfterFirebaseInit() {
        loadSavedRestaurant()
    }
    
    func setCurrentRestaurant(_ restaurant: Restaurant) {
        currentRestaurant = restaurant
        isConfigured = true
        UserDefaults.standard.set(restaurant.code, forKey: "selectedRestaurantCode")
        
        Logger.debug("✅ Restaurant configured: \(restaurant.name) (\(restaurant.code))")
        
        // Initialize Firebase for this restaurant (if not already done)
        initializeFirebaseForRestaurant()
        
        // Start listening to restaurant settings changes
        startListeningToRestaurantSettings()
    }
    
    private func initializeFirebaseForRestaurant() {
        Logger.debug("🔍 initializeFirebaseForRestaurant called - hasInitialized: \(hasInitialized)")
        
        // Prevent duplicate initialization
        guard !hasInitialized else {
            Logger.debug("⚠️ Firebase already initialized for restaurant - skipping duplicate initialization")
            return
        }
        
        hasInitialized = true
        Logger.debug("🔄 Initializing Firebase for restaurant...")
        
        // Enable Firestore network in background
        DispatchQueue.global(qos: .userInitiated).async {
            Firestore.firestore().enableNetwork { error in
                if let error = error {
                    Logger.debug("⚠️ Firestore network enable error: \(error.localizedDescription)")
                } else {
                    Logger.debug("✅ Firestore network enabled for restaurant")
                }
            }
            
            // Request notification permission (needed for fresh installs where AppDelegate skipped it)
            DispatchQueue.main.async {
                NotificationService.shared.requestPermission()
            }
            
            // Delay topic subscription and token registration to allow time for
            // permission prompt + APNS token registration on fresh installs
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                // Subscribe to restaurant-specific notifications
                NotificationService.shared.subscribeToRestaurantTopic()
                
                // Register device token for this restaurant
                NotificationService.shared.registerDeviceTokenForRestaurant()
            }
        }
    }
    
    func clearCurrentRestaurant() {
        // Stop listening to restaurant settings
        restaurantSettingsListener?.remove()
        restaurantSettingsListener = nil
        
        // Unsubscribe from current restaurant notifications
        NotificationService.shared.unsubscribeFromCurrentTopic()
        
        // Deactivate device token for current restaurant
        NotificationService.shared.removeDeviceTokenFromRestaurant()
        
        currentRestaurant = nil
        isConfigured = false
        UserDefaults.standard.removeObject(forKey: "selectedRestaurantCode")
        Logger.debug("🔄 Restaurant cleared - app will show setup screen")
    }
    
    private func loadSavedRestaurant() {
        guard let savedCode = userDefaults.string(forKey: restaurantCodeKey) else {
            Logger.debug("ℹ️ No saved restaurant code found")
            return
        }
        
        Logger.debug("🔍 Loading saved restaurant with code: \(savedCode)")
        
        // Load restaurant from Firebase
        RestaurantService.shared.getRestaurantByCode(savedCode) { [weak self] restaurant, documentId, error in
            DispatchQueue.main.async {
                if let restaurant = restaurant, let documentId = documentId {
                    // Store document ID
                    UserDefaults.standard.set(documentId, forKey: "restaurantDocumentId")
                    Logger.debug("✅ Stored document ID: \(documentId)")
                    
                    self?.setCurrentRestaurant(restaurant)
                    Logger.debug("✅ Restored restaurant: \(restaurant.name)")
                } else {
                    Logger.debug("❌ Failed to load saved restaurant: \(error?.localizedDescription ?? "Unknown error")")
                    self?.clearCurrentRestaurant()
                }
            }
        }
    }
    
    // Helper computed properties
    var restaurantCode: String? {
        return currentRestaurant?.code
    }
    
    var restaurantName: String {
        return currentRestaurant?.displayName ?? "Restaurant Manager"
    }
    
    var primaryColor: String {
        return currentRestaurant?.branding.primaryColor ?? "#D4AF37"
    }
    
    var backgroundColor: String {
        return currentRestaurant?.branding.backgroundColor ?? "#2C2C2C"
    }
    
    // MARK: - Real-time Settings Listener
    
    private func startListeningToRestaurantSettings() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            Logger.debug("⚠️ Cannot start settings listener: No restaurant document ID")
            return
        }
        
        // Remove existing listener if any
        restaurantSettingsListener?.remove()
        
        Logger.debug("🎧 Starting real-time listener for restaurant settings")
        
        restaurantSettingsListener = RestaurantService.shared.listenToRestaurantSettings(restaurantId: restaurantId) { [weak self] restaurant, error in
            DispatchQueue.main.async {
                if let error = error {
                    Logger.debug("❌ Error in restaurant settings listener: \(error.localizedDescription)")
                    return
                }
                
                if let restaurant = restaurant {
                    Logger.debug("🔄 Restaurant settings updated from dashboard")
                    self?.currentRestaurant = restaurant
                    
                    // Log important status changes
                    if restaurant.isTemporarilyClosed {
                        Logger.debug("🔒 Restaurant is now CLOSED: \(restaurant.closedReason ?? "No reason")")
                    }
                    if restaurant.isRestaurantFull {
                        Logger.debug("🈵 Restaurant is now FULL: \(restaurant.fullReason ?? "No reason")")
                    }
                }
            }
        }
    }
}
