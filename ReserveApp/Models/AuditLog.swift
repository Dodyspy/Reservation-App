import Foundation
import FirebaseFirestore

enum AuditAction: String, Codable {
    case login = "login"
    case logout = "logout"
    case createReservation = "create_reservation"
    case updateReservation = "update_reservation"
    case deleteReservation = "delete_reservation"
    case closeService = "close_service"
    case openService = "open_service"
    case updateSettings = "update_settings"
    case createUser = "create_user"
    case updateUser = "update_user"
    case deleteUser = "delete_user"
    case createRestaurant = "create_restaurant"
    case updateRestaurant = "update_restaurant"
    case assignTable = "assign_table"
    case updateCustomer = "update_customer"
    
    var displayName: String {
        switch self {
        case .login: return "User Login"
        case .logout: return "User Logout"
        case .createReservation: return "Created Reservation"
        case .updateReservation: return "Updated Reservation"
        case .deleteReservation: return "Deleted Reservation"
        case .closeService: return "Closed Service"
        case .openService: return "Opened Service"
        case .updateSettings: return "Updated Settings"
        case .createUser: return "Created User"
        case .updateUser: return "Updated User"
        case .deleteUser: return "Deleted User"
        case .createRestaurant: return "Created Restaurant"
        case .updateRestaurant: return "Updated Restaurant"
        case .assignTable: return "Assigned Table"
        case .updateCustomer: return "Updated Customer"
        }
    }
    
    var icon: String {
        switch self {
        case .login: return "arrow.right.square"
        case .logout: return "arrow.left.square"
        case .createReservation: return "plus.circle"
        case .updateReservation: return "pencil.circle"
        case .deleteReservation: return "trash.circle"
        case .closeService: return "lock.circle"
        case .openService: return "lock.open"
        case .updateSettings: return "gearshape"
        case .createUser: return "person.badge.plus"
        case .updateUser: return "person.crop.circle.badge.checkmark"
        case .deleteUser: return "person.crop.circle.badge.xmark"
        case .createRestaurant: return "building.2"
        case .updateRestaurant: return "building.2.crop.circle"
        case .assignTable: return "table.furniture"
        case .updateCustomer: return "person.text.rectangle"
        }
    }
}

struct AuditLogEntry: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var userEmail: String
    var action: AuditAction
    var details: [String: String]
    var timestamp: Date
    var restaurantId: String
    var ipAddress: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userName
        case userEmail
        case action
        case details
        case timestamp
        case restaurantId
        case ipAddress
    }
    
    init(
        id: String? = nil,
        userId: String,
        userName: String,
        userEmail: String,
        action: AuditAction,
        details: [String: String] = [:],
        timestamp: Date = Date(),
        restaurantId: String,
        ipAddress: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.action = action
        self.details = details
        self.timestamp = timestamp
        self.restaurantId = restaurantId
        self.ipAddress = ipAddress
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: timestamp)
    }
    
    var detailsDescription: String {
        details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
