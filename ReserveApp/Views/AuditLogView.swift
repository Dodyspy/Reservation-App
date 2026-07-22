import SwiftUI

struct AuditLogView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var auditEntries: [AuditLogEntry] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var filterAction: AuditAction?
    
    var filteredEntries: [AuditLogEntry] {
        if let filter = filterAction {
            return auditEntries.filter { $0.action == filter }
        }
        return auditEntries
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredEntries) { entry in
                                    AuditLogRow(entry: entry)
                                }
                                
                                if filteredEntries.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .font(.system(size: 60))
                                            .foregroundColor(AppTheme.cream.opacity(0.3))
                                        
                                        Text("Aucune entrée d'audit trouvée")
                                            .font(.headline)
                                            .foregroundColor(AppTheme.cream.opacity(0.6))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 100)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Journal d'audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            filterAction = nil
                        }) {
                            Label("All Actions", systemImage: "list.bullet")
                        }
                        
                        Divider()
                        
                        ForEach([AuditAction.login, .logout, .createReservation, .updateReservation, .deleteReservation, .closeService, .openService, .updateSettings, .createUser, .updateUser, .deleteUser], id: \.self) { action in
                            Button(action: {
                                filterAction = action
                            }) {
                                Label(action.displayName, systemImage: action.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .onAppear {
            loadAuditLog()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Audit Log"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadAuditLog() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            return
        }
        
        isLoading = true
        AuditService.shared.getAuditLog(restaurantId: restaurantId, limit: 200) { entries, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Failed to load audit log: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    auditEntries = entries ?? []
                }
            }
        }
    }
}

struct AuditLogRow: View {
    let entry: AuditLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.action.icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.action.displayName)
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                    
                    Text(entry.userName)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(entry.timestamp))
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.6))
                    
                    Text(formatDate(entry.timestamp))
                        .font(.caption2)
                        .foregroundColor(AppTheme.cream.opacity(0.4))
                }
            }
            
            if !entry.details.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entry.details.keys.sorted()), id: \.self) { key in
                        if let value = entry.details[key] {
                            HStack(spacing: 4) {
                                Text("•")
                                    .foregroundColor(AppTheme.gold.opacity(0.5))
                                Text("\(key):")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.cream.opacity(0.5))
                                Text(value)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.cream.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.anthracite.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var iconColor: Color {
        switch entry.action {
        case .login, .createReservation, .openService, .createUser, .createRestaurant:
            return .green
        case .logout:
            return .blue
        case .deleteReservation, .closeService, .deleteUser:
            return .red
        case .updateReservation, .updateSettings, .updateUser, .updateRestaurant, .assignTable, .updateCustomer:
            return AppTheme.gold
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}

#Preview {
    AuditLogView()
}
