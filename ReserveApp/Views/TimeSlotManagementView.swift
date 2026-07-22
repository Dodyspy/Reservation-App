import SwiftUI
import FirebaseFirestore

struct TimeSlotExtraCover: Identifiable {
    var id: String { time }
    var time: String        // e.g., "19:00-20:00"
    var extraCovers: Int
    var enabled: Bool
}

struct TimeSlotManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDate = Date()
    @State private var isEnabled = false
    @State private var slots: [TimeSlotExtraCover] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var serviceHours: (dinnerStart: String, dinnerEnd: String, lunchStart: String, lunchEnd: String) = ("19:00", "23:00", "12:00", "15:00")
    @State private var restaurantData: [String: Any]? = nil
    
    private let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE dd MMM yyyy"
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
    
    private var dateKey: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return String(f.string(from: selectedDate).prefix(10))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                            .scaleEffect(1.5)
                        Text("Chargement...")
                            .foregroundColor(AppTheme.cream)
                            .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 8) {
                                Image(systemName: "clock.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.gold)
                                
                                Text("Créneaux Horaires")
                                    .font(.custom("Didot", size: 24))
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.gold)
                                
                                Text("Configurez les couverts supplémentaires par créneau pour chaque jour. Ces places s'ajoutent à la capacité de base.")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.cream.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 16)
                            
                            // Date navigator
                            HStack {
                                Button(action: {
                                    if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                                        selectedDate = newDate
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.gold)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.gold.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 2) {
                                    Text(displayDateFormatter.string(from: selectedDate).capitalized)
                                        .font(.custom("Didot", size: 16))
                                        .foregroundColor(AppTheme.gold)
                                    
                                    if Calendar.current.isDateInToday(selectedDate) {
                                        Text("Aujourd'hui")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                                        selectedDate = newDate
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.gold)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.gold.opacity(0.5), lineWidth: 1)
                                        )
                                }
                            }
                            .padding()
                            .background(AppTheme.darkGray)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Master toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Activer pour ce jour")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.cream)
                                    Text(isEnabled ? "Les couverts extra sont actifs" : "Désactivé - capacité de base uniquement")
                                        .font(.caption)
                                        .foregroundColor(isEnabled ? .green : AppTheme.cream.opacity(0.5))
                                }
                                Spacer()
                                Toggle("", isOn: $isEnabled)
                                    .labelsHidden()
                                    .tint(AppTheme.gold)
                            }
                            .padding()
                            .background(AppTheme.darkGray)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            if isEnabled {
                                // Slot list
                                VStack(spacing: 0) {
                                    ForEach(slots.indices, id: \.self) { index in
                                        TimeSlotRow(slot: $slots[index])
                                        
                                        if index < slots.count - 1 {
                                            Divider()
                                                .background(AppTheme.gold.opacity(0.2))
                                        }
                                    }
                                }
                                .background(AppTheme.darkGray)
                                .cornerRadius(12)
                                .padding(.horizontal)
                                
                                // Info box
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(AppTheme.gold)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Comment ça marche ?")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppTheme.cream)
                                        
                                        Text("Capacité de base (backoffice) : X couverts\n+ Créneau 19h-20h : +Y couverts\n= Total disponible : X + Y couverts\n\nChaque jour a sa propre configuration.")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.cream.opacity(0.7))
                                    }
                                }
                                .padding()
                                .background(AppTheme.gold.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                            
                            // Save button
                            Button(action: saveTimeSlots) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isSaving ? "Enregistrement..." : "Enregistrer pour ce jour")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.gold)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .disabled(isSaving)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Créneaux")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Fermer") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(AppTheme.gold)
            )
            .onAppear {
                loadRestaurantData()
            }
            .onChange(of: selectedDate) { _ in
                loadDayConfig()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Créneaux Horaires"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Load Restaurant Data (once)
    
    private func loadRestaurantData() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            isLoading = false
            alertMessage = "Erreur: Restaurant non configuré"
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        db.collection("restaurants").document(restaurantId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                guard let data = snapshot?.data() else {
                    isLoading = false
                    return
                }
                
                restaurantData = data
                
                // Load service hours to generate slots
                if let svcHours = data["serviceHours"] as? [String: Any] {
                    serviceHours.dinnerStart = svcHours["dinnerStart"] as? String ?? "19:00"
                    serviceHours.dinnerEnd = svcHours["dinnerEnd"] as? String ?? "23:00"
                    serviceHours.lunchStart = svcHours["lunchStart"] as? String ?? "12:00"
                    serviceHours.lunchEnd = svcHours["lunchEnd"] as? String ?? "15:00"
                }
                
                loadDayConfig()
                isLoading = false
            }
        }
    }
    
    // MARK: - Load Config for Selected Day
    
    private func loadDayConfig() {
        guard let data = restaurantData else { return }
        
        // Reset slots
        slots = []
        isEnabled = false
        
        // Try to load per-day config first
        if let config = data["timeSlotExtraCovers"] as? [String: Any],
           let daily = config["daily"] as? [String: Any],
           let dayConfig = daily[dateKey] as? [String: Any] {
            isEnabled = dayConfig["enabled"] as? Bool ?? false
            if let savedSlots = dayConfig["slots"] as? [[String: Any]] {
                slots = savedSlots.map { slotData in
                    TimeSlotExtraCover(
                        time: slotData["time"] as? String ?? "",
                        extraCovers: slotData["extraCovers"] as? Int ?? 0,
                        enabled: slotData["enabled"] as? Bool ?? true
                    )
                }
            }
        }
        // Fall back to global config (legacy)
        else if let config = data["timeSlotExtraCovers"] as? [String: Any],
                config["daily"] == nil {
            isEnabled = config["enabled"] as? Bool ?? false
            if let savedSlots = config["slots"] as? [[String: Any]] {
                slots = savedSlots.map { slotData in
                    TimeSlotExtraCover(
                        time: slotData["time"] as? String ?? "",
                        extraCovers: slotData["extraCovers"] as? Int ?? 0,
                        enabled: slotData["enabled"] as? Bool ?? true
                    )
                }
            }
        }
        
        // If no slots loaded, generate from service hours
        if slots.isEmpty {
            generateDefaultSlots()
        }
    }
    
    // MARK: - Generate Default Slots
    
    private func generateDefaultSlots() {
        var generatedSlots: [TimeSlotExtraCover] = []
        
        // Generate lunch slots
        generatedSlots.append(contentsOf: generateHourlySlots(
            from: serviceHours.lunchStart,
            to: serviceHours.lunchEnd
        ))
        
        // Generate dinner slots
        generatedSlots.append(contentsOf: generateHourlySlots(
            from: serviceHours.dinnerStart,
            to: serviceHours.dinnerEnd
        ))
        
        slots = generatedSlots
    }
    
    private func generateHourlySlots(from startTime: String, to endTime: String) -> [TimeSlotExtraCover] {
        var result: [TimeSlotExtraCover] = []
        
        let startParts = startTime.split(separator: ":").map { Int($0) ?? 0 }
        let endParts = endTime.split(separator: ":").map { Int($0) ?? 0 }
        
        guard startParts.count >= 2, endParts.count >= 2 else { return result }
        
        var currentHour = startParts[0]
        let endHour = endParts[0]
        
        while currentHour < endHour {
            let nextHour = currentHour + 1
            let slotTime = String(format: "%02d:00-%02d:00", currentHour, nextHour)
            result.append(TimeSlotExtraCover(time: slotTime, extraCovers: 0, enabled: true))
            currentHour = nextHour
        }
        
        return result
    }
    
    // MARK: - Save
    
    private func saveTimeSlots() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            alertMessage = "Erreur: Restaurant non configuré"
            showAlert = true
            return
        }
        
        isSaving = true
        
        let slotsData: [[String: Any]] = slots.map { slot in
            [
                "time": slot.time,
                "extraCovers": slot.extraCovers,
                "enabled": slot.enabled
            ]
        }
        
        let dayConfig: [String: Any] = [
            "enabled": isEnabled,
            "slots": slotsData
        ]
        
        let db = Firestore.firestore()
        db.collection("restaurants").document(restaurantId).updateData([
            "timeSlotExtraCovers.daily.\(dateKey)": dayConfig,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            DispatchQueue.main.async {
                isSaving = false
                
                if let error = error {
                    alertMessage = "Erreur: \(error.localizedDescription)"
                } else {
                    alertMessage = "✅ Créneaux enregistrés pour le \(displayDateFormatter.string(from: selectedDate))"
                    // Update local cache
                    if restaurantData != nil {
                        var config = restaurantData?["timeSlotExtraCovers"] as? [String: Any] ?? [:]
                        var daily = config["daily"] as? [String: Any] ?? [:]
                        daily[dateKey] = dayConfig
                        config["daily"] = daily
                        restaurantData?["timeSlotExtraCovers"] = config
                    }
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Time Slot Row

struct TimeSlotRow: View {
    @Binding var slot: TimeSlotExtraCover
    
    var body: some View {
        HStack(spacing: 12) {
            // Toggle
            Toggle("", isOn: $slot.enabled)
                .labelsHidden()
                .tint(AppTheme.gold)
                .frame(width: 50)
            
            // Time range
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.time)
                    .font(.headline)
                    .foregroundColor(slot.enabled ? AppTheme.cream : AppTheme.cream.opacity(0.4))
                
                if slot.enabled {
                    Text("+\(slot.extraCovers) couverts")
                        .font(.caption)
                        .foregroundColor(slot.extraCovers > 0 ? .green : AppTheme.cream.opacity(0.5))
                }
            }
            
            Spacer()
            
            if slot.enabled {
                // Stepper for extra covers
                HStack(spacing: 8) {
                    Button(action: {
                        if slot.extraCovers > 0 {
                            slot.extraCovers -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(slot.extraCovers > 0 ? AppTheme.gold : AppTheme.cream.opacity(0.3))
                    }
                    .disabled(slot.extraCovers <= 0)
                    
                    Text("\(slot.extraCovers)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.gold)
                        .frame(minWidth: 35, alignment: .center)
                    
                    Button(action: {
                        slot.extraCovers += 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .padding()
        .opacity(slot.enabled ? 1.0 : 0.6)
    }
}

#Preview {
    TimeSlotManagementView()
}
