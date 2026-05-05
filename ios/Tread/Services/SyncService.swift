import Foundation
import Supabase

nonisolated struct FootwearRow: Codable, Sendable {
    let id: UUID
    let user_id: UUID
    let name: String
    let brand: String
    let colorway: String?
    let type: String
    let date_added: Date
    let date_purchased: Date?
    let status: String
    let is_default: Bool
    let expected_lifespan_km: Double
    let notes: String
    let color_tag: String
    let photo_filename: String?
    let receipt_photo_filename: String?

    init(item: FootwearItem, userId: UUID) {
        self.id = item.id
        self.user_id = userId
        self.name = item.name
        self.brand = item.brand
        self.colorway = item.colorway
        self.type = item.type.rawValue
        self.date_added = item.dateAdded
        self.date_purchased = item.datePurchased
        self.status = item.status.rawValue
        self.is_default = item.isDefault
        self.expected_lifespan_km = item.expectedLifespanKm
        self.notes = item.notes
        self.color_tag = item.colorTag
        self.photo_filename = item.photoFilename
        self.receipt_photo_filename = item.receiptPhotoFilename
    }

    func toModel() -> FootwearItem {
        FootwearItem(
            id: id,
            name: name,
            brand: brand,
            colorway: colorway ?? "",
            type: FootwearType(rawValue: type) ?? .casual,
            dateAdded: date_added,
            datePurchased: date_purchased,
            status: FootwearStatus(rawValue: status) ?? .active,
            isDefault: is_default,
            expectedLifespanKm: expected_lifespan_km,
            notes: notes,
            colorTag: color_tag,
            photoFilename: photo_filename,
            receiptPhotoFilename: receipt_photo_filename
        )
    }
}

nonisolated struct WearSessionRow: Codable, Sendable {
    let id: UUID
    let user_id: UUID
    let date: Date
    let steps: Int
    let distance_km: Double
    let footwear_id: UUID?
    let is_manual: Bool

    init(session: WearSession, userId: UUID) {
        self.id = session.id
        self.user_id = userId
        self.date = session.date
        self.steps = session.steps
        self.distance_km = session.distanceKm
        self.footwear_id = session.footwearId
        self.is_manual = session.isManual
    }

    func toModel() -> WearSession {
        WearSession(
            id: id,
            date: date,
            steps: steps,
            distanceKm: distance_km,
            footwearId: footwear_id,
            isManual: is_manual
        )
    }
}

nonisolated struct ConditionLogRow: Codable, Sendable {
    let id: UUID
    let user_id: UUID
    let footwear_id: UUID
    let date: Date
    let rating: Int
    let notes: String
    let affected_areas: [String]

    init(log: ConditionLog, userId: UUID) {
        self.id = log.id
        self.user_id = userId
        self.footwear_id = log.footwearId
        self.date = log.date
        self.rating = log.rating
        self.notes = log.notes
        self.affected_areas = log.affectedAreas.map { $0.rawValue }
    }

    func toModel() -> ConditionLog {
        ConditionLog(
            id: id,
            footwearId: footwear_id,
            date: date,
            rating: rating,
            notes: notes,
            affectedAreas: affected_areas.compactMap { WearArea(rawValue: $0) }
        )
    }
}

nonisolated struct DeleteRow: Encodable, Sendable {
    let id: UUID
}

