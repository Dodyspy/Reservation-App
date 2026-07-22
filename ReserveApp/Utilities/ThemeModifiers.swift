import SwiftUI

struct CasanovaThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accentColor(AppTheme.gold)
            .preferredColorScheme(.dark)
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? AppTheme.gold.opacity(0.7) : AppTheme.gold)
            .foregroundColor(AppTheme.anthracite)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct StatusBadgeModifier: ViewModifier {
    let status: ReservationStatus
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return AppTheme.pendingColor
        case .confirmed:
            return AppTheme.confirmedColor
        case .arrived:
            return .blue
        case .cancelled:
            return AppTheme.cancelledColor
        case .completed:
            return AppTheme.completedColor
        case .noShow:
            return AppTheme.cancelledColor
        }
    }
}

// Extension to apply theme modifiers easily
extension View {
    func withCasanovaTheme() -> some View {
        self.modifier(CasanovaThemeModifier())
    }
    
    func statusBadge(for status: ReservationStatus) -> some View {
        self.modifier(StatusBadgeModifier(status: status))
    }
}
