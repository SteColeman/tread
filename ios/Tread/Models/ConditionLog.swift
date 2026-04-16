import Foundation

nonisolated enum WearArea: String, Codable, CaseIterable, Sendable {
    case sole = "Sole"
    case heel = "Heel"
    case upper = "Upper"
    case insole = "Insole"
    case laces = "Laces"
    case toebox = "Toe Box"

    var icon: String {
        switch self {
        case .sole: return "shoe.fill"
        case .heel: return "arrow.down.to.line"
        case .upper: return "arrow.up.to.line"
        case .insole: return "square.stack.fill"
        case .laces: return "link"
        case .toebox: return "arrow.right.to.line"
        }
    }
}

nonisolated struct ConditionLog: Identifiable, Codable, Sendable {
    let id: UUID
    var footwearId: UUID
    var date: Date
    var rating: Int
    var notes: String
    var affectedAreas: [WearArea]

    init(
        id: UUID = UUID(),
        footwearId: UUID,
        date: Date = Date(),
        rating: Int = 3,
        notes: String = "",
        affectedAreas: [WearArea] = []
    ) {
        self.id = id
        self.footwearId = footwearId
        self.date = date
        self.rating = rating
        self.notes = notes
        self.affectedAreas = affectedAreas
    }

    var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }
}
