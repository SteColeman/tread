import Foundation

nonisolated enum StrikePattern: String, Codable, Sendable, CaseIterable {
    case heel = "Heel"
    case midfoot = "Midfoot"
    case forefoot = "Forefoot"
    case mixed = "Mixed"

    var icon: String {
        switch self {
        case .heel: return "arrow.down.to.line"
        case .midfoot: return "arrow.left.and.right"
        case .forefoot: return "arrow.up.to.line"
        case .mixed: return "scribble.variable"
        }
    }
}

nonisolated enum Pronation: String, Codable, Sendable, CaseIterable {
    case neutral = "Neutral"
    case over = "Overpronation"
    case under = "Underpronation"
    case unclear = "Unclear"

    var subtitle: String {
        switch self {
        case .neutral: return "Even wear across the foot"
        case .over: return "More wear on the inner edge"
        case .under: return "More wear on the outer edge"
        case .unclear: return "Not enough signal yet"
        }
    }
}

nonisolated enum WearZone: String, Codable, Sendable, CaseIterable {
    case heelOuter = "Outer Heel"
    case heelInner = "Inner Heel"
    case heelCenter = "Center Heel"
    case midfootOuter = "Outer Midfoot"
    case midfootInner = "Inner Midfoot"
    case forefootOuter = "Outer Forefoot"
    case forefootInner = "Inner Forefoot"
    case bigToe = "Big Toe"
    case generalEven = "Even"
}

nonisolated struct InjuryNote: Codable, Sendable, Hashable {
    let title: String
    let body: String
    let severity: Int // 1..3
}

/// 12 cols x 20 rows heatmap. Values 0..1 where 1 = most worn.
nonisolated struct HeatmapGrid: Codable, Sendable, Hashable {
    let cols: Int
    let rows: Int
    let values: [Double]

    static let columns = 12
    static let rowsCount = 20

    init(cols: Int = HeatmapGrid.columns, rows: Int = HeatmapGrid.rowsCount, values: [Double]) {
        self.cols = cols
        self.rows = rows
        self.values = values
    }

    static var empty: HeatmapGrid {
        HeatmapGrid(values: Array(repeating: 0.0, count: columns * rowsCount))
    }
}

nonisolated enum ScanShot: String, Codable, Sendable, CaseIterable {
    case heel
    case midfoot
    case forefoot

    var title: String {
        switch self {
        case .heel: return "Heel"
        case .midfoot: return "Midfoot"
        case .forefoot: return "Forefoot"
        }
    }

    var instruction: String {
        switch self {
        case .heel: return "Frame the heel block with the camera straight on."
        case .midfoot: return "Center the arch and middle of the outsole."
        case .forefoot: return "Frame the toe area, including the big toe."
        }
    }
}

nonisolated struct ScanShotData: Codable, Sendable, Hashable {
    let shot: ScanShot
    let photoFilename: String
    let heatmap: HeatmapGrid
}

nonisolated struct WearScan: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var footwearId: UUID
    var date: Date
    var kmAtScan: Double
    var stepsAtScan: Int

    var score: Int          // 0..100 — 0 fresh, 100 trashed
    var verdict: String
    var estimatedKmRemaining: Double
    var estimatedKmTotalLife: Double

    var strikePattern: StrikePattern
    var pronation: Pronation
    var dominantZones: [WearZone]
    var injuryNotes: [InjuryNote]

    var shots: [ScanShotData]
    var isBaseline: Bool

    init(
        id: UUID = UUID(),
        footwearId: UUID,
        date: Date = Date(),
        kmAtScan: Double,
        stepsAtScan: Int,
        score: Int,
        verdict: String,
        estimatedKmRemaining: Double,
        estimatedKmTotalLife: Double,
        strikePattern: StrikePattern,
        pronation: Pronation,
        dominantZones: [WearZone],
        injuryNotes: [InjuryNote],
        shots: [ScanShotData],
        isBaseline: Bool = false
    ) {
        self.id = id
        self.footwearId = footwearId
        self.date = date
        self.kmAtScan = kmAtScan
        self.stepsAtScan = stepsAtScan
        self.score = score
        self.verdict = verdict
        self.estimatedKmRemaining = estimatedKmRemaining
        self.estimatedKmTotalLife = estimatedKmTotalLife
        self.strikePattern = strikePattern
        self.pronation = pronation
        self.dominantZones = dominantZones
        self.injuryNotes = injuryNotes
        self.shots = shots
        self.isBaseline = isBaseline
    }

    var scoreBand: ScoreBand {
        switch score {
        case ..<40: return .fresh
        case 40..<70: return .moderate
        default: return .worn
        }
    }
}

nonisolated enum ScoreBand: Sendable {
    case fresh, moderate, worn

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .moderate: return "Moderate"
        case .worn: return "Worn"
        }
    }
}
