import Foundation

nonisolated final class PersistenceService: Sendable {
    static let shared = PersistenceService()

    private let footwearKey = "tread_footwear_items"
    private let sessionsKey = "tread_wear_sessions"
    private let conditionLogsKey = "tread_condition_logs"

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func saveFootwear(_ items: [FootwearItem]) {
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: footwearKey)
    }

    func loadFootwear() -> [FootwearItem] {
        guard let data = UserDefaults.standard.data(forKey: footwearKey),
              let items = try? decoder.decode([FootwearItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveSessions(_ sessions: [WearSession]) {
        guard let data = try? encoder.encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }

    func loadSessions() -> [WearSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? decoder.decode([WearSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func saveConditionLogs(_ logs: [ConditionLog]) {
        guard let data = try? encoder.encode(logs) else { return }
        UserDefaults.standard.set(data, forKey: conditionLogsKey)
    }

    func loadConditionLogs() -> [ConditionLog] {
        guard let data = UserDefaults.standard.data(forKey: conditionLogsKey),
              let logs = try? decoder.decode([ConditionLog].self, from: data) else {
            return []
        }
        return logs
    }
}
