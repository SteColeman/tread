import Foundation
import UIKit
import WidgetKit

nonisolated struct WidgetShoeSnapshot: Codable, Sendable {
    let id: String
    let name: String
    let brand: String
    let typeIcon: String
    let colorHex: String
    let usedKm: Double
    let goalKm: Double
    let percent: Double
    let photoFilename: String?

    var remainingKm: Double { max(0, goalKm - usedKm) }
}

nonisolated struct WidgetSnapshot: Codable, Sendable {
    let active: WidgetShoeSnapshot?
    let others: [WidgetShoeSnapshot]
    let updatedAt: Date

    static let empty = WidgetSnapshot(active: nil, others: [], updatedAt: .now)
}

nonisolated final class WidgetSnapshotService: Sendable {
    static let shared = WidgetSnapshotService()
    static let appGroup = "group.app.rork.xjflp89i7jiplm22eucmj.tread"
    static let snapshotKey = "tread_widget_snapshot_v1"
    static let widgetKind = "TreadWidget"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroup)
    }

    private var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    }

    private var photosDir: URL? {
        guard let container = sharedContainer else { return nil }
        let dir = container.appendingPathComponent("widget-photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func save(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let defaults = sharedDefaults,
              let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Self.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func writeThumbnail(_ image: UIImage, for shoeId: UUID) -> String? {
        guard let dir = photosDir else { return nil }
        let resized = image.widgetThumbnail()
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(shoeId.uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    func clearThumbnails(keeping ids: Set<UUID>) {
        guard let dir = photosDir else { return }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let keep = Set(ids.map { "\($0.uuidString).jpg" })
        for f in files where !keep.contains(f) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
    }
}

private extension UIImage {
    nonisolated func widgetThumbnail() -> UIImage {
        let target: CGFloat = 320
        let maxSide = max(size.width, size.height)
        guard maxSide > target else { return self }
        let scale = target / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
