import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @State private var selectedTimeframe: TimeFrame = .today
    @State private var showingDetailedStats = false
    
    enum TimeFrame: String, CaseIterable {
        case today = "Aujourd'hui"
        case week = "Cette semaine"
        case month = "Ce mois"
        
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "fr_FR")
            calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
            calendar.firstWeekday = 2
            return calendar
        }
        
        func interval(containing date: Date = Date()) -> DateInterval {
            let component: Calendar.Component = self == .today ? .day : self == .week ? .weekOfYear : .month
            return Self.calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 86_400)
        }
        
        var periodLabel: String {
            let interval = interval()
            let lastDay = interval.end.addingTimeInterval(-1)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = Self.calendar.timeZone
            switch self {
            case .today:
                formatter.dateFormat = "EEEE d MMMM"
                return formatter.string(from: interval.start).capitalized
            case .week:
                formatter.dateFormat = "EEE d MMM"
                return "\(formatter.string(from: interval.start)) – \(formatter.string(from: lastDay))"
            case .month:
                formatter.dateFormat = "LLLL yyyy"
                return formatter.string(from: interval.start).capitalized
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with timeframe selector
                    VStack(spacing: 15) {
                        Text("Tableau de Bord")
                            .font(.custom("Didot", size: 28))
                            .foregroundColor(AppTheme.gold)
                            .padding(.top)
                        
                        Picker("Période", selection: $selectedTimeframe) {
                            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                                Text(timeframe.rawValue).tag(timeframe)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .background(AppTheme.darkGray)
                        .cornerRadius(8)
                        
                        Text(selectedTimeframe.periodLabel)
                            .font(.caption)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Key metrics cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        MetricCard(
                            title: "Réservations",
                            value: "\(getFilteredReservations().count)",
                            icon: "calendar.badge.plus",
                            color: AppTheme.gold
                        )
                        
                        MetricCard(
                            title: "Couverts",
                            value: "\(getTotalGuests())",
                            icon: "person.2.fill",
                            color: .blue
                        )
                        
                        MetricCard(
                            title: "Confirmées",
                            value: "\(getConfirmedReservations().count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        MetricCard(
                            title: "En attente",
                            value: "\(getPendingReservations().count)",
                            icon: "clock.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Today's schedule overview (only when viewing today)
                    if selectedTimeframe == .today {
                        TodayScheduleView(reservations: getTodayReservations())
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Tableau de bord")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Data Filtering Methods
    
    private func getFilteredReservations() -> [Reservation] {
        let interval = selectedTimeframe.interval()
        return viewModel.reservations.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    
    private func getTodayReservations() -> [Reservation] {
        let calendar = Calendar.current
        return viewModel.reservations.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
            .sorted { $0.time < $1.time }
    }
    
    private func getTotalGuests() -> Int {
        getFilteredReservations().reduce(0) { $0 + $1.numberOfPeople }
    }
    
    private func getConfirmedReservations() -> [Reservation] {
        getFilteredReservations().filter { $0.status == .confirmed }
    }
    
    private func getPendingReservations() -> [Reservation] {
        getFilteredReservations().filter { $0.status == .pending }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.custom("Didot", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.cream)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.darkGray)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.anthracite.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Today's Schedule View

struct TodayScheduleView: View {
    let reservations: [Reservation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Planning d'aujourd'hui")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
                
                Spacer()
                
                Text("\(reservations.count) services")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
            }
            
            if reservations.isEmpty {
                Text("Aucune réservation aujourd'hui")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream.opacity(0.6))
                    .italic()
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(reservations) { reservation in
                            TimeSlotCard(reservation: reservation)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(AppTheme.darkGray)
                .shadow(color: AppTheme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct TimeSlotCard: View {
    let reservation: Reservation
    
    var body: some View {
        VStack(spacing: 8) {
            Text(reservation.time)
                .font(.custom("Didot", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.gold)
            
            Text(reservation.name)
                .font(.caption)
                .foregroundColor(AppTheme.cream)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                
                Text("\(reservation.numberOfPeople)")
                    .font(.caption2)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
            }
            
            Circle()
                .fill(statusColor(for: reservation.status))
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.anthracite)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(width: 80)
    }
    
    private func statusColor(for status: ReservationStatus) -> Color {
        switch status {
        case .confirmed: return .green
        case .arrived: return .blue
        case .pending: return .orange
        case .cancelled: return .red
        case .completed: return .gray
        case .noShow: return .red
        }
    }
}

// MARK: - Charts and Analytics

struct ReservationsByTimeChart: View {
    let reservations: [Reservation]
    
    private var timeSlotData: [TimeSlotData] {
        let timeSlots = ["18:00", "18:30", "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00"]
        
        return timeSlots.map { timeSlot in
            let count = reservations.filter { $0.time.hasPrefix(timeSlot.prefix(5)) }.count
            return TimeSlotData(time: timeSlot, count: count)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Réservations par créneau")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            Chart(timeSlotData) { item in
                BarMark(
                    x: .value("Heure", item.time),
                    y: .value("Réservations", item.count)
                )
                .foregroundStyle(AppTheme.gold.gradient)
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppTheme.cream.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.cream.opacity(0.7))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.cream.opacity(0.7))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(AppTheme.darkGray)
                .shadow(color: AppTheme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct TimeSlotData: Identifiable {
    let id = UUID()
    let time: String
    let count: Int
}

// MARK: - Status Distribution

struct StatusDistributionView: View {
    let reservations: [Reservation]
    
    private var statusData: [StatusData] {
        let statuses: [ReservationStatus] = [.confirmed, .pending, .completed, .cancelled]
        
        return statuses.map { status in
            let count = reservations.filter { $0.status == status }.count
            return StatusData(status: status, count: count)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Répartition des statuts")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            VStack(spacing: 12) {
                ForEach(statusData, id: \.status) { item in
                    HStack {
                        Circle()
                            .fill(colorForStatus(item.status))
                            .frame(width: 12, height: 12)
                        
                        Text(item.status.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.gold)
                        
                        if reservations.count > 0 {
                            Text("(\(Int(Double(item.count) / Double(reservations.count) * 100))%)")
                                .font(.caption)
                                .foregroundColor(AppTheme.cream.opacity(0.7))
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
    }
    
    private func colorForStatus(_ status: ReservationStatus) -> Color {
        switch status {
        case .confirmed: return .green
        case .arrived: return .blue
        case .pending: return .orange
        case .cancelled: return .red
        case .completed: return .gray
        case .noShow: return .red
        }
    }
}

struct StatusData {
    let status: ReservationStatus
    let count: Int
}

// MARK: - Top Customers

struct TopCustomersView: View {
    let reservations: [Reservation]
    
    private var topCustomers: [CustomerData] {
        let customerCounts = Dictionary(grouping: reservations, by: { $0.email })
            .mapValues { $0.count }
        
        return customerCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { CustomerData(email: $0.key, reservationCount: $0.value, name: getCustomerName(for: $0.key)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Meilleurs clients")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            if topCustomers.isEmpty {
                Text("Aucune donnée client disponible")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream.opacity(0.6))
                    .italic()
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topCustomers.enumerated()), id: \.offset) { index, customer in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.gold)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(customer.name)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.cream)
                                
                                Text(customer.email)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.cream.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Text("\(customer.reservationCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.gold)
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
    }
    
    private func getCustomerName(for email: String) -> String {
        return reservations.first { $0.email == email }?.name ?? "Client inconnu"
    }
}

struct CustomerData {
    let email: String
    let reservationCount: Int
    let name: String
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    @ObservedObject var viewModel: ReservationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Actions rapides")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "Actualiser",
                    icon: "arrow.clockwise",
                    color: .blue
                ) {
                    viewModel.fetchReservations()
                }
                
                QuickActionButton(
                    title: "Notifications",
                    icon: "bell.fill",
                    color: .orange
                ) {
                    // This would open notifications view
                }
                
                QuickActionButton(
                    title: "Paramètres",
                    icon: "gear",
                    color: .gray
                ) {
                    // This would open settings
                }
                
                QuickActionButton(
                    title: "Exporter",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    // This would export data
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(AppTheme.darkGray)
                .shadow(color: AppTheme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.cream)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.anthracite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DashboardView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
