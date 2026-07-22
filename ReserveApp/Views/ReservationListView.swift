import SwiftUI
import FirebaseFirestore

struct ReservationListView: View {
    @StateObject private var viewModel = ReservationViewModel()
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingLogo = false
    // Removed showAllReservations - always filter by date
    @State private var showNotifications = false
    @State private var selectedTab: MainTab = .reservations
    @State private var showingDisconnectAlert = false
    @State private var showingTestReservation = false
    @State private var showingAddReservation = false
    @State private var selectedService: ServiceFilter = .all
    
    // Service status for selected date
    @State private var lunchStatus: ServiceStatus?
    @State private var dinnerStatus: ServiceStatus?
    @State private var isLoadingServiceStatus = false
    @State private var showingServiceAlert = false
    @State private var serviceAlertMessage = ""
    @State private var showingServiceEdit = false
    @State private var editingService: ServiceType = .lunch
    
    enum ServiceFilter: String, CaseIterable {
        case midi = "Midi"
        case soir = "Soir"
        case all = "Tous"
    }
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    @EnvironmentObject var notificationHandler: NotificationHandler
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath = NavigationPath()
    @State private var reservationToShow: Reservation?
    
    enum MainTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case reservations = "Réservations"
        case calendar = "Calendrier"
        case tables = "Tables"
        case customers = "Clients"
        case settings = "Réglages"
        
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .reservations: return "list.bullet"
            case .calendar: return "calendar"
            case .tables: return "table.furniture"
            case .customers: return "person.3.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd.MMM.yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: MainTab.dashboard.icon)
                    Text(MainTab.dashboard.rawValue)
                }
                .tag(MainTab.dashboard)
            
            // Reservations Tab
            NavigationView {
                ZStack {
                VStack {
                
                // Main content
                VStack(spacing: 20) {
                    // Restaurant Status Banner
                    RestaurantStatusBanner()
                    
                    // Header with date and controls
                    VStack(spacing: 15) {
                        // Current date display - always show since we always filter by date
                        VStack(spacing: 5) {
                            Text("Réservations du")
                                .font(.caption)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(1)
                                
                                ZStack {
                                    // Left arrow - fixed position
                                    HStack {
                                        Button(action: {
                                            if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                                                selectedDate = newDate
                                            }
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(AppTheme.gold)
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppTheme.anthracite.opacity(0.3))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(AppTheme.gold.opacity(0.5), lineWidth: 1)
                                                )
                                        }
                                        Spacer()
                                    }
                                    
                                    // Date display - centered (non-clickable)
                                    Text(dateFormatter.string(from: selectedDate))
                                        .font(.custom("Didot", size: 18))
                                        .foregroundColor(AppTheme.gold)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.gold, lineWidth: 1)
                                        )
                                    
                                    // Right arrow - fixed position
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                                                selectedDate = newDate
                                            }
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(AppTheme.gold)
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppTheme.anthracite.opacity(0.3))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(AppTheme.gold.opacity(0.5), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Service filter (Midi/Soir/Tous) - Redesigned
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Réservations")
                                .font(.caption)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(1.5)
                            
                            HStack(spacing: 10) {
                                ForEach(ServiceFilter.allCases, id: \.self) { service in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedService = service
                                        }
                                    }) {
                                        Text(service.rawValue)
                                            .font(.system(size: 15, weight: selectedService == service ? .bold : .medium))
                                            .foregroundColor(selectedService == service ? AppTheme.anthracite : AppTheme.cream.opacity(0.9))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedService == service ? 
                                                        LinearGradient(gradient: Gradient(colors: [AppTheme.gold, AppTheme.gold.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                                        LinearGradient(gradient: Gradient(colors: [AppTheme.darkGray, AppTheme.darkGray]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedService == service ? AppTheme.gold : AppTheme.cream.opacity(0.2), lineWidth: selectedService == service ? 2 : 1)
                                            )
                                            .shadow(color: selectedService == service ? AppTheme.gold.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.darkGray)
                            .shadow(color: AppTheme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // SERVICE STATUS CONTROLS - COMPACT LAYOUT
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            // Lunch Service
                            Button(action: {
                                editingService = .lunch
                                showingServiceEdit = true
                            }) {
                                VStack(alignment: .center, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("Déjeuner")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppTheme.cream)
                                        Text("12h-15h")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.cream.opacity(0.6))
                                    }
                                    
                                    if let status = lunchStatus {
                                        Text(status.isClosed ? "Fermé" : "Ouvert")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(status.isClosed ? .red : .green)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.anthracite.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Dinner Service
                            Button(action: {
                                editingService = .dinner
                                showingServiceEdit = true
                            }) {
                                VStack(alignment: .center, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("Dîner")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppTheme.cream)
                                        Text("19h-23h")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.cream.opacity(0.6))
                                    }
                                    
                                    if let status = dinnerStatus {
                                        Text(status.isClosed ? "Fermé" : "Ouvert")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(status.isClosed ? .red : .green)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.anthracite.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    // Date picker with elegant styling
                    if showingDatePicker {
                        VStack(spacing: 10) {
                            Text("Sélectionner une date")
                                .font(.headline)
                                .foregroundColor(AppTheme.gold)
                            
                            DatePicker(
                                "Select Date",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .accentColor(AppTheme.gold)
                            .onChange(of: selectedDate) { _ in
                                withAnimation(.easeInOut) {
                                    showingDatePicker = false
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(AppTheme.darkGray)
                                .shadow(color: AppTheme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                    }
                
                if viewModel.isLoading {
                    ProgressView("Loading reservations...")
                        .padding()
                        .tint(AppTheme.gold)
                } else if let error = viewModel.error {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            viewModel.fetchReservations()
                        }
                        .padding()
                        .background(AppTheme.gold)
                        .foregroundColor(AppTheme.anthracite)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    // Always filter by selected date
                    let dateFilteredReservations = viewModel.getReservationsForDate(selectedDate)
                    let displayedReservations = filterByService(dateFilteredReservations)
                    
                    if displayedReservations.isEmpty {
                        VStack(spacing: 25) {
                            Image(systemName: "calendar")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.gold.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Aucune réservation")
                                    .font(.custom("Didot", size: 20))
                                    .foregroundColor(AppTheme.cream)
                                    .multilineTextAlignment(.center)
                                
                                Text("Essayez une autre date ou service")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.cream.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Enhanced reservation list
                        VStack(spacing: 15) {
                            // List header with count and refresh
                            HStack {
                                Text("\(displayedReservations.count) réservation\(displayedReservations.count > 1 ? "s" : "")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.cream.opacity(0.8))
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.fetchReservations()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(AppTheme.gold)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            List {
                                ForEach(displayedReservations) { reservation in
                                    SwipeableReservationCard(reservation: reservation, viewModel: viewModel)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                            .refreshable {
                                viewModel.fetchReservations()
                            }
                        }
                    }
                }
            }
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        // Notification indicator
                        if viewModel.newReservationCount > 0 {
                            Button(action: {
                                showNotifications = true
                            }) {
                                ZStack {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.gold)
                                    
                                    // Badge with count
                                    Text("\(viewModel.newReservationCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                            .accessibilityLabel("\(viewModel.newReservationCount) nouvelles réservations")
                        }

                        // Test reservation button (only for DEMO2024) - moved from deleted add button
                        if restaurantManager.restaurantCode == "DEMO2024" {
                            Button(action: {
                                showingTestReservation = true
                            }) {
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                            .accessibilityLabel("Créer une réservation test")
                        }
                    }
                }
            }
            .overlay(
                // Floating Add Reservation Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddReservation = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                Text("Ajouter")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(AppTheme.anthracite)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(AppTheme.gold)
                                    .shadow(color: AppTheme.gold.opacity(0.4), radius: 10, x: 0, y: 5)
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            )
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: MainTab.reservations.icon)
                Text(MainTab.reservations.rawValue)
            }
            .tag(MainTab.reservations)
            
            // Calendar Tab
            CalendarView(viewModel: viewModel) { date in
                // When user taps a date in calendar, switch to reservations tab and show that date
                selectedDate = date
                selectedTab = .reservations
            }
                .tabItem {
                    Image(systemName: MainTab.calendar.icon)
                    Text(MainTab.calendar.rawValue)
                }
                .tag(MainTab.calendar)
            
            // Customer Profile Tab
            CustomerProfileView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: MainTab.customers.icon)
                    Text(MainTab.customers.rawValue)
                }
                .tag(MainTab.customers)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: MainTab.settings.icon)
                    Text(MainTab.settings.rawValue)
                }
                .tag(MainTab.settings)
        }
        .accentColor(AppTheme.gold)
        .sheet(isPresented: $showNotifications) {
            NotificationsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchReservations()
            loadServiceStatus()
            // Handle cold-start notification tap (app was killed when notification was tapped)
            if notificationHandler.shouldNavigateToReservation,
               let reservationId = notificationHandler.selectedReservationId {
                selectedTab = .reservations
                navigateToReservation(id: reservationId)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Only clear in-app badge if there's no pending notification navigation
                if !notificationHandler.shouldNavigateToReservation {
                    viewModel.markAllNotificationsAsRead()
                }
            }
        }
        .onChange(of: selectedDate) { _ in
            loadServiceStatus()
        }
        .alert(isPresented: $showingServiceAlert) {
            Alert(
                title: Text("Statut du Service"),
                message: Text(serviceAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingServiceEdit) {
            if editingService == .lunch {
                ServiceEditSheet(
                    date: selectedDate,
                    service: .lunch,
                    serviceStatus: Binding(
                        get: { lunchStatus ?? ServiceStatus(isClosed: false) },
                        set: { lunchStatus = $0 }
                    )
                )
            } else {
                ServiceEditSheet(
                    date: selectedDate,
                    service: .dinner,
                    serviceStatus: Binding(
                        get: { dinnerStatus ?? ServiceStatus(isClosed: false) },
                        set: { dinnerStatus = $0 }
                    )
                )
            }
        }
        .onReceive(notificationHandler.$shouldNavigateToReservation) { shouldNavigate in
            guard shouldNavigate, let reservationId = notificationHandler.selectedReservationId else { return }
            Logger.debug("🎯 Navigating to reservation: \(reservationId)")
            
            // Always switch to reservations tab first
            selectedTab = .reservations
            
            navigateToReservation(id: reservationId)
        }
        .onReceive(viewModel.$reservations) { _ in
            // If a notification tap is pending and reservations just loaded, navigate now
            if notificationHandler.shouldNavigateToReservation,
               let reservationId = notificationHandler.selectedReservationId {
                navigateToReservation(id: reservationId)
            }
        }
        .sheet(item: $reservationToShow) { reservation in
            NavigationView {
                ReservationDetailView(reservation: reservation, viewModel: viewModel)
            }
        }
        .alert("Déconnexion", isPresented: $showingDisconnectAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Déconnecter", role: .destructive) {
                disconnectFromRestaurant()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir vous déconnecter de \(restaurantManager.currentRestaurant?.name ?? "ce restaurant") ? Vous devrez saisir un nouveau code restaurant pour vous reconnecter.")
        }
        .sheet(isPresented: $showingTestReservation) {
            TestReservationView()
        }
        .sheet(isPresented: $showingAddReservation) {
            AddReservationView(viewModel: viewModel)
        }
    }
    
    private func disconnectFromRestaurant() {
        // Unsubscribe from current restaurant notifications
        if let restaurantCode = restaurantManager.restaurantCode {
            let topicName = "\(restaurantCode.lowercased())-reservations"
            NotificationService.shared.unsubscribeFromTopic(topicName)
        }
        
        // Clear restaurant data
        restaurantManager.clearCurrentRestaurant()
        
        // Clear any cached data
        viewModel.clearData()
    }
    
    // MARK: - Notification Navigation
    
    private func navigateToReservation(id reservationId: String) {
        if let reservation = viewModel.reservations.first(where: { $0.id == reservationId }) {
            Logger.debug("✅ Found reservation: \(reservation.name) on \(reservation.date)")
            selectedDate = reservation.date
            reservationToShow = reservation
            // Navigation succeeded — clear the pending flag and badge
            notificationHandler.resetNavigation()
            viewModel.markAllNotificationsAsRead()
        } else {
            Logger.debug("⏳ Reservation not yet loaded, waiting for Firestore listener...")
            // Don't reset notificationHandler here — onReceive(viewModel.$reservations)
            // will call this function again once data arrives.
            // Trigger a fetch in case the listener isn't active yet.
            viewModel.fetchReservations()
        }
    }
    
    // Filter reservations by service (Midi/Soir/All)
    private func filterByService(_ reservations: [Reservation]) -> [Reservation] {
        switch selectedService {
        case .all:
            return reservations
        case .midi:
            return reservations.filter { reservation in
                let hour = Int(reservation.time.prefix(2)) ?? 0
                return hour >= 12 && hour < 15
            }
        case .soir:
            return reservations.filter { reservation in
                let hour = Int(reservation.time.prefix(2)) ?? 0
                return hour >= 19 && hour < 23
            }
        }
    }
    
    // MARK: - Service Status Management
    
    private func loadServiceStatus() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            Logger.debug("❌ No restaurant document ID found")
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: selectedDate).prefix(10)
        
        isLoadingServiceStatus = true
        
        // First check if entire day is closed via closedDates (backoffice compatibility)
        let db = Firestore.firestore()
        db.collection("restaurants")
            .document(restaurantId)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data() else {
                    self.loadPerServiceStatus(restaurantId: restaurantId, dateString: String(dateString))
                    return
                }
                
                // Check closedDates array (backoffice format)
                if let closedDates = data["closedDates"] as? [[String: Any]] {
                    let isDateClosed = closedDates.contains { closedDate in
                        if let date = closedDate["date"] as? String {
                            return date == dateString
                        }
                        return false
                    }
                    
                    if isDateClosed {
                        // Entire day closed - close both services
                        let closedDateInfo = closedDates.first(where: { ($0["date"] as? String) == String(dateString) })
                        let reason = closedDateInfo?["reason"] as? String
                        DispatchQueue.main.async {
                            self.lunchStatus = ServiceStatus(isClosed: true, reason: reason)
                            self.dinnerStatus = ServiceStatus(isClosed: true, reason: reason)
                            self.isLoadingServiceStatus = false
                        }
                        return
                    }
                }
                
                // No full-day closure, check per-service status
                self.loadPerServiceStatus(restaurantId: restaurantId, dateString: String(dateString))
            }
    }
    
    private func loadPerServiceStatus(restaurantId: String, dateString: String) {
        // Load lunch status
        RestaurantService.shared.getServiceStatus(
            restaurantId: restaurantId,
            date: dateString,
            service: .lunch
        ) { [self] status, error in
            DispatchQueue.main.async {
                self.lunchStatus = status ?? ServiceStatus(isClosed: false)
            }
        }
        
        // Load dinner status
        RestaurantService.shared.getServiceStatus(
            restaurantId: restaurantId,
            date: dateString,
            service: .dinner
        ) { [self] status, error in
            DispatchQueue.main.async {
                self.dinnerStatus = status ?? ServiceStatus(isClosed: false)
                self.isLoadingServiceStatus = false
            }
        }
    }
    
}

struct ReservationRowView: View {
    let reservation: Reservation
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 0) {
            // Left status bar
            Rectangle()
                .fill(StatusBadgeView.statusColor(for: reservation.status))
                .frame(width: 4)

            HStack(spacing: 12) {
                // Center - Customer info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(reservation.name.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(reservation.status == .cancelled ? AppTheme.cream.opacity(0.5) : AppTheme.cream)
                            .strikethrough(reservation.status == .cancelled, color: .red)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        // Canceled badge
                        if reservation.status == .cancelled {
                            Text("ANNULÉ")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        
                        // Arrived badge
                        if reservation.status == .arrived {
                            Text("ARRIVÉ")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                        
                        // Finished badge
                        if reservation.status == .completed {
                            Text("TERMINÉ")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                        
                        // No Show red flag
                        if reservation.status == .noShow {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        Spacer()

                        // Time + guests on the right of first line
                        HStack(spacing: 6) {
                            Text(reservation.time)
                                .font(.custom("Didot", size: 16))
                                .foregroundColor(reservation.status == .cancelled ? AppTheme.gold.opacity(0.5) : AppTheme.gold)
                                .strikethrough(reservation.status == .cancelled, color: .red)

                            Text("\(reservation.numberOfPeople) pers")
                                .font(.caption)
                                .foregroundColor(reservation.status == .cancelled ? AppTheme.cream.opacity(0.4) : AppTheme.cream.opacity(0.8))
                        }
                    }

                    HStack(spacing: 10) {
                        if !reservation.phone.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.gold.opacity(0.8))

                                Text(reservation.phone)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.cream.opacity(0.6))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }

                        if let specialRequests = reservation.specialRequests, !specialRequests.isEmpty {
                            Text(specialRequests)
                                .font(.caption2)
                                .foregroundColor(AppTheme.cream.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer()

                        // Customer history icon at end of second line
                        CustomerHistoryBadge(reservation: reservation)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }
}

struct StatusBadgeView: View {
    let status: ReservationStatus
    
    var body: some View {
        // Compact color-only status indicator to free space for the name
        Circle()
            .fill(color(for: status))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .accessibilityLabel(Text(status.rawValue.capitalized))
    }
    
    // Instance helper for the small circle
    private func color(for status: ReservationStatus) -> Color {
        switch status {
        case .confirmed:
            return Color.green
        case .arrived:
            return Color.blue
        case .pending:
            return Color.orange
        case .cancelled:
            return Color.red
        case .noShow:
            return Color.red.opacity(0.8)
        case .completed:
            return Color.gray
        }
    }

    // Static helper used by list rows for the left status bar
    static func statusColor(for status: ReservationStatus) -> Color {
        return StatusBadgeView(status: status).color(for: status)
    }
}

#Preview {
    ReservationListView()
}
