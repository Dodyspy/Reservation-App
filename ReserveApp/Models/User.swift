import Foundation
import FirebaseFirestore

enum UserRole: String, Codable, CaseIterable {
    case owner = "owner"
    case manager = "manager"
    case staff = "staff"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .manager: return "Manager"
        case .staff: return "Staff"
        }
    }
    
    var permissions: [Permission] {
        switch self {
        case .owner:
            return Permission.allCases
        case .manager:
            return [
                .viewReservations,
                .editReservations,
                .deleteReservations,
                .createReservations,
                .manageServices,
                .viewSettings,
                .editSettings,
                .viewAuditLog,
                .viewCustomers
            ]
        case .staff:
            return [
                .viewReservations,
                .editReservations,
                .createReservations,
                .viewCustomers
            ]
        }
    }
}

enum Permission: String, Codable, CaseIterable {
    case viewReservations = "view_reservations"
    case editReservations = "edit_reservations"
    case deleteReservations = "delete_reservations"
    case createReservations = "create_reservations"
    case manageServices = "manage_services"
    case viewSettings = "view_settings"
    case editSettings = "edit_settings"
    case deleteRestaurant = "delete_restaurant"
    case manageUsers = "manage_users"
    case viewAuditLog = "view_audit_log"
    case viewCustomers = "view_customers"
    case editCustomers = "edit_customers"
    
    var displayName: String {
        switch self {
        case .viewReservations: return "View Reservations"
        case .editReservations: return "Edit Reservations"
        case .deleteReservations: return "Delete Reservations"
        case .createReservations: return "Create Reservations"
        case .manageServices: return "Manage Services"
        case .viewSettings: return "View Settings"
        case .editSettings: return "Edit Settings"
        case .deleteRestaurant: return "Delete Restaurant"
        case .manageUsers: return "Manage Users"
        case .viewAuditLog: return "View Audit Log"
        case .viewCustomers: return "View Customers"
        case .editCustomers: return "Edit Customers"
        }
    }
}

struct RestaurantUser: Codable, Identifiable {
    @DocumentID var id: String?
    var firebaseUid: String
    var email: String
    var displayName: String
    var role: UserRole
    var restaurantId: String
    var isActive: Bool
    var createdAt: Date
    var createdBy: String?
    var lastLogin: Date?
    var photoURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case firebaseUid
        case email
        case displayName
        case role
        case restaurantId
        case isActive
        case createdAt
        case createdBy
        case lastLogin
        case photoURL
    }
    
    init(
        id: String? = nil,
        firebaseUid: String,
        email: String,
        displayName: String,
        role: UserRole,
        restaurantId: String,
        isActive: Bool = true,
        createdAt: Date = Date(),
        createdBy: String? = nil,
        lastLogin: Date? = nil,
        photoURL: String? = nil
    ) {
        self.id = id
        self.firebaseUid = firebaseUid
        self.email = email
        self.displayName = displayName
        self.role = role
        self.restaurantId = restaurantId
        self.isActive = isActive
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.lastLogin = lastLogin
        self.photoURL = photoURL
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        return role.permissions.contains(permission)
    }
    
    func canManageUsers() -> Bool {
        return role == .owner
    }
}
