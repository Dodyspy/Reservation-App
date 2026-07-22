import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let restaurantManager = RestaurantManager.shared
    
    init() {
        setupFirestoreListener()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Firebase Operations
    
    private func setupFirestoreListener() {
        guard restaurantManager.restaurantCode != nil else {
            print("❌ No restaurant code available for customer loading")
            return
        }
        
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found")
            errorMessage = "Document ID manquant. Veuillez vous reconnecter."
            return
        }
        
        isLoading = true
        
        // Use restaurant-specific customer collection with document ID
        let collection = RestaurantService.shared.getCustomersCollection(for: restaurantId)
        
        listener = collection
            .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase error loading customers: \(error.localizedDescription)")
                    self.errorMessage = "Erreur de chargement des clients"
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No customers found in Firestore")
                    self.customers = []
                    self.isLoading = false
                    return
                }
                
                self.customers = documents.compactMap { doc in
                    do {
                        let customer = try doc.data(as: Customer.self)
                        return customer
                    } catch {
                        print("❌ Failed to decode customer \(doc.documentID): \(error)")
                        print("📄 Customer data: \(doc.data())")
                        return nil
                    }
                }
                print("✅ Loaded \(self.customers.count) customers from Firestore (out of \(documents.count) documents)")
                self.isLoading = false
            }
    }
    
    // MARK: - Customer Management
    
    func updateCustomer(_ customer: Customer) {
        guard let customerId = customer.id,
              restaurantManager.restaurantCode != nil,
              let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            errorMessage = "ID client manquant ou restaurant non configuré"
            return
        }
        
        var updatedCustomer = customer
        updatedCustomer.updated_at = Date()
        
        do {
            let collection = RestaurantService.shared.getCustomersCollection(for: restaurantId)
            try collection.document(customerId).setData(from: updatedCustomer)
            print("✅ Updated customer: \(customer.primary_email)")
        } catch {
            errorMessage = "Erreur lors de la mise à jour: \(error.localizedDescription)"
            print("❌ Failed to update customer: \(error)")
        }
    }
    
    func deleteCustomer(_ customer: Customer) {
        guard let customerId = customer.id,
              restaurantManager.restaurantCode != nil,
              let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            errorMessage = "ID client manquant ou restaurant non configuré"
            return
        }
        
        let collection = RestaurantService.shared.getCustomersCollection(for: restaurantId)
        collection.document(customerId).delete { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    self?.errorMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    print("❌ Failed to delete customer: \(error)")
                } else {
                    print("✅ Deleted customer: \(customer.primary_email)")
                }
            }
        }
    }
    
    func addCustomerNote(_ customer: Customer, note: String) {
        var updatedCustomer = customer
        let existingNotes = customer.notes ?? ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let newNote = "[\(dateFormatter.string(from: Date()))] \(note)"
        updatedCustomer.notes = existingNotes.isEmpty ? newNote : "\(existingNotes)\n\(newNote)"
        
        updateCustomer(updatedCustomer)
    }
    
    func updateVIPStatus(_ customer: Customer, status: Customer.VIPStatus) {
        var updatedCustomer = customer
        updatedCustomer.vip_status = status
        updateCustomer(updatedCustomer)
    }
    
    // MARK: - Search and Filter
    
    func searchCustomers(_ searchText: String) -> [Customer] {
        if searchText.isEmpty {
            return customers
        }
        
        return customers.filter { customer in
            customer.primary_email.localizedCaseInsensitiveContains(searchText) ||
            (customer.primary_name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            customer.primary_phone.contains(searchText)
        }
    }
    
    func filterByVIPStatus(_ status: Customer.VIPStatus?) -> [Customer] {
        guard let status = status else { return customers }
        return customers.filter { $0.vip_status == status }
    }
}
