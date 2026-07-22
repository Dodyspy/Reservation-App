import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @State private var selectedDate = Date()
    @State private var showingReservationDetail = false
    @State private var selectedReservation: Reservation?
    var onDateSelected: ((Date) -> Void)?
    
    private var displayedDates: [Date] {
        // Month-only calendar
        return getMonthDates(for: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with navigation (month only)
                VStack(spacing: 15) {
                    // Date navigation
                    HStack {
                        Button(action: {
                            navigateDate(direction: -1)
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppTheme.gold)
                        }
                        
                        Spacer()
                        
                        Text(headerTitle)
                            .font(.custom("Didot", size: 18))
                            .foregroundColor(AppTheme.cream)
                        
                        Spacer()
                        
                        Button(action: {
                            navigateDate(direction: 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.gold)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(20)
                .background(AppTheme.darkGray)
                
                // Calendar grid
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 1) {
                        // Calendar cells (month view only)
                        ForEach(displayedDates, id: \.self) { date in
                            CalendarDayCell(
                                date: date,
                                reservations: getReservationsForDate(date),
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                selectedDate = date
                                // Trigger callback to switch to reservations tab
                                onDateSelected?(date)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingReservationDetail) {
            if let reservation = selectedReservation {
                ReservationDetailView(reservation: reservation, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var gridColumns: [GridItem] {
        // 7 columns for month view
        return Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    }
    
    private var headerTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate).capitalized
    }
    
    private func navigateDate(direction: Int) {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) ?? selectedDate
    }
    
    private func getMonthDates(for date: Date) -> [Date] {
        let calendar = Calendar.current
        
        guard let _ = calendar.range(of: .day, in: .month, for: date),
              let monthStart = calendar.dateInterval(of: .month, for: date)?.start else {
            return []
        }
        
        // Get first day of calendar (might be from previous month)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromPreviousMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        guard let calendarStart = calendar.date(byAdding: .day, value: -daysFromPreviousMonth, to: monthStart) else {
            return []
        }
        
        // Generate 42 days (6 weeks) for complete calendar view
        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: calendarStart)
        }
    }
    
    
    private func getReservationsForDate(_ date: Date) -> [Reservation] {
        let calendar = Calendar.current
        return viewModel.reservations.filter { reservation in
            calendar.isDate(reservation.date, inSameDayAs: date)
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let reservations: [Reservation]
    let isSelected: Bool
    let onTap: () -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    private var totalGuests: Int {
        reservations.reduce(0) { $0 + $1.numberOfPeople }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day number
                Text(dayNumber)
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(dayTextColor)
                
                // Reservation indicators
                if !reservations.isEmpty {
                    // Compact view for month mode
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppTheme.gold)
                            .frame(width: 4, height: 4)
                        
                        if reservations.count > 1 {
                            Text("\(reservations.count)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.gold)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(cellBackground)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? AppTheme.gold : AppTheme.cream.opacity(0.1), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayTextColor: Color {
        if isToday {
            return AppTheme.gold
        } else if !isCurrentMonth {
            return AppTheme.cream.opacity(0.4)
        } else {
            return AppTheme.cream
        }
    }
    
    private var cellBackground: Color {
        if isSelected {
            return AppTheme.gold.opacity(0.2)
        } else if isToday {
            return AppTheme.gold.opacity(0.1)
        } else if !reservations.isEmpty {
            return AppTheme.darkGray.opacity(0.8)
        } else {
            return AppTheme.darkGray.opacity(0.3)
        }
    }
}

// MARK: - Day Detail View

struct DayDetailView: View {
    let date: Date
    let reservations: [Reservation]
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Date header
                VStack(spacing: 8) {
                    Text(dateFormatter.string(from: date))
                        .font(.custom("Didot", size: 20))
                        .foregroundColor(AppTheme.gold)
                    
                    Text("\(reservations.count) réservation\(reservations.count > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.8))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.darkGray)
                )
                
                // Reservations list
                if reservations.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.cream.opacity(0.5))
                        
                        Text("Aucune réservation")
                            .font(.headline)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(reservations.sorted { $0.time < $1.time }) { reservation in
                            ReservationRowView(reservation: reservation)
                                .listRowBackground(AppTheme.darkGray.opacity(0.3))
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                }
                
                Spacer()
            }
            .padding()
            .background(AppTheme.anthracite)
            .navigationTitle("Détail du jour")
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
    
    private func getWeekDates(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    private func getMonthDates(for date: Date) -> [Date] {
        let calendar = Calendar.current
        
        guard let _ = calendar.range(of: .day, in: .month, for: date),
              let monthStart = calendar.dateInterval(of: .month, for: date)?.start else {
            return []
        }
        
        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monthStart)
        }
    }
}

#Preview {
    CalendarView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
