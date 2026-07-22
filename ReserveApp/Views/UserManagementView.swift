import SwiftUI

struct UserManagementView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var users: [RestaurantUser] = []
    @State private var showAddUser = false
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedUser: RestaurantUser?
    @State private var showUserDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(users) { user in
                                UserRow(user: user)
                                    .onTapGesture {
                                        selectedUser = user
                                        showUserDetail = true
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gestion des Utilisateurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authService.currentUser?.canManageUsers() == true {
                        Button(action: {
                            showAddUser = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppTheme.gold)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadUsers()
        }
        .sheet(isPresented: $showAddUser) {
            AddUserView(onUserAdded: {
                loadUsers()
            })
        }
        .sheet(item: $selectedUser) { user in
            UserDetailView(user: user, onUserUpdated: {
                loadUsers()
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Gestion des Utilisateurs"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadUsers() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") else {
            return
        }
        
        isLoading = true
        UserService.shared.getUsers(restaurantId: restaurantId) { fetchedUsers, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Échec du chargement des utilisateurs : \(error.localizedDescription)"
                    showAlert = true
                } else {
                    users = fetchedUsers ?? []
                }
            }
        }
    }
}

struct UserRow: View {
    let user: RestaurantUser
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(user.isActive ? AppTheme.gold : Color.gray)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.anthracite)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(AppTheme.cream)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
                
                HStack(spacing: 8) {
                    Label(user.role.displayName, systemImage: "person.badge.key")
                        .font(.caption)
                        .foregroundColor(AppTheme.gold)
                    
                    if !user.isActive {
                        Label("Inactif", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.cream.opacity(0.3))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.anthracite.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct AddUserView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var displayName = ""
    @State private var selectedRole: UserRole = .staff
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var onUserAdded: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nom complet")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            TextField("", text: $displayName)
                                .placeholder(when: displayName.isEmpty) {
                                    Text("Jean Dupont")
                                        .foregroundColor(AppTheme.cream.opacity(0.3))
                                }
                                .foregroundColor(AppTheme.cream)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.anthracite.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            TextField("", text: $email)
                                .placeholder(when: email.isEmpty) {
                                    Text("user@example.com")
                                        .foregroundColor(AppTheme.cream.opacity(0.3))
                                }
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .foregroundColor(AppTheme.cream)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.anthracite.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rôle")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            Picker("Rôle", selection: $selectedRole) {
                                ForEach(UserRole.allCases, id: \.self) { role in
                                    Text(role.displayName).tag(role)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .colorMultiply(AppTheme.gold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Permissions")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(selectedRole.permissions, id: \.self) { permission in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.gold)
                                        Text(permission.displayName)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.cream.opacity(0.7))
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.anthracite.opacity(0.3))
                            )
                        }
                        
                        Text("Un email de réinitialisation du mot de passe sera envoyé à l'utilisateur")
                            .font(.caption)
                            .foregroundColor(AppTheme.cream.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Button(action: createUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.anthracite))
                            } else {
                                Text("Créer l'utilisateur")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.anthracite)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.gold)
                        )
                        .disabled(isLoading || email.isEmpty || displayName.isEmpty)
                        .opacity((email.isEmpty || displayName.isEmpty) ? 0.5 : 1.0)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ajouter un Utilisateur")
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Ajouter un Utilisateur"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !alertMessage.contains("Échec") {
                        onUserAdded()
                        dismiss()
                    }
                }
            )
        }
    }
    
    private func createUser() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"),
              let currentUser = authService.currentUser else {
            return
        }
        
        isLoading = true
        
        UserService.shared.createUser(
            email: email,
            displayName: displayName,
            role: selectedRole,
            restaurantId: restaurantId,
            createdBy: currentUser
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    alertMessage = "Utilisateur créé avec succès. Email envoyé à \(email)"
                    showAlert = true
                case .failure(let error):
                    alertMessage = "Échec de la création : \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct UserDetailView: View {
    let user: RestaurantUser
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showDeactivateConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var onUserUpdated: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Circle()
                            .fill(user.isActive ? AppTheme.gold : Color.gray)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(user.displayName.prefix(1).uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(AppTheme.anthracite)
                            )
                        
                        VStack(spacing: 8) {
                            Text(user.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.cream)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.cream.opacity(0.7))
                            
                            Label(user.role.displayName, systemImage: "person.badge.key")
                                .font(.headline)
                                .foregroundColor(AppTheme.gold)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InfoRow(label: "Statut", value: user.isActive ? "Actif" : "Inactif", icon: "circle.fill", iconColor: user.isActive ? .green : .red)
                            
                            if let lastLogin = user.lastLogin {
                                InfoRow(label: "Dernière connexion", value: formatDate(lastLogin), icon: "clock")
                            }
                            
                            InfoRow(label: "Créé le", value: formatDate(user.createdAt), icon: "calendar")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.anthracite.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                                )
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Permissions")
                                .font(.headline)
                                .foregroundColor(AppTheme.cream)
                            
                            ForEach(user.role.permissions, id: \.self) { permission in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.gold)
                                    Text(permission.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.cream.opacity(0.8))
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.anthracite.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                                )
                        )
                        
                        if authService.currentUser?.canManageUsers() == true && user.id != authService.currentUser?.id {
                            Button(action: {
                                showDeactivateConfirm = true
                            }) {
                                Text(user.isActive ? "Désactiver l'utilisateur" : "Réactiver l'utilisateur")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(user.isActive ? Color.red : Color.green)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Détails Utilisateur")
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
        .confirmationDialog(
            user.isActive ? "Désactiver l'utilisateur ?" : "Réactiver l'utilisateur ?",
            isPresented: $showDeactivateConfirm,
            titleVisibility: .visible
        ) {
            Button(user.isActive ? "Désactiver" : "Réactiver", role: user.isActive ? .destructive : nil) {
                toggleUserStatus()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(user.isActive ? "Cet utilisateur ne pourra plus accéder à l'application." : "Cet utilisateur pourra de nouveau accéder à l'application.")
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Gestion des Utilisateurs"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !alertMessage.contains("Échec") {
                        onUserUpdated()
                        dismiss()
                    }
                }
            )
        }
    }
    
    private func toggleUserStatus() {
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"),
              let userId = user.id,
              let currentUser = authService.currentUser else {
            return
        }
        
        if user.isActive {
            UserService.shared.deactivateUser(userId: userId, restaurantId: restaurantId, deactivatedBy: currentUser) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Échec de la désactivation : \(error.localizedDescription)"
                    } else {
                        alertMessage = "Utilisateur désactivé avec succès"
                    }
                    showAlert = true
                }
            }
        } else {
            UserService.shared.reactivateUser(userId: userId, restaurantId: restaurantId, reactivatedBy: currentUser) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Échec de la réactivation : \(error.localizedDescription)"
                    } else {
                        alertMessage = "Utilisateur réactivé avec succès"
                    }
                    showAlert = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    var iconColor: Color = AppTheme.gold
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.cream.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.cream)
        }
    }
}

#Preview {
    UserManagementView()
}
