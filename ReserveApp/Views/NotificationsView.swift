//
//  NotificationsView.swift
//  ReserveApp
//
//  Created by Cascade AI on 24/07/2025.
//

import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.newReservations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Aucune nouvelle notification")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("Les nouvelles réservations apparaîtront ici")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Notifications list
                    List {
                        Section {
                            ForEach(viewModel.newReservations) { reservation in
                                NotificationRowView(reservation: reservation)
                                    .onTapGesture {
                                        // Mark this notification as read and navigate to reservation
                                        viewModel.markNotificationAsRead(for: reservation.id ?? "")
                                        dismiss()
                                    }
                            }
                        } header: {
                            HStack {
                                Text("Nouvelles réservations")
                                Spacer()
                                Text("\\(viewModel.newReservations.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.gold)
                                    .foregroundColor(.black)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                if !viewModel.newReservations.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Tout marquer lu") {
                            viewModel.markAllNotificationsAsRead()
                            dismiss()
                        }
                        .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .withCasanovaTheme()
    }
}

struct NotificationRowView: View {
    let reservation: Reservation
    
    var body: some View {
        HStack(spacing: 12) {
            // Notification indicator
            Circle()
                .fill(AppTheme.gold)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                // Customer name and party size
                HStack {
                    Text(reservation.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(reservation.numberOfPeople) pers.")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                // Date and time
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(reservation.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    
                    Text(reservation.time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Customer contact info
                if !reservation.email.isEmpty {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(reservation.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Time since notification
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(timeAgoString(from: reservation.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack {
                Circle()
                    .fill(statusColor(for: reservation.status.rawValue))
                    .frame(width: 12, height: 12)
                
                Text(reservation.status.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "confirmed", "confirmé":
            return .green
        case "pending", "en attente":
            return .orange
        case "cancelled", "annulé":
            return .red
        default:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    private func timeAgoString(from date: Date?) -> String {
        guard let date = date else { return "À l'instant" }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "À l'instant"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Il y a \(minutes) min"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "Il y a \(hours) h"
        } else {
            let days = Int(timeInterval / 86400)
            return "Il y a \(days) j"
        }
    }
}

#Preview {
    NotificationsView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
