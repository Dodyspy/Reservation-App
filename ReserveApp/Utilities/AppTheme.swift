import SwiftUI

struct AppTheme {
    // Colors based on Casanova d'Issy website theme
    static let anthracite = Color(hex: "282828")
    static let gold = Color(hex: "D4AF37")
    static let cream = Color(hex: "F5F5DC")
    static let darkGray = Color(hex: "333333")
    static let lightGray = Color(hex: "CCCCCC")
    
    // Status colors
    static let pendingColor = Color.orange
    static let confirmedColor = Color.green
    static let cancelledColor = Color.red
    static let completedColor = Color.blue
    
    // Font sizes
    static let titleFontSize: CGFloat = 24
    static let headlineFontSize: CGFloat = 18
    static let bodyFontSize: CGFloat = 16
    static let captionFontSize: CGFloat = 12
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
