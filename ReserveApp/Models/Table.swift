import Foundation
import SwiftUI
import FirebaseFirestore

struct Table: Identifiable, Codable {
    var id: String?
    var number: Int
    var capacity: Int
    var location: TableLocation
    var zoneId: String? // Custom zone reference
    var isAvailable: Bool
    var notes: String?
    
    enum TableLocation: String, Codable, CaseIterable {
        case terrace = "terrasse"
        case interior = "intérieur"
        case bar = "bar"
        case privateRoom = "salon privé"
        case custom = "custom" // For custom zones
        
        var displayName: String {
            switch self {
            case .terrace: return "Terrasse"
            case .interior: return "Intérieur"
            case .bar: return "Bar"
            case .privateRoom: return "Salon Privé"
            case .custom: return "Zone Personnalisée"
            }
        }
        
        var icon: String {
            switch self {
            case .terrace: return "sun.max"
            case .interior: return "house"
            case .bar: return "wineglass"
            case .privateRoom: return "lock"
            case .custom: return "rectangle.3.group"
            }
        }
        
        var zoneColor: Color {
            switch self {
            case .terrace: return Color(hex: "#F4A261")
            case .interior: return Color(hex: "#2A9D8F")
            case .bar: return Color(hex: "#E76F51")
            case .privateRoom: return Color(hex: "#264653")
            case .custom: return .purple
            }
        }
    }
    
    init(id: String? = nil, number: Int, capacity: Int, location: TableLocation, zoneId: String? = nil, isAvailable: Bool = true, notes: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.number = number
        self.capacity = capacity
        self.location = location
        self.zoneId = zoneId
        self.isAvailable = isAvailable
        self.notes = notes
    }
}

// MARK: - Table Assignment for Reservations

extension Reservation {
    var assignedTableNumber: Int? {
        // This would be stored in Firestore as an additional field
        return nil // Placeholder - would be implemented with Firestore field
    }
}

// MARK: - Default Restaurant Layout

struct RestaurantLayout {
    static let defaultTables: [Table] = {
        var tables: [Table] = []
        
        // Terrasse (8 tables)
        tables.append(Table(id: "table_terrace_1", number: 1, capacity: 2, location: .terrace))
        tables.append(Table(id: "table_terrace_2", number: 2, capacity: 4, location: .terrace))
        tables.append(Table(id: "table_terrace_3", number: 3, capacity: 2, location: .terrace))
        tables.append(Table(id: "table_terrace_4", number: 4, capacity: 6, location: .terrace))
        tables.append(Table(id: "table_terrace_5", number: 5, capacity: 4, location: .terrace))
        tables.append(Table(id: "table_terrace_6", number: 6, capacity: 2, location: .terrace))
        tables.append(Table(id: "table_terrace_7", number: 7, capacity: 4, location: .terrace))
        tables.append(Table(id: "table_terrace_8", number: 8, capacity: 2, location: .terrace))
        
        // Intérieur (12 tables)
        tables.append(Table(id: "table_interior_10", number: 10, capacity: 2, location: .interior))
        tables.append(Table(id: "table_interior_11", number: 11, capacity: 4, location: .interior))
        tables.append(Table(id: "table_interior_12", number: 12, capacity: 2, location: .interior))
        tables.append(Table(id: "table_interior_13", number: 13, capacity: 6, location: .interior))
        tables.append(Table(id: "table_interior_14", number: 14, capacity: 4, location: .interior))
        tables.append(Table(id: "table_interior_15", number: 15, capacity: 2, location: .interior))
        tables.append(Table(id: "table_interior_16", number: 16, capacity: 8, location: .interior))
        tables.append(Table(id: "table_interior_17", number: 17, capacity: 4, location: .interior))
        tables.append(Table(id: "table_interior_18", number: 18, capacity: 2, location: .interior))
        tables.append(Table(id: "table_interior_19", number: 19, capacity: 4, location: .interior))
        tables.append(Table(id: "table_interior_20", number: 20, capacity: 2, location: .interior))
        tables.append(Table(id: "table_interior_21", number: 21, capacity: 6, location: .interior))
        
        // Bar (4 tables)
        tables.append(Table(id: "table_bar_30", number: 30, capacity: 2, location: .bar))
        tables.append(Table(id: "table_bar_31", number: 31, capacity: 2, location: .bar))
        tables.append(Table(id: "table_bar_32", number: 32, capacity: 4, location: .bar))
        tables.append(Table(id: "table_bar_33", number: 33, capacity: 2, location: .bar))
        
        // Salon Privé (2 tables)
        tables.append(Table(id: "table_private_40", number: 40, capacity: 8, location: .privateRoom, notes: "Salon privé pour événements"))
        tables.append(Table(id: "table_private_41", number: 41, capacity: 12, location: .privateRoom, notes: "Grande table pour groupes"))
        
        return tables
    }()
}
