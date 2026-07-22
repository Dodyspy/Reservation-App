import SwiftUI

struct SwipeableReservationCard: View {
    let reservation: Reservation
    @ObservedObject var viewModel: ReservationViewModel
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showingDetail = false
    @State private var showingStatusDialog = false
    
    private let actionWidth: CGFloat = 75
    private let swipeThreshold: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Background actions (revealed when swiping left)
            HStack(spacing: 0) {
                Spacer()
                
                // Call action
                Button(action: {
                    if let url = URL(string: "tel://\(reservation.phone)") {
                        UIApplication.shared.open(url)
                    }
                    withAnimation {
                        resetSwipe()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 18))
                        Text("Call")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(reservation.phone.isEmpty)
                .opacity(reservation.phone.isEmpty ? 0.5 : 1)
                
                // Email action
                Button(action: {
                    if let url = URL(string: "mailto:\(reservation.email)") {
                        UIApplication.shared.open(url)
                    }
                    withAnimation {
                        resetSwipe()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                        Text("Email")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.orange)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(reservation.email.isEmpty)
                .opacity(reservation.email.isEmpty ? 0.5 : 1)
                
                // Cancel action
                Button(action: {
                    viewModel.updateReservationStatus(reservation: reservation, status: .cancelled)
                    withAnimation {
                        resetSwipe()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Cancel")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(reservation.status == .cancelled)
                .opacity(reservation.status == .cancelled ? 0.5 : 1)
                
                // Info/Detail action
                Button(action: {
                    showingDetail = true
                    withAnimation {
                        resetSwipe()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                        Text("Détails")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.purple)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Main card content
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
                            
                            // VIP Badge
                            if isVIPCustomer() {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text("VIP")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                            }
                            
                            // Large Party Alert (8+ people)
                            if reservation.numberOfPeople >= 8 {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.3.fill")
                                        .font(.system(size: 8))
                                    Text("GRAND GROUPE")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                            }
                            
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
            .background(AppTheme.darkGray)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow left swipe (negative offset)
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        } else if isSwiped {
                            // Allow right swipe to close
                            offset = gesture.translation.width - totalActionWidth()
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if gesture.translation.width < -swipeThreshold {
                                // Swipe left to reveal actions
                                offset = -totalActionWidth()
                                isSwiped = true
                            } else if gesture.translation.width > swipeThreshold && isSwiped {
                                // Swipe right to close
                                resetSwipe()
                            } else {
                                // Return to previous state
                                offset = isSwiped ? -totalActionWidth() : 0
                            }
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        if !isSwiped {
                            showingStatusDialog = true
                        }
                    }
            )
        }
        .frame(height: 70)
        .confirmationDialog("Modifier le statut", isPresented: $showingStatusDialog, titleVisibility: .visible) {
            if reservation.status != .confirmed {
                Button("Confirmée ✓") {
                    viewModel.updateReservationStatus(reservation: reservation, status: .confirmed)
                }
            }
            if reservation.status != .arrived {
                Button("Arrivé ✓") {
                    viewModel.updateReservationStatus(reservation: reservation, status: .arrived)
                }
            }
            if reservation.status != .completed {
                Button("Terminé ✓") {
                    viewModel.updateReservationStatus(reservation: reservation, status: .completed)
                }
            }
            if reservation.status != .noShow {
                Button("No-show 🚩") {
                    viewModel.updateReservationStatus(reservation: reservation, status: .noShow)
                }
            }
            if reservation.status != .cancelled {
                Button("Annulée", role: .destructive) {
                    viewModel.updateReservationStatus(reservation: reservation, status: .cancelled)
                }
            }
            Button("Retour", role: .cancel) {}
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                ReservationDetailView(reservation: reservation, viewModel: viewModel)
            }
        }
    }
    
    private func totalActionWidth() -> CGFloat {
        // 4 buttons: Call, Email, Cancel, Details
        return actionWidth * 4
    }
    
    private func resetSwipe() {
        offset = 0
        isSwiped = false
    }
    
    // Check if customer is VIP (has 3+ reservations)
    private func isVIPCustomer() -> Bool {
        // This would ideally check customer history from Firebase
        // For now, we can use a simple heuristic based on special requests or email domain
        if let requests = reservation.specialRequests?.lowercased() {
            return requests.contains("vip") || requests.contains("habitué")
        }
        return false
    }
}
