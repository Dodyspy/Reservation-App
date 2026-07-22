import SwiftUI
import FirebaseFirestore

struct ServiceEditSheet: View {
    let date: Date
    let service: ServiceType
    @Binding var serviceStatus: ServiceStatus
    @Environment(\.dismiss) var dismiss
    
    @State private var isClosed: Bool
    @State private var reason: String
    @State private var startTime: String
    @State private var endTime: String
    @State private var lastReservationTime: String
    @State private var maxCovers: Int = 50
    @State private var isUpdating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
    
    init(date: Date, service: ServiceType, serviceStatus: Binding<ServiceStatus>) {
        self.date = date
        self.service = service
        self._serviceStatus = serviceStatus
        
        // Initialize state from current status
        _isClosed = State(initialValue: serviceStatus.wrappedValue.isClosed)
        _reason = State(initialValue: serviceStatus.wrappedValue.reason ?? "")
        
        // Default service hours
        if service == .lunch {
            _startTime = State(initialValue: "12:00")
            _endTime = State(initialValue: "15:00")
            _lastReservationTime = State(initialValue: "14:45")
        } else {
            _startTime = State(initialValue: "19:00")
            _endTime = State(initialValue: "23:00")
            _lastReservationTime = State(initialValue: "22:45")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Edit service")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(dateFormatter.string(from: date)) | \(service.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 30) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text("0 reservations")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.caption)
                                Text("0 covers")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 20)
                    
                    // Action Buttons
                    HStack(spacing: 20) {
                        ActionButton(
                            icon: "globe",
                            title: "Stop online",
                            action: {}
                        )
                        
                        ActionButton(
                            icon: isClosed ? "power" : "power",
                            title: isClosed ? "Open service" : "Close service",
                            isDestructive: !isClosed,
                            action: {
                                isClosed.toggle()
                            }
                        )
                        
                        ActionButton(
                            icon: "note.text",
                            title: "Add note",
                            action: {}
                        )
                    }
                    .padding(.horizontal)
                    
                    // Basic Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Basic info")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        // Service Hours
                        Text("Service hours")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        TimePickerRow(icon: "clock", label: "Start time", time: $startTime)
                        TimePickerRow(icon: "clock", label: "End time", time: $endTime)
                        TimePickerRow(icon: "clock", label: "Last reservation time", time: $lastReservationTime)
                        
                        Divider()
                        
                        // Max Covers
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(.secondary)
                            Text("Max bookable covers")
                                .font(.subheadline)
                            Spacer()
                            TextField("100", value: $maxCovers, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                        
                        // Close Reason (if closed)
                        if isClosed {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Raison de fermeture")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                TextField("Ex: Réveillon, Fermé pour préparation", text: $reason)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            saveChanges()
                        }) {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Apply for this day")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isClosed ? Color.red : AppTheme.gold)
                        )
                        .disabled(isUpdating)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Service Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !alertMessage.contains("Erreur") {
                        dismiss()
                    }
                }
            )
        }
    }
    
    private func saveChanges() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            alertMessage = "Erreur: Restaurant non configuré"
            showAlert = true
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date).prefix(10)
        
        isUpdating = true
        
        RestaurantService.shared.updateServiceStatus(
            restaurantId: restaurantId,
            date: String(dateString),
            service: service,
            isClosed: isClosed,
            reason: reason,
            completion: { error in
                DispatchQueue.main.async {
                    self.isUpdating = false
                    
                    if let error = error {
                        self.alertMessage = "Erreur: \(error.localizedDescription)"
                    } else {
                        // Update binding
                        self.serviceStatus = ServiceStatus(isClosed: isClosed, reason: reason)
                        self.alertMessage = isClosed ? 
                            "🔒 \(service.displayName) fermé pour le \(dateString)" : 
                            "✅ \(service.displayName) ouvert pour le \(dateString)"
                        
                        // Log audit entry if user is authenticated
                        if let user = AuthenticationService.shared.currentUser {
                            AuditService.shared.log(
                                action: isClosed ? .closeService : .openService,
                                user: user,
                                details: [
                                    "service": service.rawValue,
                                    "date": String(dateString),
                                    "reason": reason
                                ]
                            )
                        }
                    }
                    self.showAlert = true
                }
            }
        )
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? .red : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TimePickerRow: View {
    let icon: String
    let label: String
    @Binding var time: String
    @State private var showingPicker = false
    @State private var selectedDate: Date
    
    init(icon: String, label: String, time: Binding<String>) {
        self.icon = icon
        self.label = label
        self._time = time
        
        // Parse time string to Date
        let components = time.wrappedValue.split(separator: ":")
        let hour = Int(components.first ?? "12") ?? 12
        let minute = Int(components.last ?? "00") ?? 0
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        self._selectedDate = State(initialValue: Calendar.current.date(from: dateComponents) ?? Date())
    }
    
    var body: some View {
        Button(action: {
            showingPicker.toggle()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(time)
                    .foregroundColor(.secondary)
                Image(systemName: showingPicker ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        
        if showingPicker {
            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .onChange(of: selectedDate) { newDate in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    time = formatter.string(from: newDate)
                }
        }
    }
}
