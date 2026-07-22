import SwiftUI

// MARK: - Dynamic Theme System
struct DynamicTheme {
    let primaryColor: Color
    let backgroundColor: Color
    let accentColor: Color
    let textColor: Color
    let cardBackgroundColor: Color
    
    init(restaurant: Restaurant?) {
        if let branding = restaurant?.branding {
            self.primaryColor = Color(hex: branding.primaryColor)
            self.backgroundColor = Color(hex: branding.backgroundColor)
            self.accentColor = Color(hex: branding.accentColor)
            self.textColor = .white
            self.cardBackgroundColor = Color(hex: branding.backgroundColor).opacity(0.8)
        } else {
            // Default theme (Casanova d'Issy)
            self.primaryColor = Color(hex: "#D4AF37")
            self.backgroundColor = Color(hex: "#2C2C2C")
            self.accentColor = Color(hex: "#F5F5DC")
            self.textColor = .white
            self.cardBackgroundColor = Color(hex: "#2C2C2C").opacity(0.8)
        }
    }
}

// MARK: - Theme Environment Key
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = DynamicTheme(restaurant: nil)
}

extension EnvironmentValues {
    var theme: DynamicTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Modifier for Dynamic Theme
struct DynamicThemeModifier: ViewModifier {
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, DynamicTheme(restaurant: restaurantManager.currentRestaurant))
            .background(DynamicTheme(restaurant: restaurantManager.currentRestaurant).backgroundColor)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func withDynamicTheme() -> some View {
        modifier(DynamicThemeModifier())
    }
}

// MARK: - Themed UI Components
struct ThemedButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.theme) var theme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.primaryColor)
                .cornerRadius(12)
        }
    }
}

struct ThemedCard<Content: View>: View {
    let content: Content
    @Environment(\.theme) var theme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

struct ThemedNavigationTitle: View {
    let title: String
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    @Environment(\.theme) var theme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textColor)
                
                if let restaurant = restaurantManager.currentRestaurant {
                    Text(restaurant.displayName)
                        .font(.subheadline)
                        .foregroundColor(theme.primaryColor)
                }
            }
            
            Spacer()
            
            // Restaurant settings button
            Button(action: {
                restaurantManager.clearCurrentRestaurant()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(theme.primaryColor)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Status Badge with Dynamic Colors
struct StatusBadge: View {
    let status: ReservationStatus
    @Environment(\.theme) var theme
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return theme.primaryColor
        case .arrived: return .blue
        case .cancelled: return .red
        case .completed: return .gray
        case .noShow: return .red
        }
    }
}

// MARK: - Restaurant Header Component
struct RestaurantHeader: View {
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    @Environment(\.theme) var theme
    
    var body: some View {
        if let restaurant = restaurantManager.currentRestaurant {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textColor)
                        
                        Text(restaurant.address)
                            .font(.caption)
                            .foregroundColor(theme.accentColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(restaurant.phone)
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                        
                        Text(restaurant.subscriptionTier.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primaryColor.opacity(0.2))
                            .foregroundColor(theme.primaryColor)
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(theme.cardBackgroundColor)
            .cornerRadius(12)
        }
    }
}
