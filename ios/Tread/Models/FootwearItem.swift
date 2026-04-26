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
    var colorway: String
    var type: FootwearType
    var dateAdded: Date
    var datePurchased: Date?
    var status: FootwearStatus
    var isDefault: Bool
    var expectedLifespanKm: Double
    var notes: String
    var colorTag: String
    var photoFilename: String?
    var receiptPhotoFilename: String?

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        colorway: String = "",
        type: FootwearType = .casual,
        dateAdded: Date = Date(),
        datePurchased: Date? = nil,
        status: FootwearStatus = .active,
        isDefault: Bool = false,
        expectedLifespanKm: Double = 800,
        notes: String = "",
        colorTag: String = "slate",
        photoFilename: String? = nil,
        receiptPhotoFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.colorway = colorway
        self.type = type
        self.dateAdded = dateAdded
        self.datePurchased = datePurchased
        self.status = status
        self.isDefault = isDefault
        self.expectedLifespanKm = expectedLifespanKm
        self.notes = notes
        self.colorTag = colorTag
        self.photoFilename = photoFilename
        self.receiptPhotoFilename = receiptPhotoFilename
    }

    enum CodingKeys: String, CodingKey {
        case id, name, brand, colorway, type, dateAdded, datePurchased, status, isDefault, expectedLifespanKm, notes, colorTag, photoFilename, receiptPhotoFilename
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        self.colorway = try c.decodeIfPresent(String.self, forKey: .colorway) ?? ""
        self.type = try c.decode(FootwearType.self, forKey: .type)
        self.dateAdded = try c.decode(Date.self, forKey: .dateAdded)
        self.datePurchased = try c.decodeIfPresent(Date.self, forKey: .datePurchased)
        self.status = try c.decode(FootwearStatus.self, forKey: .status)
        self.isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.expectedLifespanKm = try c.decodeIfPresent(Double.self, forKey: .expectedLifespanKm) ?? 800
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.colorTag = try c.decodeIfPresent(String.self, forKey: .colorTag) ?? "slate"
        self.photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        self.receiptPhotoFilename = try c.decodeIfPresent(String.self, forKey: .receiptPhotoFilename)
    }
}
