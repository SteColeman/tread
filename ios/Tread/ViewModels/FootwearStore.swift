import Foundation

@Observable
@MainActor
class FootwearStore {
    var footwear: [FootwearItem] = []
    var sessions: [WearSession] = []
    var conditionLogs: [ConditionLog] = []

    var isSyncing: Bool = false
    var lastSyncedAt: Date?
    var syncError: String?

    private let persistence = PersistenceService.shared
    private let sync = SyncService.shared
    private(set) var userId: UUID?

    var activeFootwear: [FootwearItem] {
        footwear.filter { $0.status == .active }
    }

    var retiredFootwear: [FootwearItem] {
        footwear.filter { $0.status == .retired }
    }

    var defaultPair: FootwearItem? {
        footwear.first(where: { $0.isDefault && $0.status == .active })
    }

    var unassignedSessions: [WearSession] {
        sessions.filter { !$0.isAssigned }
    }

    func load() {
        footwear = persistence.loadFootwear()
        sessions = persistence.loadSessions()
        conditionLogs = persistence.loadConditionLogs()
    }

    func attach(userId: UUID?) async {
        self.userId = userId
        guard let userId else { return }
        await fullSync(userId: userId)
    }

    func fullSync(userId: UUID) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let remote = try await sync.pull(userId: userId)

            footwear = mergeFootwear(local: footwear, remote: remote.footwear)
            sessions = mergeSessions(local: sessions, remote: remote.sessions)
            conditionLogs = mergeLogs(local: conditionLogs, remote: remote.logs)

            try await sync.pushFootwear(footwear, userId: userId)
            try await sync.pushSessions(sessions, userId: userId)
            try await sync.pushLogs(conditionLogs, userId: userId)

            persist()
            lastSyncedAt = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func mergeFootwear(local: [FootwearItem], remote: [FootwearItem]) -> [FootwearItem] {
        var byId: [UUID: FootwearItem] = [:]
        for item in remote { byId[item.id] = item }
        for item in local { byId[item.id] = item }
        return Array(byId.values).sorted { $0.dateAdded < $1.dateAdded }
    }

    private func mergeSessions(local: [WearSession], remote: [WearSession]) -> [WearSession] {
        var byId: [UUID: WearSession] = [:]
        for s in remote { byId[s.id] = s }
        for s in local { byId[s.id] = s }
        return Array(byId.values).sorted { $0.date > $1.date }
    }

    private func mergeLogs(local: [ConditionLog], remote: [ConditionLog]) -> [ConditionLog] {
        var byId: [UUID: ConditionLog] = [:]
        for l in remote { byId[l.id] = l }
        for l in local { byId[l.id] = l }
        return Array(byId.values).sorted { $0.date > $1.date }
    }

    func addFootwear(_ item: FootwearItem) {
        var newItem = item
        if newItem.isDefault {
            clearDefaultStatus()
        }
        footwear.append(newItem)
        save()
        pushFootwearRemote([newItem])
        if newItem.isDefault { pushFootwearRemote(footwear) }
    }

