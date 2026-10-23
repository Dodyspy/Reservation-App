import SwiftUI
import Charts

struct DetailedAnalyticsView: View {
    let reservations: [Reservation]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAnalyticsTab: AnalyticsTab = .overview
    
    enum AnalyticsTab: String, CaseIterable {
        case overview = "Vue d'ensemble"
        case trends = "Tendances"
        case customers = "Clients"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar"
            case .trends: return "chart.line.uptrend.xyaxis"
            case .customers: return "person.3"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedAnalyticsTab = tab
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16))
                                
                                Text(tab.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(selectedAnalyticsTab == tab ? AppTheme.gold : AppTheme.cream.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .background(
                            Rectangle()
                                .fill(selectedAnalyticsTab == tab ? AppTheme.gold.opacity(0.1) : Color.clear)
                        )
                    }
                }
                .background(AppTheme.darkGray)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedAnalyticsTab {
                        case .overview:
                            OverviewAnalyticsView(reservations: reservations)
                        case .trends:
                            TrendsAnalyticsView(reservations: reservations)
                        case .customers:
                            CustomerAnalyticsView(reservations: reservations)
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Analyses détaillées")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
            }
        }
    }
}

// MARK: - Overview Analytics

struct OverviewAnalyticsView: View {
    let reservations: [Reservation]
    
    private var weeklyStats: [WeeklyData] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<4).compactMap { weekOffset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { return nil }
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return nil }
            
            let weekReservations = reservations.filter { reservation in
                reservation.date >= weekStart && reservation.date <= weekEnd
            }
            
            let weekFormatter = DateFormatter()
            weekFormatter.dateFormat = "dd/MM"
            
            return WeeklyData(
                week: "Sem. \(weekFormatter.string(from: weekStart))",
                reservations: weekReservations.count,
                guests: weekReservations.reduce(0) { $0 + $1.numberOfPeople }
            )
        }.reversed()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Revenue estimation
            RevenueEstimationCard(reservations: reservations)
            
            // Weekly trends
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(AppTheme.gold)
                    
                    Text("Évolution hebdomadaire")
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                }
                
                Chart(weeklyStats) { item in
                    LineMark(
                        x: .value("Semaine", item.week),
                        y: .value("Réservations", item.reservations)
                    )
                    .foregroundStyle(AppTheme.gold)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Semaine", item.week),
                        y: .value("Réservations", item.reservations)
                    )
                    .foregroundStyle(AppTheme.gold.opacity(0.2))
                }
                .frame(height: 120)
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
            
            // Peak hours analysis
            PeakHoursView(reservations: reservations)
        }
    }
}

struct WeeklyData: Identifiable {
    let id = UUID()
    let week: String
    let reservations: Int
    let guests: Int
}

// MARK: - Revenue Estimation

struct RevenueEstimationCard: View {
    let reservations: [Reservation]
    
    private var estimatedRevenue: Double {
        // Estimate based on average spend per person (€45 for Casanova d'Issy)
        let totalGuests = reservations.reduce(0) { $0 + $1.numberOfPeople }
        return Double(totalGuests) * 45.0
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundColor(AppTheme.gold)
                
                Text("Estimation du chiffre d'affaires")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            VStack(spacing: 8) {
                Text("€\(Int(estimatedRevenue))")
                    .font(.custom("Didot", size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.gold)
                
                Text("Basé sur €45 par personne en moyenne")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(reservations.reduce(0) { $0 + $1.numberOfPeople })")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.cream)
                        
                        Text("Couverts")
                            .font(.caption)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                    }
                    
                    VStack {
                        Text("\(reservations.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.cream)
                        
                        Text("Services")
                            .font(.caption)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
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
}

// MARK: - Peak Hours

struct PeakHoursView: View {
    let reservations: [Reservation]
    
    private var peakHour: String {
        let hourCounts = Dictionary(grouping: reservations) { reservation in
            String(reservation.time.prefix(2))
        }.mapValues { $0.count }
        
        return hourCounts.max(by: { $0.value < $1.value })?.key ?? "20"
    }
    
    private var averagePartySize: Double {
        guard !reservations.isEmpty else { return 0 }
        let totalGuests = reservations.reduce(0) { $0 + $1.numberOfPeople }
        return Double(totalGuests) / Double(reservations.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(AppTheme.gold)
                
                Text("Statistiques de service")
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heure de pointe")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.8))
                    
                    Text("\(peakHour):00")
                        .font(.custom("Didot", size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.gold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Taille moyenne")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.8))
                    
                    Text(String(format: "%.1f pers.", averagePartySize))
                        .font(.custom("Didot", size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.gold)
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

// MARK: - Trends Analytics (placeholder for future implementation)

struct TrendsAnalyticsView: View {
    let reservations: [Reservation]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Analyse des tendances")
                .font(.title2)
                .foregroundColor(AppTheme.gold)
            
            Text("Fonctionnalité en développement")
                .font(.subheadline)
                .foregroundColor(AppTheme.cream.opacity(0.7))
                .italic()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Customer Analytics (placeholder for future implementation)

struct CustomerAnalyticsView: View {
    let reservations: [Reservation]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Analyse clientèle")
                .font(.title2)
                .foregroundColor(AppTheme.gold)
            
            Text("Fonctionnalité en développement")
                .font(.subheadline)
                .foregroundColor(AppTheme.cream.opacity(0.7))
                .italic()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DetailedAnalyticsView(reservations: [])
        .withCasanovaTheme()
}
