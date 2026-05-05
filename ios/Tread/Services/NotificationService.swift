import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized: Bool = false
    var hasRequested: Bool = false

    // Stored preferences
    var masterEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif_master") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notif_master"); refreshSchedules() }
    }

    var lifeWarningEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif_life80") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notif_life80"); refreshSchedules() }
    }

    var weeklySummaryEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif_weekly") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notif_weekly"); refreshSchedules() }
    }

    var monthlyCheckInEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif_monthly") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notif_monthly"); refreshSchedules() }
    }

    // Tracks which shoes have already had their 80% warning fired
    private let firedWarningsKey = "notif_fired_life80_ids"

    private var firedWarningIds: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: firedWarningsKey) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: firedWarningsKey)
        }
    }

    func bootstrap() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        hasRequested = settings.authorizationStatus != .notDetermined
        refreshSchedules()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            hasRequested = true
            isAuthorized = granted
            refreshSchedules()
            return granted
        } catch {
            hasRequested = true
            return false
        }
    }

    // Called whenever toggles change or shoe data changes
    func refreshSchedules() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_summary", "monthly_checkin"])

        guard isAuthorized && masterEnabled else { return }

        if weeklySummaryEnabled {
            scheduleWeekly()
        }
        if monthlyCheckInEnabled {
            scheduleMonthly()
        }
    }

    private func scheduleWeekly() {
        var comps = DateComponents()
        comps.weekday = 1 // Sunday
        comps.hour = 19
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Your week in shoes"
        content.body = "Tap to see how each pair held up this week."
        content.sound = .default
        content.userInfo = ["type": "weekly_summary"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMonthly() {
        var comps = DateComponents()
        comps.day = 1
        comps.hour = 10
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Time for a quick check-in"
        content.body = "Log how your active pair is feeling — it only takes a few seconds."
        content.sound = .default
        content.userInfo = ["type": "monthly_checkin"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly_checkin", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fire the 80% warning for any shoe that just crossed the threshold.
    func evaluateLifeWarnings(items: [(name: String, percent: Double, id: UUID)]) {
        guard isAuthorized && masterEnabled && lifeWarningEnabled else { return }

        var fired = firedWarningIds
        let center = UNUserNotificationCenter.current()

        for item in items {
            let key = item.id.uuidString
            let crossed = item.percent >= 0.8
            if crossed && !fired.contains(key) {
                let content = UNMutableNotificationContent()
                content.title = "\(item.name) is at \(Int(min(item.percent, 1.0) * 100))%"
                content.body = item.percent >= 1.0
                    ? "You've passed the replacement goal. Time to start looking for a new pair."
                    : "Start thinking about your next pair — we'll keep tracking until you retire them."
                content.sound = .default
                content.userInfo = ["type": "life_warning", "shoeId": key]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let request = UNNotificationRequest(identifier: "life80_\(key)", content: content, trigger: trigger)
                center.add(request)

                fired.insert(key)
            } else if !crossed && fired.contains(key) {
                // Reset (e.g. user raised the goal or reset progress)
                fired.remove(key)
            }
        }

        firedWarningIds = fired
    }

    func clearFiredWarning(for id: UUID) {
        var fired = firedWarningIds
        fired.remove(id.uuidString)
        firedWarningIds = fired
    }
}