    func updateFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        if item.isDefault {
            clearDefaultStatus()
        }
        footwear[index] = item
        save()
        pushFootwearRemote(footwear)
    }

    func deleteFootwear(_ item: FootwearItem) {
        footwear.removeAll { $0.id == item.id }
        sessions = sessions.map { session in
            guard session.footwearId == item.id else { return session }
            var updated = session
            updated.footwearId = nil
            return updated
        }
        conditionLogs.removeAll { $0.footwearId == item.id }
        save()
        if let userId {
            Task { try? await sync.deleteFootwear(id: item.id, userId: userId) }
            pushSessionsRemote(sessions)
        }
    }

    func setAsDefault(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        clearDefaultStatus()
        footwear[index].isDefault = true
        if footwear[index].status == .retired {
            footwear[index].status = .active
        }
        save()
        pushFootwearRemote(footwear)
    }

    func clearDefault() {
        clearDefaultStatus()
        save()
        pushFootwearRemote(footwear)
    }

    func retireFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        footwear[index].status = .retired
        footwear[index].isDefault = false
        save()
        pushFootwearRemote([footwear[index]])
    }

    func reactivateFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        footwear[index].status = .active
        save()
        pushFootwearRemote([footwear[index]])
    }

    private func clearDefaultStatus() {
        for i in footwear.indices {
            footwear[i].isDefault = false
        }
    }

    func addSession(_ session: WearSession) {
        sessions.append(session)
        save()
        pushSessionsRemote([session])
    }

    func assignSession(_ sessionId: UUID, to footwearId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].footwearId = footwearId
        save()
        pushSessionsRemote([sessions[index]])
    }

    func assignAllUnassigned(to footwearId: UUID) {
        var changed: [WearSession] = []
        for i in sessions.indices where sessions[i].footwearId == nil {
            sessions[i].footwearId = footwearId
            changed.append(sessions[i])
        }
        save()
        pushSessionsRemote(changed)
    }

    func addConditionLog(_ log: ConditionLog) {
        conditionLogs.append(log)
        save()
        pushLogsRemote([log])
    }

    func totalDistance(for footwearId: UUID) -> Double {
        sessions
            .filter { $0.footwearId == footwearId }
            .reduce(0) { $0 + $1.distanceKm }
    }

    func totalSteps(for footwearId: UUID) -> Int {
        sessions
            .filter { $0.footwearId == footwearId }
            .reduce(0) { $0 + $1.steps }
    }

    func sessionCount(for footwearId: UUID) -> Int {
        sessions.filter { $0.footwearId == footwearId }.count
    }

    func latestCondition(for footwearId: UUID) -> ConditionLog? {
        conditionLogs
            .filter { $0.footwearId == footwearId }
            .sorted { $0.date > $1.date }
            .first
    }

    func conditionHistory(for footwearId: UUID) -> [ConditionLog] {
        conditionLogs
            .filter { $0.footwearId == footwearId }
            .sorted { $0.date > $1.date }
    }

    func lifecyclePercentage(for item: FootwearItem) -> Double {
        let distance = totalDistance(for: item.id)
        guard item.expectedLifespanKm > 0 else { return 0 }
        return min(distance / item.expectedLifespanKm, 1.0)
    }

    func sessionsForFootwear(_ footwearId: UUID) -> [WearSession] {
        sessions
            .filter { $0.footwearId == footwearId }
            .sorted { $0.date > $1.date }
    }

    func importHealthKitData(_ dailyData: [(date: Date, steps: Int, distanceKm: Double)]) {
        let calendar = Calendar.current
        var newSessions: [WearSession] = []
        for day in dailyData {
            let dayStart = calendar.startOfDay(for: day.date)
            let alreadyExists = sessions.contains { calendar.isDate($0.date, inSameDayAs: dayStart) && !$0.isManual }
            guard !alreadyExists, day.steps > 0 else { continue }

            let session = WearSession(
                date: dayStart,
                steps: day.steps,
                distanceKm: day.distanceKm
            )
            sessions.append(session)
            newSessions.append(session)
        }

        if let defaultItem = defaultPair {
            for i in sessions.indices where sessions[i].footwearId == nil {
                sessions[i].footwearId = defaultItem.id
            }
        }

        save()
        if !newSessions.isEmpty {
            pushSessionsRemote(sessions)
        }
    }

    func mostWornPair() -> FootwearItem? {
        activeFootwear
            .max(by: { totalDistance(for: $0.id) < totalDistance(for: $1.id) })
    }

    func leastWornPair() -> FootwearItem? {
        let active = activeFootwear
        guard active.count > 1 else { return nil }
        return active.min(by: { totalDistance(for: $0.id) < totalDistance(for: $1.id) })
    }

    func pairsNearingRetirement() -> [FootwearItem] {
        activeFootwear.filter { lifecyclePercentage(for: $0) >= 0.8 }
    }

    func clearLocalAndRemote() async {
        if let userId {
            try? await sync.wipe(userId: userId)
        }
        footwear = []
        sessions = []
        conditionLogs = []
        persist()
    }

    private func save() {
        persist()
    }

    private func persist() {
        persistence.saveFootwear(footwear)
        persistence.saveSessions(sessions)
        persistence.saveConditionLogs(conditionLogs)
    }

    private func pushFootwearRemote(_ items: [FootwearItem]) {
        guard let userId else { return }
        Task { [sync] in try? await sync.pushFootwear(items, userId: userId) }
    }

    private func pushSessionsRemote(_ sessions: [WearSession]) {
        guard let userId else { return }
        Task { [sync] in try? await sync.pushSessions(sessions, userId: userId) }
    }

    private func pushLogsRemote(_ logs: [ConditionLog]) {
        guard let userId else { return }
        Task { [sync] in try? await sync.pushLogs(logs, userId: userId) }
    }
}
