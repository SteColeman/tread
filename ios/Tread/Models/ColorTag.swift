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

    var hex: String {
        switch self {
        case .slate: return "#6B7380"
        case .stone: return "#8C8780"
        case .ember: return "#C2614D"
        case .moss: return "#668C66"
        case .ocean: return "#4D80A6"
        case .dusk: return "#8C669A"
        case .sand: return "#B8A685"
        case .cedar: return "#945C47"
        case .iron: return "#5A5C61"
        case .clay: return "#AD7B61"
        }
    }
}
