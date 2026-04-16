import Foundation

nonisolated struct WearSession: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var date: Date
    var steps: Int
    var distanceKm: Double
    var footwearId: UUID?
    var isManual: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        steps: Int,
        distanceKm: Double,
        footwearId: UUID? = nil,
        isManual: Bool = false
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.distanceKm = distanceKm
        self.footwearId = footwearId
        self.isManual = isManual
    }

    var isAssigned: Bool { footwearId != nil }
}
