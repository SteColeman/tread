import Foundation

nonisolated enum FootwearType: String, Codable, CaseIterable, Sendable, Identifiable {
    case casual = "Casual"
    case walking = "Walking"
    case hiking = "Hiking"
    case work = "Work"
    case weather = "Weather"
    case sport = "Sport"
    case sandal = "Sandal"
    case boot = "Boot"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .casual: return "shoe.fill"
        case .walking: return "figure.walk"
        case .hiking: return "mountain.2.fill"
        case .work: return "briefcase.fill"
        case .weather: return "cloud.rain.fill"
        case .sport: return "figure.run"
        case .sandal: return "sun.max.fill"
        case .boot: return "snowflake"
        case .other: return "shoeprint.fill"
        }
    }
}

nonisolated enum FootwearStatus: String, Codable, CaseIterable, Sendable {
    case active = "Active"
    case retired = "Retired"
    case archived = "Archived"
}

nonisolated struct FootwearItem: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    var type: FootwearType
    var dateAdded: Date
    var datePurchased: Date?
    var status: FootwearStatus
    var isDefault: Bool
    var expectedLifespanKm: Double
    var notes: String
    var colorTag: String

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        type: FootwearType = .casual,
        dateAdded: Date = Date(),
        datePurchased: Date? = nil,
        status: FootwearStatus = .active,
        isDefault: Bool = false,
        expectedLifespanKm: Double = 800,
        notes: String = "",
        colorTag: String = "slate"
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.type = type
        self.dateAdded = dateAdded
        self.datePurchased = datePurchased
        self.status = status
        self.isDefault = isDefault
        self.expectedLifespanKm = expectedLifespanKm
        self.notes = notes
        self.colorTag = colorTag
    }
}
