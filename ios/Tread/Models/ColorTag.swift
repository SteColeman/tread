import SwiftUI

nonisolated enum ColorTag: String, CaseIterable, Sendable, Identifiable {
    case slate
    case stone
    case ember
    case moss
    case ocean
    case dusk
    case sand
    case cedar
    case iron
    case clay

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .slate: return Color(red: 0.42, green: 0.45, blue: 0.50)
        case .stone: return Color(red: 0.55, green: 0.53, blue: 0.50)
        case .ember: return Color(red: 0.76, green: 0.38, blue: 0.30)
        case .moss: return Color(red: 0.40, green: 0.55, blue: 0.40)
        case .ocean: return Color(red: 0.30, green: 0.50, blue: 0.65)
        case .dusk: return Color(red: 0.55, green: 0.40, blue: 0.60)
        case .sand: return Color(red: 0.72, green: 0.65, blue: 0.52)
        case .cedar: return Color(red: 0.58, green: 0.38, blue: 0.28)
        case .iron: return Color(red: 0.35, green: 0.36, blue: 0.38)
        case .clay: return Color(red: 0.68, green: 0.48, blue: 0.38)
        }
    }

    var label: String { rawValue.capitalized }
}
