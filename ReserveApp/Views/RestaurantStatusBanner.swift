import SwiftUI

struct RestaurantStatusBanner: View {
    @ObservedObject private var restaurantManager = RestaurantManager.shared
    
    var body: some View {
        if let restaurant = restaurantManager.currentRestaurant {
            if let message = restaurant.getClosureMessage() {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: getStatusIcon(restaurant: restaurant))
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(getStatusTitle(restaurant: restaurant))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(getStatusColor(restaurant: restaurant))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
    
    private func getStatusIcon(restaurant: Restaurant) -> String {
        if restaurant.isTemporarilyClosed {
            return "lock.fill"
        } else if restaurant.isRestaurantFull {
            return "exclamationmark.triangle.fill"
        } else {
            return "info.circle.fill"
        }
    }
    
    private func getStatusTitle(restaurant: Restaurant) -> String {
        if restaurant.isTemporarilyClosed {
            return "Restaurant Fermé"
        } else if restaurant.isRestaurantFull {
            return "Restaurant Complet"
        } else {
            return "Service Non Disponible"
        }
    }
    
    private func getStatusColor(restaurant: Restaurant) -> Color {
        if restaurant.isTemporarilyClosed {
            return Color.red.opacity(0.9)
        } else if restaurant.isRestaurantFull {
            return Color.orange.opacity(0.9)
        } else {
            return Color.gray.opacity(0.9)
        }
    }
}

struct RestaurantStatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantStatusBanner()
            .preferredColorScheme(.dark)
    }
}
