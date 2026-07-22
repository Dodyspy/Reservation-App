import SwiftUI

struct TableManagementView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @State private var selectedLocation: Table.TableLocation = .interior
    @State private var showingTableAssignment = false
    @State private var selectedReservation: Reservation?
    @State private var tables: [Table] = RestaurantLayout.defaultTables
    
    private var filteredTables: [Table] {
        tables.filter { $0.location == selectedLocation }
    }
    
    private var todayReservations: [Reservation] {
        let calendar = Calendar.current
        return viewModel.reservations.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Table.TableLocation.allCases, id: \.self) { location in
                            LocationTab(
                                location: location,
                                isSelected: selectedLocation == location,
                                tableCount: tables.filter { $0.location == location }.count
                            ) {
                                selectedLocation = location
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 15)
                .background(AppTheme.darkGray)
                
                // Tables grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 3), spacing: 15) {
                        ForEach(filteredTables) { table in
                            TableCard(
                                table: table,
                                assignedReservation: getAssignedReservation(for: table),
                                onTap: {
                                    if let reservation = getAssignedReservation(for: table) {
                                        selectedReservation = reservation
                                        showingTableAssignment = true
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Gestion des Tables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Assigner automatiquement") {
                            autoAssignTables()
                        }
                        
                        Button("Réinitialiser les tables") {
                            resetTableAssignments()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTableAssignment) {
            if let reservation = selectedReservation {
                TableAssignmentView(
                    reservation: reservation,
                    tables: tables,
                    onAssign: { tableNumber in
                        assignTable(tableNumber, to: reservation)
                    }
                )
            }
        }
    }
    
    private func getAssignedReservation(for table: Table) -> Reservation? {
        // In a real implementation, this would check the reservation's assigned table
        // For now, we'll simulate some assignments for demo purposes
        return todayReservations.first { reservation in
            // Simulate table assignment based on party size and table capacity
            reservation.numberOfPeople <= table.capacity && 
            reservation.numberOfPeople > (table.capacity - 3)
        }
    }
    
    private func assignTable(_ tableNumber: Int, to reservation: Reservation) {
        // This would update the reservation in Firestore with the assigned table
        Logger.debug("Assigning table \(tableNumber) to reservation \(reservation.name)")
        selectedReservation = nil
        showingTableAssignment = false
    }
    
    private func autoAssignTables() {
        // Auto-assign algorithm based on party size and table capacity
        let unassignedReservations = todayReservations.filter { reservation in
            !tables.contains { table in
                getAssignedReservation(for: table)?.id == reservation.id
            }
        }
        
        for reservation in unassignedReservations {
            if let bestTable = findBestTable(for: reservation) {
                assignTable(bestTable.number, to: reservation)
            }
        }
    }
    
    private func findBestTable(for reservation: Reservation) -> Table? {
        return tables
            .filter { $0.isAvailable && $0.capacity >= reservation.numberOfPeople }
            .min { abs($0.capacity - reservation.numberOfPeople) < abs($1.capacity - reservation.numberOfPeople) }
    }
    
    private func resetTableAssignments() {
        // This would clear all table assignments
        Logger.debug("Resetting all table assignments")
    }
}

// MARK: - Location Tab

struct LocationTab: View {
    let location: Table.TableLocation
    let isSelected: Bool
    let tableCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: location.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? AppTheme.anthracite : AppTheme.gold)
                
                Text(location.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? AppTheme.anthracite : AppTheme.cream)
                
                Text("\(tableCount) tables")
                    .font(.caption2)
                    .foregroundColor(isSelected ? AppTheme.anthracite.opacity(0.7) : AppTheme.cream.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppTheme.gold : AppTheme.anthracite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Table Card

struct TableCard: View {
    let table: Table
    let assignedReservation: Reservation?
    let onTap: () -> Void
    
    private var isOccupied: Bool {
        assignedReservation != nil
    }
    
    private var cardColor: Color {
        if !table.isAvailable {
            return .red.opacity(0.3)
        } else if isOccupied {
            return AppTheme.gold.opacity(0.3)
        } else {
            return AppTheme.darkGray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Table number and status
                HStack {
                    Text("Table \(table.number)")
                        .font(.custom("Didot", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.cream)
                    
                    Spacer()
                    
                    Circle()
                        .fill(isOccupied ? AppTheme.gold : (table.isAvailable ? .green : .red))
                        .frame(width: 8, height: 8)
                }
                
                // Capacity info
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                    
                    Text("\(table.capacity) places")
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                    
                    Spacer()
                }
                
                // Assigned reservation info
                if let reservation = assignedReservation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reservation.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.gold)
                            .lineLimit(1)
                        
                        HStack {
                            Text(reservation.time)
                                .font(.caption2)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(reservation.numberOfPeople) pers.")
                                .font(.caption2)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(table.isAvailable ? "Disponible" : "Indisponible")
                        .font(.caption)
                        .foregroundColor(table.isAvailable ? .green : .red)
                        .italic()
                }
                
                Spacer()
            }
            .padding(12)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isOccupied ? AppTheme.gold : AppTheme.cream.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Table Assignment Sheet

struct TableAssignmentView: View {
    let reservation: Reservation
    let tables: [Table]
    let onAssign: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var availableTables: [Table] {
        tables.filter { $0.isAvailable && $0.capacity >= reservation.numberOfPeople }
            .sorted { $0.number < $1.number }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Reservation info
                VStack(spacing: 15) {
                    Text("Assigner une table")
                        .font(.custom("Didot", size: 24))
                        .foregroundColor(AppTheme.gold)
                    
                    VStack(spacing: 8) {
                        Text(reservation.name)
                            .font(.headline)
                            .foregroundColor(AppTheme.cream)
                        
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(AppTheme.gold)
                                Text("\(reservation.numberOfPeople) personnes")
                                    .foregroundColor(AppTheme.cream)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(AppTheme.gold)
                                Text(reservation.time)
                                    .foregroundColor(AppTheme.cream)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(AppTheme.darkGray)
                )
                
                // Available tables
                if availableTables.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Aucune table disponible")
                            .font(.headline)
                            .foregroundColor(AppTheme.cream)
                        
                        Text("Toutes les tables sont occupées ou trop petites pour \(reservation.numberOfPeople) personnes")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                            ForEach(availableTables) { table in
                                TableAssignmentCard(table: table) {
                                    onAssign(table.number)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Assigner une Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
            }
        }
    }
}

struct TableAssignmentCard: View {
    let table: Table
    let onAssign: () -> Void
    
    var body: some View {
        Button(action: onAssign) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: table.location.icon)
                        .foregroundColor(AppTheme.gold)
                    
                    Text("Table \(table.number)")
                        .font(.custom("Didot", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.cream)
                    
                    Spacer()
                }
                
                HStack {
                    Text("\(table.capacity) places")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.8))
                    
                    Spacer()
                    
                    Text(table.location.displayName)
                        .font(.caption)
                        .foregroundColor(AppTheme.gold.opacity(0.8))
                }
                
                if let notes = table.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.6))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.darkGray)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TableManagementView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
