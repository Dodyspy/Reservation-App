import SwiftUI

struct EditableTableManagementView: View {
    @StateObject private var tableViewModel = TableViewModel()
    @StateObject private var zoneViewModel = ZoneViewModel()
    @State private var selectedZoneId: String = "interior"
    @State private var showingAddTable = false
    @State private var showingEditTable = false
    @State private var selectedTable: Table?
    @State private var showingLocationManager = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with zone tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(zoneViewModel.zones) { zone in
                            ZoneTabButton(
                                zone: zone,
                                isSelected: selectedZoneId == zone.id,
                                tableCount: tableViewModel.tablesForZone(zone.id).count
                            ) {
                                selectedZoneId = zone.id
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 15)
                .background(AppTheme.darkGray)
                
                // Tables management area
                if tableViewModel.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                        Text("Chargement des tables...")
                            .foregroundColor(AppTheme.cream)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TablesGridView(
                        tables: tableViewModel.tablesForZone(selectedZoneId),
                        onTableTap: { table in
                            selectedTable = table
                            showingEditTable = true
                        },
                        onToggleAvailability: { table in
                            tableViewModel.toggleTableAvailability(table)
                        }
                    )
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Gestion des Tables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zones") {
                        showingLocationManager = true
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTable = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTable) {
            if let selectedZone = zoneViewModel.zones.first(where: { $0.id == selectedZoneId }) {
                AddEditTableView(
                    zone: selectedZone,
                    tableViewModel: tableViewModel,
                    zoneViewModel: zoneViewModel
                )
            }
        }
        .sheet(isPresented: $showingEditTable) {
            if let table = selectedTable {
                AddEditTableView(
                    table: table,
                    zone: zoneViewModel.zones.first(where: { $0.id == selectedZoneId }),
                    tableViewModel: tableViewModel,
                    zoneViewModel: zoneViewModel
                )
            }
        }
        .sheet(isPresented: $showingLocationManager) {
            LocationManagerView(tableViewModel: tableViewModel)
        }
        .alert("Erreur", isPresented: .constant(tableViewModel.errorMessage != nil)) {
            Button("OK") {
                tableViewModel.errorMessage = nil
            }
        } message: {
            Text(tableViewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Zone Tab Button

struct ZoneTabButton: View {
    let zone: Zone
    let isSelected: Bool
    let tableCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: zone.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? AppTheme.anthracite : zone.color)
                
                Text(zone.displayName)
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
                    .fill(isSelected ? zone.color : AppTheme.anthracite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(zone.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tables Grid View

struct TablesGridView: View {
    let tables: [Table]
    let onTableTap: (Table) -> Void
    let onToggleAvailability: (Table) -> Void
    
    var body: some View {
        ScrollView {
            if tables.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "table.furniture")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.cream.opacity(0.5))
                    
                    Text("Aucune table dans cette zone")
                        .font(.headline)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                    
                    Text("Appuyez sur + pour ajouter une table")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 3), spacing: 15) {
                    ForEach(tables) { table in
                        EditableTableCard(
                            table: table,
                            onTap: { onTableTap(table) },
                            onToggleAvailability: { onToggleAvailability(table) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Editable Table Card

struct EditableTableCard: View {
    let table: Table
    let onTap: () -> Void
    let onToggleAvailability: () -> Void
    
    private var cardColor: Color {
        if !table.isAvailable {
            return .red.opacity(0.3)
        } else {
            return table.location.zoneColor.opacity(0.2)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with table number and availability toggle
            HStack {
                Text("Table \(table.number)")
                    .font(.custom("Didot", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.cream)
                
                Spacer()
                
                Button(action: onToggleAvailability) {
                    Circle()
                        .fill(table.isAvailable ? .green : .red)
                        .frame(width: 12, height: 12)
                }
            }
            
            // Capacity info
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(table.location.zoneColor)
                
                Text("\(table.capacity) places")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.8))
                
                Spacer()
            }
            
            // Status and notes
            VStack(alignment: .leading, spacing: 4) {
                Text(table.isAvailable ? "Disponible" : "Indisponible")
                    .font(.caption)
                    .foregroundColor(table.isAvailable ? .green : .red)
                    .fontWeight(.medium)
                
                if let notes = table.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(AppTheme.cream.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Edit button
            Button("Modifier") {
                onTap()
            }
            .font(.caption)
            .foregroundColor(table.location.zoneColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(table.location.zoneColor, lineWidth: 1)
            )
        }
        .padding(12)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(table.location.zoneColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - Add/Edit Table View

struct AddEditTableView: View {
    let table: Table?
    let zone: Zone?
    let tableViewModel: TableViewModel
    let zoneViewModel: ZoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var tableNumber: String = ""
    @State private var capacity: String = ""
    @State private var selectedZoneId: String
    @State private var isAvailable: Bool = true
    @State private var notes: String = ""
    @State private var showingDeleteConfirmation = false
    
    private var isEditing: Bool { table != nil }
    
    init(table: Table? = nil, zone: Zone?, tableViewModel: TableViewModel, zoneViewModel: ZoneViewModel) {
        self.table = table
        self.zone = zone
        self.tableViewModel = tableViewModel
        self.zoneViewModel = zoneViewModel
        self._selectedZoneId = State(initialValue: table?.zoneId ?? zone?.id ?? "interior")
        
        if let table = table {
            self._tableNumber = State(initialValue: String(table.number))
            self._capacity = State(initialValue: String(table.capacity))
            self._isAvailable = State(initialValue: table.isAvailable)
            self._notes = State(initialValue: table.notes ?? "")
        }
    }
    
    private var isValid: Bool {
        guard let number = Int(tableNumber),
              let cap = Int(capacity),
              number > 0,
              cap > 0 else { return false }
        
        return tableViewModel.isTableNumberAvailable(number, in: getLocationForZone(), excluding: table?.id)
    }
    
    private func getLocationForZone() -> Table.TableLocation {
        guard let selectedZone = zoneViewModel.zones.first(where: { $0.id == selectedZoneId }) else {
            return .interior
        }
        
        // Map zone IDs to locations for validation
        switch selectedZone.id {
        case "terrace": return .terrace
        case "interior": return .interior
        case "bar": return .bar
        case "privateRoom": return .privateRoom
        default: return .custom
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations de la table") {
                    HStack {
                        Text("Numéro")
                        Spacer()
                        TextField("Ex: 15", text: $tableNumber)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Capacité")
                        Spacer()
                        TextField("Ex: 4", text: $capacity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Zone", selection: $selectedZoneId) {
                        ForEach(zoneViewModel.zones) { zone in
                            HStack {
                                Image(systemName: zone.icon)
                                    .foregroundColor(zone.color)
                                Text(zone.displayName)
                            }
                            .tag(zone.id)
                        }
                    }
                    
                    Toggle("Disponible", isOn: $isAvailable)
                }
                
                Section("Notes (optionnel)") {
                    TextField("Notes sur cette table...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if isEditing {
                    Section {
                        Button("Supprimer la table", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier Table" : "Nouvelle Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveTable()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .alert("Supprimer la table", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if let table = table {
                    tableViewModel.deleteTable(table)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer la table \(tableNumber) ? Cette action est irréversible.")
        }
    }
    
    private func saveTable() {
        guard let number = Int(tableNumber),
              let cap = Int(capacity) else { return }
        
        let newTable = Table(
            number: number,
            capacity: cap,
            location: getLocationForZone(),
            zoneId: selectedZoneId,
            isAvailable: isAvailable,
            notes: notes.isEmpty ? nil : notes
        )
        
        if isEditing {
            var updatedTable = newTable
            updatedTable.id = table?.id
            tableViewModel.updateTable(updatedTable)
        } else {
            tableViewModel.addTable(newTable)
        }
        
        dismiss()
    }
}

// MARK: - Location Manager View

struct LocationManagerView: View {
    let tableViewModel: TableViewModel
    @StateObject private var zoneViewModel = ZoneViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddZone = false
    @State private var selectedZone: Zone?
    @State private var showingEditZone = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Gestion des Zones")
                        .font(.custom("Didot", size: 24))
                        .foregroundColor(AppTheme.gold)
                    
                    Text("Personnalisez les zones de votre restaurant")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                }
                .padding()
                .background(AppTheme.darkGray)
                
                if zoneViewModel.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                        Text("Chargement des zones...")
                            .foregroundColor(AppTheme.cream)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(zoneViewModel.zones) { zone in
                                ZoneCard(
                                    zone: zone,
                                    tableCount: tableViewModel.tablesForZone(zone.id).count,
                                    onEdit: {
                                        selectedZone = zone
                                        showingEditZone = true
                                    },
                                    onDelete: zone.isDefault ? nil : {
                                        zoneViewModel.deleteZone(zone)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddZone = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddZone) {
            AddEditZoneView(zoneViewModel: zoneViewModel)
        }
        .sheet(isPresented: $showingEditZone) {
            if let zone = selectedZone {
                AddEditZoneView(zone: zone, zoneViewModel: zoneViewModel)
            }
        }
        .alert("Erreur", isPresented: .constant(zoneViewModel.errorMessage != nil)) {
            Button("OK") {
                zoneViewModel.errorMessage = nil
            }
        } message: {
            Text(zoneViewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Zone Card

struct ZoneCard: View {
    let zone: Zone
    let tableCount: Int
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 15) {
            // Zone icon and color
            ZStack {
                Circle()
                    .fill(zone.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: zone.icon)
                    .font(.system(size: 20))
                    .foregroundColor(zone.color)
            }
            
            // Zone info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zone.displayName)
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                    
                    if zone.isDefault {
                        Text("DÉFAUT")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.gold.opacity(0.3))
                            .foregroundColor(AppTheme.gold)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(tableCount) tables")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream.opacity(0.6))
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 10) {
                Button("Modifier") {
                    onEdit()
                }
                .font(.caption)
                .foregroundColor(zone.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(zone.color, lineWidth: 1)
                )
                
                if let onDelete = onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.darkGray)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(zone.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    EditableTableManagementView()
        .withCasanovaTheme()
}
