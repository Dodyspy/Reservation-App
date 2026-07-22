import Foundation
import FirebaseFirestore

struct Reservation: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var numberOfPeople: Int
    var date: Date
    var time: String
    var specialRequests: String?
    var status: ReservationStatus
    @ServerTimestamp var createdAt: Date?
    var arrivedAt: Date?
    var finishedAt: Date?
    
    // Customer tracking fields
    var customerId: String?
    
    // Audit tracking fields
    var modifiedBy: String?
    var modifiedByName: String?
    var modifiedByEmail: String?
    var modifiedAt: Date?
    
    // Firebase fields that don't match our model
    private var dateString: String?
    private var guests: Int?
    private var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case guests             // Firebase field name
        case dateString = "date"        // Firebase has date as string
        case dateTimestamp      // For proper ordering
        case time
        case notes              // Firebase field name
        case status
        case createdAt
        case arrivedAt
        case finishedAt
        case customerId
        case modifiedBy
        case modifiedByName
        case modifiedByEmail
        case modifiedAt
    }
    
    // Regular initializer for creating new reservations
    init(name: String, email: String, phone: String, numberOfPeople: Int, date: Date, time: String, specialRequests: String? = nil, status: ReservationStatus, customerId: String? = nil) {
        self.name = name
        self.email = email
        self.phone = phone
        self.numberOfPeople = numberOfPeople
        self.date = date
        self.time = time
        self.specialRequests = specialRequests
        self.status = status
        self.customerId = customerId
        self.createdAt = nil // Will be set by Firebase
        self.arrivedAt = nil
        self.finishedAt = nil
        self.modifiedBy = nil
        self.modifiedByName = nil
        self.modifiedByEmail = nil
        self.modifiedAt = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Standard fields
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        time = try container.decode(String.self, forKey: .time)
        status = try container.decode(ReservationStatus.self, forKey: .status)
        
        // Handle guests/numberOfPeople
        numberOfPeople = try container.decodeIfPresent(Int.self, forKey: .guests) ?? 1
        
        // Handle notes/specialRequests
        if let notes = try container.decodeIfPresent(String.self, forKey: .notes) {
            specialRequests = notes.isEmpty || notes == "Aucune note" ? nil : notes
        } else {
            specialRequests = nil
        }
        
        // Handle date parsing from string - support multiple formats
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = TimeZone(identifier: "Europe/Paris") // Fix timezone issue
            
            // Try multiple date formats to handle different inputs
            let formats = ["dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "d/M/yy", "yyyy-MM-dd"]
            var parsedDate: Date?
            
            for format in formats {
                formatter.dateFormat = format
                if let parsed = formatter.date(from: dateString) {
                    // Adjust to noon to avoid timezone boundary issues
                    if let adjustedDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: parsed) {
                        parsedDate = adjustedDate
                    } else {
                        parsedDate = parsed
                    }
                    break
                }
            }
            
            date = parsedDate ?? Date()
            Logger.debug("✅ Parsed date string '\(dateString)' to: \(date)")
        } else {
            // Try to decode as Date object directly
            date = try container.decodeIfPresent(Date.self, forKey: .dateString) ?? Date()
        }
        
        // Handle optional fields
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        arrivedAt = try container.decodeIfPresent(Date.self, forKey: .arrivedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        modifiedBy = try container.decodeIfPresent(String.self, forKey: .modifiedBy)
        modifiedByName = try container.decodeIfPresent(String.self, forKey: .modifiedByName)
        modifiedByEmail = try container.decodeIfPresent(String.self, forKey: .modifiedByEmail)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        
        // Try to decode DocumentID
        _id = try DocumentID(from: decoder)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(numberOfPeople, forKey: .guests)  // Save as "guests"
        try container.encode(time, forKey: .time)
        try container.encode(status, forKey: .status)
        
        // Encode date as string for Firebase
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        try container.encode(formatter.string(from: date), forKey: .dateString)
        
        // Also encode dateTimestamp for proper ordering
        try container.encode(date, forKey: .dateTimestamp)
        
        // Encode notes
        try container.encodeIfPresent(specialRequests, forKey: .notes)
        try container.encodeIfPresent(customerId, forKey: .customerId)
        try container.encodeIfPresent(arrivedAt, forKey: .arrivedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encodeIfPresent(modifiedBy, forKey: .modifiedBy)
        try container.encodeIfPresent(modifiedByName, forKey: .modifiedByName)
        try container.encodeIfPresent(modifiedByEmail, forKey: .modifiedByEmail)
        try container.encodeIfPresent(modifiedAt, forKey: .modifiedAt)
        
        // Only encode createdAt if it's not nil (Firebase will set @ServerTimestamp)
        if let createdAt = createdAt {
            try container.encode(createdAt, forKey: .createdAt)
        }
        
        // Only encode ID if it exists (for updates, not for new documents)
        if let id = id {
            try container.encode(id, forKey: .id)
        }
    }
}

enum ReservationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case arrived = "arrived"
    case completed = "completed"
    case cancelled = "cancelled"
    case noShow = "no_show"
    
    var displayName: String {
        switch self {
        case .pending: return "En attente"
        case .confirmed: return "Confirmée"
        case .arrived: return "Arrivé"
        case .completed: return "Terminée"
        case .cancelled: return "Annulée"
        case .noShow: return "No-show"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "green"
        case .arrived: return "blue"
        case .completed: return "gray"
        case .cancelled: return "red"
        case .noShow: return "red"
        }
    }
}
