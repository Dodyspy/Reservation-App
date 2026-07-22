import SwiftUI

struct RestaurantSetupView: View {
    @StateObject private var restaurantManager = RestaurantManager.shared
    @State private var restaurantCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 20) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "#D4AF37"))
                    
                    Text("Restaurant Manager Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Connectez-vous à votre restaurant")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Restaurant Code Input
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Code Restaurant")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Entrez votre code restaurant", text: $restaurantCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .font(.title2)
                            .onSubmit {
                                connectToRestaurant()
                            }
                    }
                    
                    Button(action: connectToRestaurant) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Connexion..." : "Se connecter")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#D4AF37"))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(restaurantCode.isEmpty || isLoading)
                    .opacity(restaurantCode.isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Help Text
                VStack(spacing: 10) {
                    Text("Besoin d'aide ?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Contactez votre administrateur pour obtenir le code de votre restaurant")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                
                Spacer()
            }
            .background(Color(hex: "#2C2C2C"))
            .navigationBarHidden(true)
        }
        .alert("Erreur de connexion", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connectToRestaurant() {
        guard !restaurantCode.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        RestaurantService.shared.getRestaurantByCode(restaurantCode) { restaurant, documentId, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let restaurant = restaurant, let documentId = documentId {
                    // Success - configure the app for this restaurant
                    // Store both the restaurant code and document ID
                    UserDefaults.standard.set(restaurantCode.uppercased(), forKey: "selectedRestaurantCode")
                    UserDefaults.standard.set(documentId, forKey: "restaurantDocumentId")
                    print("✅ Stored restaurant code: \(restaurantCode.uppercased())")
                    print("✅ Stored document ID: \(documentId)")
                    
                    restaurantManager.setCurrentRestaurant(restaurant)
                } else {
                    // Error - show message
                    errorMessage = error?.localizedDescription ?? "Code restaurant invalide"
                    showError = true
                    restaurantCode = ""
                }
            }
        }
    }
}


#Preview {
    RestaurantSetupView()
}