nonisolated struct WearScanRow: Codable, Sendable {
    let id: UUID
    let user_id: UUID
    let footwear_id: UUID
    let date: Date
    let km_at_scan: Double
    let steps_at_scan: Int
    let score: Int
    let verdict: String
    let estimated_km_remaining: Double
    let estimated_km_total_life: Double
    let strike_pattern: String
    let pronation: String
    let dominant_zones: [String]
    let injury_notes: String  // JSON-encoded string
    let shots: String         // JSON-encoded string
    let is_baseline: Bool

    init(scan: WearScan, userId: UUID) throws {
        self.id = scan.id
        self.user_id = userId
        self.footwear_id = scan.footwearId
        self.date = scan.date
        self.km_at_scan = scan.kmAtScan
        self.steps_at_scan = scan.stepsAtScan
        self.score = scan.score
        self.verdict = scan.verdict
        self.estimated_km_remaining = scan.estimatedKmRemaining
        self.estimated_km_total_life = scan.estimatedKmTotalLife
        self.strike_pattern = scan.strikePattern.rawValue
        self.pronation = scan.pronation.rawValue
        self.dominant_zones = scan.dominantZones.map { $0.rawValue }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let notesData = try enc.encode(scan.injuryNotes)
        self.injury_notes = String(data: notesData, encoding: .utf8) ?? "[]"
        let shotsData = try enc.encode(scan.shots)
        self.shots = String(data: shotsData, encoding: .utf8) ?? "[]"
        self.is_baseline = scan.isBaseline
    }

    func toModel() -> WearScan? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let notes: [InjuryNote] = (try? dec.decode([InjuryNote].self, from: Data(injury_notes.utf8))) ?? []
        let shotsArr: [ScanShotData] = (try? dec.decode([ScanShotData].self, from: Data(shots.utf8))) ?? []
        return WearScan(
            id: id,
            footwearId: footwear_id,
            date: date,
            kmAtScan: km_at_scan,
            stepsAtScan: steps_at_scan,
            score: score,
            verdict: verdict,
            estimatedKmRemaining: estimated_km_remaining,
            estimatedKmTotalLife: estimated_km_total_life,
            strikePattern: StrikePattern(rawValue: strike_pattern) ?? .mixed,
            pronation: Pronation(rawValue: pronation) ?? .unclear,
            dominantZones: dominant_zones.compactMap { WearZone(rawValue: $0) },
            injuryNotes: notes,
            shots: shotsArr,
            isBaseline: is_baseline
        )
    }
}

nonisolated struct RemoteSnapshot: Sendable {
    let footwear: [FootwearItem]
    let sessions: [WearSession]
    let logs: [ConditionLog]
    let scans: [WearScan]
}

nonisolated final class SyncService: Sendable {
    static let shared = SyncService()

    private var client: SupabaseClient? { SupabaseClientProvider.shared }

    func pull(userId: UUID) async throws -> RemoteSnapshot {
        guard let client else {
            return RemoteSnapshot(footwear: [], sessions: [], logs: [], scans: [])
        }

        let footwearRows: [FootwearRow] = try await client
            .from("footwear_items")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let sessionRows: [WearSessionRow] = try await client
            .from("wear_sessions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let logRows: [ConditionLogRow] = try await client
            .from("condition_logs")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        var scans: [WearScan] = []
        do {
            let scanRows: [WearScanRow] = try await client
                .from("wear_scans")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            scans = scanRows.compactMap { $0.toModel() }
        } catch {
            // Table may not exist yet — silently skip
            scans = []
        }

        return RemoteSnapshot(
            footwear: footwearRows.map { $0.toModel() },
            sessions: sessionRows.map { $0.toModel() },
            logs: logRows.map { $0.toModel() },
            scans: scans
        )
    }

    func pushFootwear(_ items: [FootwearItem], userId: UUID) async throws {
        guard let client, !items.isEmpty else { return }
        let rows = items.map { FootwearRow(item: $0, userId: userId) }
        try await client.from("footwear_items").upsert(rows).execute()
    }

    func pushSessions(_ sessions: [WearSession], userId: UUID) async throws {
        guard let client, !sessions.isEmpty else { return }
        let rows = sessions.map { WearSessionRow(session: $0, userId: userId) }
        try await client.from("wear_sessions").upsert(rows).execute()
    }

    func pushLogs(_ logs: [ConditionLog], userId: UUID) async throws {
        guard let client, !logs.isEmpty else { return }
        let rows = logs.map { ConditionLogRow(log: $0, userId: userId) }
        try await client.from("condition_logs").upsert(rows).execute()
    }

    func pushScans(_ scans: [WearScan], userId: UUID) async throws {
        guard let client, !scans.isEmpty else { return }
        let rows = try scans.map { try WearScanRow(scan: $0, userId: userId) }
        try await client.from("wear_scans").upsert(rows).execute()
    }

    func deleteScan(id: UUID, userId: UUID) async throws {
        guard let client else { return }
        try await client.from("wear_scans")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteFootwear(id: UUID, userId: UUID) async throws {
        guard let client else { return }
        try await client.from("footwear_items")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func wipe(userId: UUID) async throws {
        guard let client else { return }
        try await client.from("footwear_items").delete().eq("user_id", value: userId).execute()
        try await client.from("wear_sessions").delete().eq("user_id", value: userId).execute()
        try await client.from("condition_logs").delete().eq("user_id", value: userId).execute()
        try? await client.from("wear_scans").delete().eq("user_id", value: userId).execute()
    }
}
