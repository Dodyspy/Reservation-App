import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class TableViewModel: ObservableObject {
    @Published var tables: [Table] = []
    @Published var locations: [Table.TableLocation] = Table.TableLocation.allCases
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        loadTables()
    }
    
    // MARK: - Table Management
    
    func loadTables() {
        isLoading = true
        errorMessage = nil
        
        // Use direct Firestore connection like reservations
        listener = db.collection("tables")
            .order(by: "number")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.debug("Firestore tables error: \(error.localizedDescription)")
                    // If it's a permission error, try to initialize tables in Firebase
                    if error.localizedDescription.contains("permissions") {
                        Logger.debug("🔄 Attempting to initialize tables in Firebase...")
                        self.initializeTablesInFirebase()
                    } else {
                        self.loadDefaultTables()
                    }
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    Logger.debug("No tables found in Firestore, initializing with defaults")
                    self.initializeTablesInFirebase()
                    return
                }
                
                let loadedTables = documents.compactMap { document -> Table? in
                    var data = document.data()
                    data["id"] = document.documentID
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        return try JSONDecoder().decode(Table.self, from: jsonData)
                    } catch {
                        Logger.debug("Error decoding table: \(error)")
                        return nil
                    }
                }
                
                if loadedTables.isEmpty {
                    Logger.debug("No valid tables found in Firestore, initializing with defaults")
                    self.initializeTablesInFirebase()
                } else {
                    Logger.debug("✅ Loaded \(loadedTables.count) tables from Firestore")
                    self.tables = loadedTables.sorted { $0.number < $1.number }
                    self.isLoading = false
                }
            }
    }
    
    private func initializeTablesInFirebase() {
        Logger.debug("🚀 Initializing tables in Firebase...")
        let defaultTables = RestaurantLayout.defaultTables
        
        Task {
            var successCount = 0
            for table in defaultTables {
                do {
                    _ = try db.collection("tables").addDocument(from: table)
                    successCount += 1
                } catch {
                    Logger.debug("❌ Failed to add table \(table.number): \(error)")
                }
            }
            
            await MainActor.run {
                if successCount > 0 {
                    Logger.debug("✅ Successfully initialized \(successCount) tables in Firebase")
                } else {
                    Logger.debug("❌ Failed to initialize tables, using local defaults")
                    self.loadDefaultTables()
                }
            }
        }
    }
    
    func addTable(_ table: Table) {
        do {
            _ = try db.collection("tables").addDocument(from: table)
            Logger.debug("✅ Added table to Firestore")
        } catch {
            Logger.debug("❌ Error adding table: \(error)")
            errorMessage = "Erreur d'ajout: \(error.localizedDescription)"
        }
    }
    
    func updateTable(_ table: Table) {
        guard let id = table.id else { return }
        
        do {
            try db.collection("tables").document(id).setData(from: table, merge: true)
            Logger.debug("✅ Updated table in Firestore")
        } catch {
            Logger.debug("❌ Error updating table: \(error)")
            errorMessage = "Erreur de mise à jour: \(error.localizedDescription)"
        }
    }
    
    func deleteTable(_ table: Table) {
        guard let id = table.id else { return }
        
        db.collection("tables").document(id).delete { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    Logger.debug("❌ Error deleting table: \(error)")
                    self?.errorMessage = "Erreur de suppression: \(error.localizedDescription)"
                } else {
                    Logger.debug("✅ Deleted table from Firestore")
                }
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    func toggleTableAvailability(_ table: Table) {
        var updatedTable = table
        updatedTable.isAvailable.toggle()
        updateTable(updatedTable)
    }
    
    // MARK: - Location Management
    
    func addCustomLocation(_ name: String) {
        // For now, we'll use the existing enum cases
        // In a full implementation, this would be stored in Firestore
        Logger.debug("Adding custom location: \(name)")
    }
    
    // MARK: - Helper Methods
    
    func tablesForLocation(_ location: Table.TableLocation) -> [Table] {
        return tables.filter { $0.location == location }
    }
    
    func tablesForZone(_ zoneId: String) -> [Table] {
        return tables.filter { table in
            if let customZoneId = table.zoneId {
                return customZoneId == zoneId
            }
            // Map default locations to zone IDs
            switch table.location {
            case .terrace: return zoneId == "terrace"
            case .interior: return zoneId == "interior"
            case .bar: return zoneId == "bar"
            case .privateRoom: return zoneId == "privateRoom"
            case .custom: return false
            }
        }.sorted { $0.number < $1.number }
    }
    
    func getNextTableNumber(for location: Table.TableLocation) -> Int {
        let existingNumbers = tablesForLocation(location).map { $0.number }
        let baseNumber = location.baseTableNumber
        
        for i in 1...99 {
            let number = baseNumber + i
            if !existingNumbers.contains(number) {
                return number
            }
        }
        return baseNumber + 1
    }
    
    func isTableNumberAvailable(_ number: Int, in location: Table.TableLocation, excluding tableId: String? = nil) -> Bool {
        return !tables.contains { table in
            table.number == number && 
            table.location == location && 
            table.id != tableId
        }
    }
    
    private func createDefaultTables() {
        let defaultTables = RestaurantLayout.defaultTables
        
        for table in defaultTables {
            addTable(table)
        }
    }
    
    private func loadDefaultTables() {
        self.tables = RestaurantLayout.defaultTables
        self.isLoading = false
    }
}

// MARK: - Firestore Helper Functions

struct FirestoreCollectionResponse: Codable {
    let documents: [FirestoreDocument]?
}

struct FirestoreDocument: Codable {
    let name: String
    let fields: [String: FirestoreValue]
    let createTime: String?
    let updateTime: String?
}

struct FirestoreValue: Codable {
    let stringValue: String?
    let integerValue: String?
    let booleanValue: Bool?
    let timestampValue: String?
}

func createFirestoreDocument<T: Codable>(from object: T) throws -> [String: Any] {
    let encoder = JSONEncoder()
    let data = try encoder.encode(object)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw NSError(domain: "TableViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode object to JSON dictionary"])
    }
    
    var fields: [String: Any] = [:]
    
    for (key, value) in json {
        if let stringValue = value as? String {
            fields[key] = ["stringValue": stringValue]
        } else if let intValue = value as? Int {
            fields[key] = ["integerValue": String(intValue)]
        } else if let boolValue = value as? Bool {
            fields[key] = ["booleanValue": boolValue]
        }
    }
    
    return ["fields": fields]
}

func parseFirestoreDocument<T: Codable>(_ document: FirestoreDocument, as type: T.Type) throws -> T {
    var json: [String: Any] = [:]
    
    // Extract document ID from the name field
    let pathComponents = document.name.components(separatedBy: "/")
    if let documentId = pathComponents.last {
        json["id"] = documentId
    }
    
    for (key, value) in document.fields {
        if let stringValue = value.stringValue {
            json[key] = stringValue
        } else if let integerValue = value.integerValue, let intValue = Int(integerValue) {
            json[key] = intValue
        } else if let booleanValue = value.booleanValue {
            json[key] = booleanValue
        }
    }
    
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(type, from: data)
}

// MARK: - Table Location Extensions

extension Table.TableLocation {
    var baseTableNumber: Int {
        switch self {
        case .terrace: return 0
        case .interior: return 10
        case .bar: return 30
        case .privateRoom: return 40
        case .custom: return 50
        }
    }
    
}
