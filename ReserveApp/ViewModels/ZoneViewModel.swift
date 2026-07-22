import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class ZoneViewModel: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        setupFirestoreListener()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Firebase Operations
    
    private func setupFirestoreListener() {
        isLoading = true
        
        listener = db.collection("zones")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase error loading zones: \(error.localizedDescription)")
                    self.loadDefaultZones()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No zones found in Firestore, initializing with defaults")
                    self.initializeDefaultZones()
                    return
                }
                
                if documents.isEmpty {
                    print("Empty zones collection, initializing with defaults")
                    self.initializeDefaultZones()
                } else {
                    self.zones = documents.compactMap { doc in
                        try? doc.data(as: Zone.self)
                    }
                    print("✅ Loaded \(self.zones.count) zones from Firestore")
                }
                
                self.isLoading = false
            }
    }
    
    private func loadDefaultZones() {
        zones = Zone.defaultZones
        isLoading = false
        print("Using default zones as fallback")
    }
    
    private func initializeDefaultZones() {
        print("🚀 Initializing zones in Firebase...")
        
        for zone in Zone.defaultZones {
            do {
                try db.collection("zones").document(zone.id).setData(from: zone)
                print("✅ Initialized zone: \(zone.displayName)")
            } catch {
                print("❌ Failed to initialize zone \(zone.displayName): \(error)")
            }
        }
    }
    
    // MARK: - Zone Management
    
    func addZone(_ zone: Zone) {
        do {
            try db.collection("zones").document(zone.id).setData(from: zone)
            print("✅ Added zone: \(zone.displayName)")
        } catch {
            errorMessage = "Erreur lors de l'ajout de la zone: \(error.localizedDescription)"
            print("❌ Failed to add zone: \(error)")
        }
    }
    
    func updateZone(_ zone: Zone) {
        do {
            try db.collection("zones").document(zone.id).setData(from: zone)
            print("✅ Updated zone: \(zone.displayName)")
        } catch {
            errorMessage = "Erreur lors de la mise à jour de la zone: \(error.localizedDescription)"
            print("❌ Failed to update zone: \(error)")
        }
    }
    
    func deleteZone(_ zone: Zone) {
        guard !zone.isDefault else {
            errorMessage = "Impossible de supprimer une zone par défaut"
            return
        }
        
        db.collection("zones").document(zone.id).delete { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    self?.errorMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    print("❌ Failed to delete zone: \(error)")
                } else {
                    print("✅ Deleted zone: \(zone.displayName)")
                }
            }
        }
    }
    
    func reorderZones(_ zones: [Zone]) {
        for (index, zone) in zones.enumerated() {
            var updatedZone = zone
            updatedZone.sortOrder = index
            updateZone(updatedZone)
        }
    }
    
    // MARK: - Validation
    
    func isZoneNameAvailable(_ name: String, excluding zoneId: String? = nil) -> Bool {
        return !zones.contains { zone in
            zone.name.lowercased() == name.lowercased() && zone.id != zoneId
        }
    }
    
    func isDisplayNameAvailable(_ displayName: String, excluding zoneId: String? = nil) -> Bool {
        return !zones.contains { zone in
            zone.displayName.lowercased() == displayName.lowercased() && zone.id != zoneId
        }
    }
}
