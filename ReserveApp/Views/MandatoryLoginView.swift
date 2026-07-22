import SwiftUI
import Firebase
import FirebaseAuth

struct MandatoryLoginView: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var restaurantManager = RestaurantManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showForgotPassword = false
    
    var body: some View {
        ZStack {
            AppTheme.anthracite.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 50)
                    
                    // Logo and restaurant name
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(AppTheme.gold)
                        
                        Text("Restaurant Manager Pro")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.cream)
                        
                        Text("Connectez-vous pour accéder à l'application")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 10)
                    
                    // Login form
                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            TextField("", text: $email)
                                .placeholder(when: email.isEmpty) {
                                    Text("votre.email@exemple.com")
                                        .foregroundColor(AppTheme.cream.opacity(0.3))
                                }
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(AppTheme.cream)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mot de passe")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.cream.opacity(0.8))
                            
                            SecureField("", text: $password)
                                .placeholder(when: password.isEmpty) {
                                    Text("Entrez votre mot de passe")
                                        .foregroundColor(AppTheme.cream.opacity(0.3))
                                }
                                .textContentType(.password)
                                .foregroundColor(AppTheme.cream)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        // Forgot password
                        Button(action: {
                            showForgotPassword = true
                        }) {
                            Text("Mot de passe oublié ?")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.gold)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    
                    // Sign in button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Connexion..." : "Se connecter")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.gold)
                        )
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
        .alert("Connexion", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordViewFR()
        }
    }
    
    private func signIn() {
        isLoading = true
        
        authService.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let user):
                    Logger.debug("✅ Connecté en tant que: \(user.displayName)")
                case .failure(let error):
                    let errorCode = (error as NSError).code
                    switch errorCode {
                    case AuthErrorCode.wrongPassword.rawValue:
                        alertMessage = "Mot de passe incorrect"
                    case AuthErrorCode.userNotFound.rawValue:
                        alertMessage = "Aucun compte trouvé avec cet email"
                    case AuthErrorCode.invalidEmail.rawValue:
                        alertMessage = "Adresse email invalide"
                    case AuthErrorCode.userDisabled.rawValue:
                        alertMessage = "Ce compte a été désactivé"
                    case AuthErrorCode.tooManyRequests.rawValue:
                        alertMessage = "Trop de tentatives. Réessayez plus tard."
                    case 401:
                        alertMessage = "Veuillez vérifier votre email avant de vous connecter. Consultez votre boîte de réception."
                    case 404:
                        alertMessage = "Profil utilisateur non trouvé. Contactez votre administrateur."
                    case 403:
                        alertMessage = "Compte désactivé. Contactez votre administrateur."
                    default:
                        alertMessage = "Erreur de connexion: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
        }
    }
    
}

// MARK: - Forgot Password (French)
struct ForgotPasswordViewFR: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.anthracite.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.gold)
                    
                    VStack(spacing: 8) {
                        Text("Réinitialiser le mot de passe")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.cream)
                        
                        Text("Entrez votre email pour recevoir un lien de réinitialisation")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.cream.opacity(0.8))
                        
                        TextField("", text: $email)
                            .placeholder(when: email.isEmpty) {
                                Text("votre.email@exemple.com")
                                    .foregroundColor(AppTheme.cream.opacity(0.3))
                            }
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(AppTheme.cream)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal)
                    
                    Button(action: resetPassword) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            }
                            Text(isLoading ? "Envoi..." : "Envoyer le lien")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.gold)
                        )
                    }
                    .disabled(isLoading || email.isEmpty)
                    .opacity(email.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
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
                title: Text("Réinitialisation"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !alertMessage.contains("Erreur") {
                        dismiss()
                    }
                }
            )
        }
    }
    
    private func resetPassword() {
        isLoading = true
        
        AuthenticationService.shared.resetPassword(email: email) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Erreur: \(error.localizedDescription)"
                } else {
                    alertMessage = "Lien de réinitialisation envoyé à \(email)"
                }
                showAlert = true
            }
        }
    }
}

#Preview {
    MandatoryLoginView()
}
