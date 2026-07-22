import SwiftUI

struct CustomerProfileView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var searchText = ""
    @State private var sortOption: CustomerSortOption = .name
    @State private var filterVIPStatus: Customer.VIPStatus?
    @State private var navigationPath = NavigationPath()
    
    enum CustomerSortOption: String, CaseIterable {
        case name = "Nom"
        case reservations = "Réservations"
        case lastVisit = "Dernière visite"
        case vipStatus = "Statut VIP"
        
        var icon: String {
            switch self {
            case .name: return "textformat.abc"
            case .reservations: return "number"
            case .lastVisit: return "clock"
            case .vipStatus: return "star"
            }
        }
    }
    
    private var customers: [Customer] {
        // Use Firebase customers if available, otherwise extract from reservations
        if !customerViewModel.customers.isEmpty {
            return customerViewModel.customers
        } else {
            let uniqueEmails = Set(viewModel.reservations.map { $0.email })
            return uniqueEmails.compactMap { email in
                createCustomerFromReservations(email: email)
            }
        }
    }
    
    private var filteredAndSortedCustomers: [Customer] {
        var filtered = customers
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { customer in
                customer.primary_email.localizedCaseInsensitiveContains(searchText) ||
                (customer.primary_name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                customer.primary_phone.contains(searchText)
            }
        }
        
        // Apply VIP status filter
        if let vipFilter = filterVIPStatus {
            filtered = filtered.filter { $0.vip_status == vipFilter }
        }
        
        // Apply sorting
        return filtered.sorted { customer1, customer2 in
            switch sortOption {
            case .name:
                return (customer1.primary_name ?? customer1.primary_email) < (customer2.primary_name ?? customer2.primary_email)
            case .reservations:
                return customer1.total_reservations > customer2.total_reservations
            case .lastVisit:
                return (customer1.updated_at ?? Date.distantPast) > (customer2.updated_at ?? Date.distantPast)
            case .vipStatus:
                let priority1 = vipPriority(customer1.vip_status)
                let priority2 = vipPriority(customer2.vip_status)
                return priority1 > priority2
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 15) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.gold)
                        
                        TextField("Rechercher clients...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(AppTheme.cream)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.darkGray)
                    )
                    
                    // Filter and sort controls
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Sort options
                            Menu {
                                ForEach(CustomerSortOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        sortOption = option
                                    }) {
                                        HStack {
                                            Image(systemName: option.icon)
                                            Text(option.rawValue)
                                            if sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(sortOption.rawValue)
                                }
                                .font(.caption)
                                .foregroundColor(AppTheme.gold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.gold, lineWidth: 1)
                                )
                            }
                            
                            // VIP status filter
                            Menu {
                                Button("Tous les clients") {
                                    filterVIPStatus = nil
                                }
                                
                                ForEach(Customer.VIPStatus.allCases, id: \.self) { status in
                                    Button(action: {
                                        filterVIPStatus = status
                                    }) {
                                        HStack {
                                            Image(systemName: status.icon)
                                            Text(status.displayName)
                                            if filterVIPStatus == status {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.circle")
                                    Text(filterVIPStatus?.displayName ?? "Tous")
                                }
                                .font(.caption)
                                .foregroundColor(AppTheme.gold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.gold, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(AppTheme.darkGray)
                
                // Customer list
                if filteredAndSortedCustomers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.cream.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "Aucun client trouvé" : "Aucun résultat pour '\(searchText)'")
                            .font(.headline)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredAndSortedCustomers, id: \.primary_email) { customer in
                            NavigationLink(value: customer) {
                                CustomerRowView(customer: customer)
                            }
                            .listRowBackground(AppTheme.darkGray.opacity(0.3))
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Exporter la liste") {
                            exportCustomerList()
                        }
                        
                        Button("Statistiques clients") {
                            // Show customer analytics
                        }
                        
                        Button("Synchroniser Firebase") {
                            // Refresh customer data
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
            .navigationDestination(for: Customer.self) { customer in
                CustomerDetailView(customer: customer, viewModel: viewModel, customerViewModel: customerViewModel)
            }
            .searchable(text: $searchText, prompt: "Rechercher par nom, email ou téléphone")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createCustomerFromReservations(email: String) -> Customer {
        let customerReservations = viewModel.reservations.filter { $0.email == email }
        let totalReservations = customerReservations.count
        let noShowCount = customerReservations.filter { $0.status == .noShow }.count
        
        // Get customer name from most recent reservation
        let _ = customerReservations.sorted { $0.date > $1.date }.first?.name
        let customerPhone = customerReservations.first?.phone ?? ""
        
        // Determine VIP status based on reservation history
        let _ : Customer.VIPStatus = {
            if noShowCount > 2 {
                return .blacklisted
            } else if totalReservations >= 10 {
                return .premium
            } else if totalReservations >= 5 {
                return .vip
            } else {
                return .regular
            }
        }()
        
        return Customer(
            primary_email: email,
            primary_phone: customerPhone,
            total_reservations: totalReservations,
            no_show_count: noShowCount,
            created_at: customerReservations.map { $0.date }.min(),
            updated_at: customerReservations.map { $0.date }.max()
        )
    }
    
    private func vipPriority(_ status: Customer.VIPStatus?) -> Int {
        switch status {
        case .premium: return 4
        case .vip: return 3
        case .regular: return 2
        case .blacklisted: return 1
        case .none: return 0
        }
    }
    
    private func exportCustomerList() {
        // Implementation for exporting customer data
        print("Exporting customer list...")
    }
}

// MARK: - Customer Row View

struct CustomerRowView: View {
    let customer: Customer
    
    private var customerReservations: [Reservation] {
        // This would be passed from parent or fetched from viewModel
        return []
    }
    
    var body: some View {
        HStack(spacing: 15) {
                // VIP status indicator
                VStack {
                    Image(systemName: customer.vip_status?.icon ?? Customer.VIPStatus.regular.icon)
                        .font(.title2)
                        .foregroundColor(vipStatusColor)
                    
                    if let vipStatus = customer.vip_status, vipStatus != .regular {
                        Text(vipStatus.displayName)
                            .font(.caption2)
                            .foregroundColor(vipStatusColor)
                    }
                }
                .frame(width: 50)
                
                // Customer info
                VStack(alignment: .leading, spacing: 6) {
                    Text(customer.primary_name ?? "Client")
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                    
                    Text(customer.primary_email)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.8))
                    
                    if !customer.primary_phone.isEmpty {
                        Text(customer.primary_phone)
                            .font(.caption)
                            .foregroundColor(AppTheme.cream.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(customer.total_reservations)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.gold)
                    
                    Text("réservations")
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.6))
                    
                    if customer.no_show_count > 0 {
                        Text("\(customer.no_show_count) no-show\(customer.no_show_count > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.vertical, 8)
    }
    
    private var vipStatusColor: Color {
        switch customer.vip_status {
        case .premium: return .purple
        case .vip: return AppTheme.gold
        case .blacklisted: return .red
        case .regular, .none: return AppTheme.cream.opacity(0.6)
        }
    }
}

// MARK: - Customer Detail View

struct CustomerDetailView: View {
    let customer: Customer
    @ObservedObject var viewModel: ReservationViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditCustomer = false
    @State private var showingAddNote = false
    @State private var showingDeleteAlert = false
    @State private var newNote = ""
    
    init(customer: Customer, viewModel: ReservationViewModel, customerViewModel: CustomerViewModel) {
        self.customer = customer
        self.viewModel = viewModel
        self.customerViewModel = customerViewModel
        print("✅ CustomerDetailView initialized for: \(customer.primary_email)")
    }
    
    private var customerReservations: [Reservation] {
        // Include ALL reservations (including canceled ones)
        viewModel.reservations.filter { $0.email == customer.primary_email }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ScrollView {
                VStack(spacing: 25) {
                    // Customer header
                    VStack(spacing: 15) {
                        // VIP status and avatar
                        VStack(spacing: 10) {
                            Image(systemName: customer.vip_status?.icon ?? Customer.VIPStatus.regular.icon)
                                .font(.system(size: 40))
                                .foregroundColor(vipStatusColor)
                            
                            Text(customer.primary_name ?? "Client")
                                .font(.custom("Didot", size: 24))
                                .foregroundColor(AppTheme.cream)
                            
                            if let vipStatus = customer.vip_status {
                                Text(vipStatus.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(vipStatusColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(vipStatusColor.opacity(0.2))
                                    )
                            }
                        }
                        
                        // Contact info with clickable buttons
                        VStack(spacing: 8) {
                            Button(action: {
                                if let url = URL(string: "mailto:\(customer.primary_email)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(AppTheme.gold)
                                    Text(customer.primary_email)
                                        .foregroundColor(AppTheme.cream)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(AppTheme.gold.opacity(0.6))
                                        .font(.caption)
                                }
                            }
                            
                            if !customer.primary_phone.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "tel:\(customer.primary_phone)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "phone.fill")
                                            .foregroundColor(AppTheme.gold)
                                        Text(customer.primary_phone)
                                            .foregroundColor(AppTheme.cream)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundColor(AppTheme.gold.opacity(0.6))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.darkGray)
                    )
                    
                    // Statistics cards
                    HStack(spacing: 15) {
                        StatCard(
                            title: "Réservations",
                            value: "\(customer.total_reservations)",
                            icon: "calendar.badge.plus",
                            color: AppTheme.gold
                        )
                        
                        StatCard(
                            title: "No-shows",
                            value: "\(customer.no_show_count)",
                            icon: "calendar.badge.minus",
                            color: customer.no_show_count > 0 ? .red : .green
                        )
                        
                        StatCard(
                            title: "Fidélité",
                            value: loyaltyScore,
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                    
                    // Recent reservations
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Réservations récentes")
                            .font(.custom("Didot", size: 18))
                            .foregroundColor(AppTheme.gold)
                        
                        if customerReservations.isEmpty {
                            Text("Aucune réservation trouvée")
                                .foregroundColor(AppTheme.cream.opacity(0.6))
                                .italic()
                        } else {
                            ForEach(customerReservations.prefix(5)) { reservation in
                                CustomerReservationRow(reservation: reservation)
                            }
                            
                            if customerReservations.count > 5 {
                                Button("Voir toutes les réservations (\(customerReservations.count))") {
                                    // Show all reservations
                                }
                                .foregroundColor(AppTheme.gold)
                                .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.darkGray)
                    )
                    
                    // Customer preferences (if available)
                    if let preferences = customer.preferences {
                        CustomerPreferencesCard(preferences: preferences)
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes")
                            .font(.custom("Didot", size: 18))
                            .foregroundColor(AppTheme.gold)
                        
                        Text(customer.notes ?? "Aucune note")
                            .foregroundColor(customer.notes != nil ? AppTheme.cream : AppTheme.cream.opacity(0.6))
                            .italic(customer.notes == nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.darkGray)
                    )
                }
                .padding()
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Profil Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Modifier le profil") {
                            showingEditCustomer = true
                        }
                        
                        Button("Ajouter une note") {
                            showingAddNote = true
                        }
                        
                        Button("Changer statut VIP") {
                            // Quick VIP status change
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Supprimer le client", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        .sheet(isPresented: $showingEditCustomer) {
            EditCustomerView(customer: customer, customerViewModel: customerViewModel)
        }
        .sheet(isPresented: $showingAddNote) {
            AddCustomerNoteView(customer: customer, customerViewModel: customerViewModel, newNote: $newNote)
        }
        .alert("Supprimer le client", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteCustomer()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer \(customer.primary_name ?? customer.primary_email) ? Cette action est irréversible.")
        }
    }
    
    private func deleteCustomer() {
        customerViewModel.deleteCustomer(customer)
        dismiss()
    }
    
    // MARK: - Helper Properties
    
    private var vipStatusColor: Color {
        switch customer.vip_status {
        case .premium: return .purple
        case .vip: return AppTheme.gold
        case .blacklisted: return .red
        case .regular, .none: return AppTheme.cream.opacity(0.6)
        }
    }
    
    private var loyaltyScore: String {
        let score = max(0, customer.total_reservations - customer.no_show_count)
        return "\(score)%"
    }
    
    // MARK: - Helper Methods
    
    private func saveCustomerChanges() {
        // This method is no longer needed - editing is handled by EditCustomerView
        print("Customer editing handled by EditCustomerView...")
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.cream)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.cream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.darkGray)
        )
    }
}

struct CustomerReservationRow: View {
    let reservation: Reservation
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: reservation.date))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream)
                
                Text("\(reservation.numberOfPeople) personnes • \(reservation.time)")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
            }
            
            Spacer()
            
            Text(reservation.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor.opacity(0.2))
                )
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch reservation.status {
        case .confirmed: return .green
        case .arrived: return .blue
        case .pending: return .orange
        case .cancelled: return .red
        case .noShow: return .red
        case .completed: return .gray
        }
    }
}

struct CustomerPreferencesCard: View {
    let preferences: Customer.CustomerPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Préférences")
                .font(.custom("Didot", size: 18))
                .foregroundColor(AppTheme.gold)
            
            VStack(alignment: .leading, spacing: 10) {
                if let seating = preferences.preferred_seating {
                    PreferenceRow(
                        icon: seating.icon,
                        title: "Placement préféré",
                        value: seating.displayName
                    )
                }
                
                if let restrictions = preferences.dietary_restrictions, !restrictions.isEmpty {
                    PreferenceRow(
                        icon: "leaf.fill",
                        title: "Restrictions alimentaires",
                        value: restrictions.joined(separator: ", ")
                    )
                }
                
                if let allergies = preferences.allergies, !allergies.isEmpty {
                    PreferenceRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Allergies",
                        value: allergies.joined(separator: ", ")
                    )
                }
                
                if let communication = preferences.communication_preference {
                    PreferenceRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Communication",
                        value: communication.displayName
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(AppTheme.darkGray)
        )
    }
}

struct PreferenceRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.gold)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream)
            }
            
            Spacer()
        }
    }
}

#Preview {
    CustomerProfileView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
