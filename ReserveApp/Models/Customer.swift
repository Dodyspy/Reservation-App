import Foundation
import FirebaseFirestore

struct Customer: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var primary_email: String
    var primary_phone: String
    var total_reservations: Int
    var no_show_count: Int
    var created_at: Date?
    var updated_at: Date?
    
    // Enhanced profile fields
    var primary_name: String?
    var all_emails: [String]?
    var all_phones: [String]?
    var first_reservation_date: String?
    var last_reservation_date: String?
    var last_no_show_date: String?
    var preferences: CustomerPreferences?
    var vip_status: VIPStatus?
    var notes: String?
    var birthday: Date?
    var anniversary: Date?
    
    struct CustomerPreferences: Codable {
        var preferred_seating: Table.TableLocation?
        var dietary_restrictions: [String]?
        var favorite_dishes: [String]?
        var allergies: [String]?
        var special_occasions: [String]?
        var communication_preference: CommunicationPreference?
        
        enum CommunicationPreference: String, Codable, CaseIterable {
            case email = "email"
            case phone = "phone"
            case both = "both"
            case minimal = "minimal"
            
            var displayName: String {
                switch self {
                case .email: return "Email uniquement"
                case .phone: return "Téléphone uniquement"
                case .both: return "Email et téléphone"
                case .minimal: return "Communication minimale"
                }
            }
        }
    }
    
    enum VIPStatus: String, Codable, CaseIterable {
        case regular = "regular"
        case vip = "vip"
        case premium = "premium"
        case blacklisted = "blacklisted"
        
        var displayName: String {
            switch self {
            case .regular: return "Client régulier"
            case .vip: return "VIP"
            case .premium: return "Premium"
            case .blacklisted: return "Liste noire"
            }
        }
        
        var color: String {
            switch self {
            case .regular: return "blue"
            case .vip: return "gold"
            case .premium: return "purple"
            case .blacklisted: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .regular: return "person.circle"
            case .vip: return "star.circle.fill"
            case .premium: return "crown.fill"
            case .blacklisted: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case primary_email
        case primary_phone
        case total_reservations
        case no_show_count
        case created_at
        case updated_at
        case primary_name
        case all_emails
        case all_phones
        case first_reservation_date
        case last_reservation_date
        case last_no_show_date
        case preferences
        case vip_status
        case notes
        case birthday
        case anniversary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        primary_email = try container.decode(String.self, forKey: .primary_email)
        primary_phone = try container.decodeIfPresent(String.self, forKey: .primary_phone) ?? ""
        total_reservations = try container.decode(Int.self, forKey: .total_reservations)
        no_show_count = try container.decode(Int.self, forKey: .no_show_count)
        
        // Optional fields (ignore if not present)
        primary_name = try container.decodeIfPresent(String.self, forKey: .primary_name)
        all_emails = try container.decodeIfPresent([String].self, forKey: .all_emails)
        all_phones = try container.decodeIfPresent([String].self, forKey: .all_phones)
        first_reservation_date = try container.decodeIfPresent(String.self, forKey: .first_reservation_date)
        last_reservation_date = try container.decodeIfPresent(String.self, forKey: .last_reservation_date)
        last_no_show_date = try container.decodeIfPresent(String.self, forKey: .last_no_show_date)
        preferences = try container.decodeIfPresent(CustomerPreferences.self, forKey: .preferences)
        vip_status = try container.decodeIfPresent(VIPStatus.self, forKey: .vip_status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        anniversary = try container.decodeIfPresent(Date.self, forKey: .anniversary)
        
        // Handle timestamps - can be Firestore Timestamps (decoded as Date), or ISO8601 strings
        // Try Date first (Firestore Timestamps), then fall back to ISO8601 string
        if let createdAtDate = try? container.decode(Date.self, forKey: .created_at) {
            created_at = createdAtDate
        } else if let createdAtString = try? container.decode(String.self, forKey: .created_at) {
            created_at = ISO8601DateFormatter().date(from: createdAtString)
        } else {
            created_at = nil
        }
        
        if let updatedAtDate = try? container.decode(Date.self, forKey: .updated_at) {
            updated_at = updatedAtDate
        } else if let updatedAtString = try? container.decode(String.self, forKey: .updated_at) {
            updated_at = ISO8601DateFormatter().date(from: updatedAtString)
        } else {
            updated_at = nil
        }
        
        // Try to decode DocumentID
        _id = try DocumentID(from: decoder)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(primary_email, forKey: .primary_email)
        try container.encode(primary_phone, forKey: .primary_phone)
        try container.encode(total_reservations, forKey: .total_reservations)
        try container.encode(no_show_count, forKey: .no_show_count)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        
        try _id.encode(to: encoder)
    }
    
    // Simple initializer for preview data and testing
    init(id: String? = nil, primary_email: String, primary_phone: String, total_reservations: Int, no_show_count: Int, created_at: Date? = nil, updated_at: Date? = nil) {
        self._id = DocumentID(wrappedValue: id)
        self.primary_email = primary_email
        self.primary_phone = primary_phone
        self.total_reservations = total_reservations
        self.no_show_count = no_show_count
        self.created_at = created_at
        self.updated_at = updated_at
        
        // Initialize optional fields
        self.primary_name = nil
        self.all_emails = nil
        self.all_phones = nil
        self.first_reservation_date = nil
        self.last_reservation_date = nil
        self.last_no_show_date = nil
    }
    
    // Computed properties for UI display
    var hasNoShows: Bool {
        return no_show_count > 0
    }
    
    var isRepeatCustomer: Bool {
        return total_reservations > 1
    }
    
    var customerStatusText: String {
        if hasNoShows {
            return "⚠️ \(no_show_count) no-show\(no_show_count > 1 ? "s" : "")"
        } else if isRepeatCustomer {
            return "🔄 \(total_reservations) réservations"
        } else {
            return "✨ Nouveau client"
        }
    }
    
    var statusColor: String {
        if hasNoShows {
            return "red"
        } else if isRepeatCustomer {
            return "blue"
        } else {
            return "green"
        }
    }
    
    // Hashable conformance for NavigationLink
    func hash(into hasher: inout Hasher) {
        hasher.combine(primary_email)
    }
    
    static func == (lhs: Customer, rhs: Customer) -> Bool {
        lhs.primary_email == rhs.primary_email
    }
}

struct CustomerHistory {
    let customer: Customer?
    let totalReservations: Int
    let noShowCount: Int
    let hasNoShows: Bool
    let isRepeatCustomer: Bool
    let statusText: String
    let statusColor: String
    
    init(customer: Customer?) {
        self.customer = customer
        self.totalReservations = customer?.total_reservations ?? 1
        self.noShowCount = customer?.no_show_count ?? 0
        self.hasNoShows = noShowCount > 0
        self.isRepeatCustomer = totalReservations > 1
        
        if hasNoShows {
            self.statusText = "⚠️ \(noShowCount) no-show\(noShowCount > 1 ? "s" : "")"
            self.statusColor = "red"
        } else if isRepeatCustomer {
            self.statusText = "🔄 \(totalReservations) réservations"
            self.statusColor = "blue"
        } else {
            self.statusText = "✨ Nouveau client"
            self.statusColor = "green"
        }
    }
}
