import Foundation

@Observable
@MainActor
class FootwearStore {
    var footwear: [FootwearItem] = []
    var sessions: [WearSession] = []
    var conditionLogs: [ConditionLog] = []

    private let persistence = PersistenceService.shared

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

    func addFootwear(_ item: FootwearItem) {
        var newItem = item
        if newItem.isDefault {
            clearDefaultStatus()
        }
        footwear.append(newItem)
        save()
    }

    func updateFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        if item.isDefault {
            clearDefaultStatus()
        }
        footwear[index] = item
        save()
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
    }

    func setAsDefault(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        clearDefaultStatus()
        footwear[index].isDefault = true
        if footwear[index].status == .retired {
            footwear[index].status = .active
        }
        save()
    }

    func clearDefault() {
        clearDefaultStatus()
        save()
    }

    func retireFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        footwear[index].status = .retired
        footwear[index].isDefault = false
        save()
    }

    func reactivateFootwear(_ item: FootwearItem) {
        guard let index = footwear.firstIndex(where: { $0.id == item.id }) else { return }
        footwear[index].status = .active
        save()
    }

    private func clearDefaultStatus() {
        for i in footwear.indices {
            footwear[i].isDefault = false
        }
    }

    func addSession(_ session: WearSession) {
        sessions.append(session)
        save()
    }

    func assignSession(_ sessionId: UUID, to footwearId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].footwearId = footwearId
        save()
    }

    func assignAllUnassigned(to footwearId: UUID) {
        for i in sessions.indices where sessions[i].footwearId == nil {
            sessions[i].footwearId = footwearId
        }
        save()
    }

    func addConditionLog(_ log: ConditionLog) {
        conditionLogs.append(log)
        save()
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
        }

        if let defaultItem = defaultPair {
            for i in sessions.indices where sessions[i].footwearId == nil {
                sessions[i].footwearId = defaultItem.id
            }
        }

        save()
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

    private func save() {
        persistence.saveFootwear(footwear)
        persistence.saveSessions(sessions)
        persistence.saveConditionLogs(conditionLogs)
    }
}
