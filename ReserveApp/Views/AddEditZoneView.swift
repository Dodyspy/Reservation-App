import SwiftUI

struct AddEditZoneView: View {
    let zone: Zone?
    let zoneViewModel: ZoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var selectedIcon: String = "rectangle.3.group"
    @State private var selectedColor: Color = .blue
    @State private var showingDeleteConfirmation = false
    
    private var isEditing: Bool { zone != nil }
    
    init(zone: Zone? = nil, zoneViewModel: ZoneViewModel) {
        self.zone = zone
        self.zoneViewModel = zoneViewModel
        
        if let zone = zone {
            self._displayName = State(initialValue: zone.displayName)
            self._selectedIcon = State(initialValue: zone.icon)
            self._selectedColor = State(initialValue: zone.color)
        }
    }
    
    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        zoneViewModel.isDisplayNameAvailable(displayName, excluding: zone?.id)
    }
    
    private let availableIcons = [
        "sun.max", "house", "wineglass", "lock", "leaf", "flame", "snowflake",
        "moon", "star", "heart", "music.note", "camera", "gamecontroller",
        "book", "paintbrush", "hammer", "wrench", "scissors", "eyeglasses",
        "crown", "diamond", "gem", "gift", "balloon", "party.popper",
        "birthday.cake", "cup.and.saucer", "fork.knife", "takeoutbag.and.cup.and.straw"
    ]
    
    private let availableColors: [Color] = [
        Color(hex: "#F4A261"),  // Terrace
        Color(hex: "#2A9D8F"),    // Interior
        Color(hex: "#E76F51"),     // Bar
        Color(hex: "#264653"),   // Private Room
        .blue, .purple, .pink, .indigo, .cyan, .mint, .brown, .gray
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations de la zone") {
                    HStack {
                        Text("Nom de la zone")
                        Spacer()
                        TextField("Ex: Terrasse VIP", text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Apparence") {
                    // Icon selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icône")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? .white : selectedColor)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(selectedIcon == icon ? selectedColor : selectedColor.opacity(0.2))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 5)
                    
                    // Color selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Couleur")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 35, height: 35)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? .white : .clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 5)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Aperçu")
                            .font(.headline)
                        
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(selectedColor.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedColor)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(displayName.isEmpty ? "Nom de la zone" : displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Zone personnalisée")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.vertical, 5)
                }
                
                if isEditing && zone?.isDefault == false {
                    Section {
                        Button("Supprimer la zone", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier Zone" : "Nouvelle Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveZone()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .alert("Supprimer la zone", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if let zone = zone {
                    zoneViewModel.deleteZone(zone)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer la zone '\(displayName)' ? Toutes les tables de cette zone seront déplacées vers 'Intérieur'.")
        }
    }
    
    private func saveZone() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let zoneName = trimmedName.lowercased().replacingOccurrences(of: " ", with: "_")
        
        let newZone = Zone(
            id: zone?.id ?? UUID().uuidString,
            name: zoneName,
            displayName: trimmedName,
            icon: selectedIcon,
            colorHex: selectedColor.toHex(),
            isDefault: zone?.isDefault ?? false,
            sortOrder: zone?.sortOrder ?? zoneViewModel.zones.count
        )
        
        if isEditing {
            zoneViewModel.updateZone(newZone)
        } else {
            zoneViewModel.addZone(newZone)
        }
        
        dismiss()
    }
}

#Preview {
    AddEditZoneView(zoneViewModel: ZoneViewModel())
}
