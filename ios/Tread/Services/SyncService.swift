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

nonisolated struct RemoteSnapshot: Sendable {
    let footwear: [FootwearItem]
    let sessions: [WearSession]
    let logs: [ConditionLog]
}

nonisolated final class SyncService: Sendable {
    static let shared = SyncService()

    private var client: SupabaseClient? { SupabaseClientProvider.shared }

    func pull(userId: UUID) async throws -> RemoteSnapshot {
        guard let client else {
            return RemoteSnapshot(footwear: [], sessions: [], logs: [])
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

        return RemoteSnapshot(
            footwear: footwearRows.map { $0.toModel() },
            sessions: sessionRows.map { $0.toModel() },
            logs: logRows.map { $0.toModel() }
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
    }
}
