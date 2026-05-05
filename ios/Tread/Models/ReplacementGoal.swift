import Foundation
import SwiftUI

nonisolated enum ReplacementGoalPreset: String, CaseIterable, Identifiable, Sendable {
    case trainers
    case dailyWalker
    case hiker
    case casual
    case heavyDuty
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trainers: return "Trainers"
        case .dailyWalker: return "Daily Walker"
        case .hiker: return "Hiker"
        case .casual: return "Casual"
        case .heavyDuty: return "Heavy Duty"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .trainers: return "figure.run"
        case .dailyWalker: return "figure.walk"
        case .hiker: return "mountain.2.fill"
        case .casual: return "shoe.fill"
        case .heavyDuty: return "shield.lefthalf.filled"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Distance in kilometers. Values map roughly to common mileage guidance.
    var distanceKm: Double {
        switch self {
        case .trainers: return 800       // ~500 mi
        case .dailyWalker: return 1100   // ~700 mi
        case .hiker: return 1600         // ~1000 mi
        case .casual: return 2400        // ~1500 mi
        case .heavyDuty: return 3200     // ~2000 mi
        case .custom: return 800
        }
    }

    var subtitle: String {
        switch self {
        case .trainers: return "800 km · daily trainers"
        case .dailyWalker: return "1,100 km · everyday walks"
        case .hiker: return "1,600 km · trail & boot"
        case .casual: return "2,400 km · light wear"
        case .heavyDuty: return "3,200 km · workwear"
        case .custom: return "Set your own"
        }
    }

    static func bestMatch(forKm km: Double) -> ReplacementGoalPreset {
        let values: [ReplacementGoalPreset] = [.trainers, .dailyWalker, .hiker, .casual, .heavyDuty]
        if let exact = values.first(where: { abs($0.distanceKm - km) < 1 }) {
            return exact
        }
        return .custom
    }
}
