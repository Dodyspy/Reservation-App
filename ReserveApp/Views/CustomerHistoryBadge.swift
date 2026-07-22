import SwiftUI

struct CustomerHistoryBadge: View {
    let reservation: Reservation
    @State private var customerHistory: CustomerHistory?
    @State private var isLoading = false
    @StateObject private var restaurantManager = RestaurantManager.shared
    
    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("...")
                        .font(.caption2)
                        .foregroundColor(AppTheme.cream.opacity(0.6))
                }
            } else if let history = customerHistory {
                CustomerHistoryView(history: history)
            } else {
                EmptyView()
            }
        }
        .task {
            guard !isLoading, customerHistory == nil else { return }
            guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
                isLoading = false
                return
            }
            isLoading = true
            RestaurantService.shared.getCustomerHistory(
                email: reservation.email,
                phone: reservation.phone,
                restaurantCode: restaurantId
            ) { history in
                Task { @MainActor in
                    self.customerHistory = history
                    self.isLoading = false
                }
            }
        }
    }
}

struct CustomerHistoryView: View {
    let history: CustomerHistory
    
    var body: some View {
        HStack(spacing: 6) {
            // Status icon and text
            HStack(spacing: 3) {
                Text(statusIcon)
                    .font(.caption2)
                
                Text(history.statusText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var statusIcon: String {
        if history.hasNoShows {
            return "⚠️"
        } else if history.isRepeatCustomer {
            return "🔄"
        } else {
            return "✨"
        }
    }
    
    private var statusColor: Color {
        if history.hasNoShows {
            return .red
        } else if history.isRepeatCustomer {
            return AppTheme.gold
        } else {
            return .green
        }
    }
    
    private var backgroundColor: Color {
        if history.hasNoShows {
            return Color.red.opacity(0.1)
        } else if history.isRepeatCustomer {
            return AppTheme.gold.opacity(0.1)
        } else {
            return Color.green.opacity(0.1)
        }
    }
}

// Detailed customer history view for reservation details
struct CustomerHistoryDetailView: View {
    let reservation: Reservation
    @State private var customerHistory: CustomerHistory?
    @State private var isLoading = true
    @StateObject private var restaurantManager = RestaurantManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historique Client")
                    .font(.headline)
                    .foregroundColor(AppTheme.gold)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let history = customerHistory {
                VStack(alignment: .leading, spacing: 8) {
                    // Customer status
                    HStack {
                        Text("Statut:")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream.opacity(0.8))
                        
                        Spacer()
                        
                        CustomerHistoryView(history: history)
                    }
                    
                    // Statistics
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Réservations Totales")
                                .font(.caption)
                                .foregroundColor(AppTheme.cream.opacity(0.7))
                            
                            Text("\(history.totalReservations)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.gold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("No-Shows")
                                .font(.caption)
                                .foregroundColor(AppTheme.cream.opacity(0.7))
                            
                            Text("\(history.noShowCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(history.hasNoShows ? .red : AppTheme.cream.opacity(0.6))
                        }
                    }
                    
                    // Warning for no-shows
                    if history.hasNoShows {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            
                            Text("Ce client a eu \(history.noShowCount) absence\(history.noShowCount > 1 ? "s" : "") sans annulation.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            } else if !isLoading {
                Text("Impossible de charger l'historique client")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.6))
                    .italic()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.darkGray.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                )
        )
        .task {
            guard customerHistory == nil else { return }
            guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
                isLoading = false
                return
            }
            RestaurantService.shared.getCustomerHistory(
                email: reservation.email,
                phone: reservation.phone,
                restaurantCode: restaurantId
            ) { history in
                Task { @MainActor in
                    self.customerHistory = history
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        CustomerHistoryView(history: CustomerHistory(customer: nil))
        CustomerHistoryView(history: CustomerHistory(customer: Customer(
            id: "test",
            primary_email: "test@example.com",
            primary_phone: "123456789",
            total_reservations: 5,
            no_show_count: 0,
            created_at: Date(),
            updated_at: Date()
        )))
        CustomerHistoryView(history: CustomerHistory(customer: Customer(
            id: "test2",
            primary_email: "test2@example.com",
            primary_phone: "987654321",
            total_reservations: 3,
            no_show_count: 2,
            created_at: Date(),
            updated_at: Date()
        )))
    }
    .padding()
    .background(AppTheme.anthracite)
}
