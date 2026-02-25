import SwiftUI

enum Theme {
    static let accentGradient = LinearGradient(
        colors: [.purple, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color(.systemGray6)

    static let glassMaterial: Material = .ultraThinMaterial
}
