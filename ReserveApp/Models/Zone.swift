import Foundation
import SwiftUI
import FirebaseFirestore

struct Zone: Identifiable, Codable {
    var id: String
    var name: String
    var displayName: String
    var icon: String
    var colorHex: String
    var isDefault: Bool
    var sortOrder: Int
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    init(id: String, name: String, displayName: String, icon: String, colorHex: String, isDefault: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
}

// MARK: - Default Zones

extension Zone {
    static let defaultZones: [Zone] = [
        Zone(id: "terrace", name: "terrace", displayName: "Terrasse", icon: "sun.max", colorHex: "#F4A261", isDefault: true, sortOrder: 1),
        Zone(id: "interior", name: "interior", displayName: "Intérieur", icon: "house", colorHex: "#2A9D8F", isDefault: true, sortOrder: 2),
        Zone(id: "bar", name: "bar", displayName: "Bar", icon: "wineglass", colorHex: "#E76F51", isDefault: true, sortOrder: 3),
        Zone(id: "privateRoom", name: "privateRoom", displayName: "Salon Privé", icon: "lock", colorHex: "#264653", isDefault: true, sortOrder: 4)
    ]
}

// MARK: - Color Extension

extension Color {
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
