import Foundation
import HealthKit

@Observable
@MainActor
class HealthKitService {
    var isAuthorized = false
    var authorizationError: String?

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isAvailable else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        let typesToRead: Set<HKSampleType> = [stepType, distanceType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
        } catch {
            authorizationError = error.localizedDescription
        }
    }

    func fetchDailyData(for date: Date) async -> (steps: Int, distanceKm: Double) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (0, 0.0)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        async let steps = fetchSum(for: stepType, unit: .count(), predicate: predicate)
        async let distance = fetchSum(for: distanceType, unit: .meterUnit(with: .kilo), predicate: predicate)

        return await (Int(steps), distance)
    }

    func fetchWeeklyData() async -> [(date: Date, steps: Int, distanceKm: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var results: [(date: Date, steps: Int, distanceKm: Double)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let data = await fetchDailyData(for: date)
            results.append((date: date, steps: data.steps, distanceKm: data.distanceKm))
        }

        return results
    }

    private nonisolated func fetchSum(for type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}
