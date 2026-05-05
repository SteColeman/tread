import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model (mirrors WidgetSnapshotService in main target)

nonisolated struct WGShoe: Codable, Sendable {
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

nonisolated struct WGSnapshot: Codable, Sendable {
    let active: WGShoe?
    let others: [WGShoe]
    let updatedAt: Date

    static let appGroup = "group.app.rork.xjflp89i7jiplm22eucmj.tread"
    static let snapshotKey = "tread_widget_snapshot_v1"

    static func load() -> WGSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: snapshotKey) else {
            return WGSnapshot(active: nil, others: [], updatedAt: .now)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WGSnapshot.self, from: data))
            ?? WGSnapshot(active: nil, others: [], updatedAt: .now)
    }

    static func loadPhoto(_ filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let url = container.appendingPathComponent("widget-photos", isDirectory: true)
            .appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static let sample = WGSnapshot(
        active: WGShoe(
            id: UUID().uuidString,
            name: "Pegasus 41",
            brand: "Nike",
            typeIcon: "figure.run",
            colorHex: "#5C7E9C",
            usedKm: 410,
            goalKm: 800,
            percent: 0.51,
            photoFilename: nil
        ),
        others: [
            WGShoe(id: UUID().uuidString, name: "Cloud 5", brand: "On", typeIcon: "shoe.fill", colorHex: "#9C7050", usedKm: 120, goalKm: 800, percent: 0.15, photoFilename: nil),
            WGShoe(id: UUID().uuidString, name: "Speedgoat", brand: "Hoka", typeIcon: "mountain.2.fill", colorHex: "#6B8E5A", usedKm: 720, goalKm: 1600, percent: 0.45, photoFilename: nil)
        ],
        updatedAt: .now
    )
}

// MARK: - Provider

nonisolated struct TreadEntry: TimelineEntry {
    let date: Date
    let snapshot: WGSnapshot
}

nonisolated struct TreadProvider: TimelineProvider {
    func placeholder(in context: Context) -> TreadEntry {
        TreadEntry(date: .now, snapshot: WGSnapshot.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TreadEntry) -> Void) {
        let snap = context.isPreview ? WGSnapshot.sample : WGSnapshot.load()
        completion(TreadEntry(date: .now, snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TreadEntry>) -> Void) {
        let snap = WGSnapshot.load()
        let entry = TreadEntry(date: .now, snapshot: snap)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Helpers

@MainActor
private func progressColor(_ percent: Double) -> Color {
    if percent >= 0.9 { return .red }
    if percent >= 0.75 { return .orange }
    if percent >= 0.5 { return Color(red: 0.85, green: 0.72, blue: 0.30) }
    return Color(red: 0.36, green: 0.62, blue: 0.45)
}

@MainActor
private func remainingText(_ km: Double) -> String {
    if km <= 0 { return "Replace" }
    if km >= 1000 {
        return "\((km / 1000).formatted(.number.precision(.fractionLength(1))))k km"
    }
    return "\(Int(km)) km"
}

private func colorFromHex(_ hex: String) -> Color {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return .gray }
    let r = Double((v >> 16) & 0xff) / 255
    let g = Double((v >> 8) & 0xff) / 255
    let b = Double(v & 0xff) / 255
    return Color(red: r, green: g, blue: b)
}

// MARK: - Sub views

struct ShoeRing: View {
    let percent: Double
    let color: Color
    let lineWidth: CGFloat
    var showPercent: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(percent, 1.0)))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showPercent {
                Text("\(Int(min(percent, 1.0) * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
            }
        }
    }
}

struct ShoeThumb: View {
    let shoe: WGShoe
    let size: CGFloat

    var body: some View {
        let tag = colorFromHex(shoe.colorHex)
        Group {
            if let img = WGSnapshot.loadPhoto(shoe.photoFilename) {
                Color.gray.opacity(0.15)
                    .overlay {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
            } else {
                LinearGradient(
                    colors: [tag, tag.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: shoe.typeIcon)
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
    }
}

// MARK: - Small

struct SmallView: View {
    let entry: TreadEntry

    var body: some View {
        if let shoe = entry.snapshot.active {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ShoeThumb(shoe: shoe, size: 44)
                    Spacer()
                    ShoeRing(percent: shoe.percent, color: progressColor(shoe.percent), lineWidth: 5)
                        .frame(width: 36, height: 36)
                }

                Spacer(minLength: 6)

                Text(shoe.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 3) {
                    Text(remainingText(shoe.remainingKm))
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(progressColor(shoe.percent))
                    Text("left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .widgetURL(URL(string: "tread://shoe/\(shoe.id)"))
        } else {
            EmptyStateView()
        }
    }
}

// MARK: - Medium

struct MediumView: View {
    let entry: TreadEntry

    var body: some View {
        if let shoe = entry.snapshot.active {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ShoeThumb(shoe: shoe, size: 46)
                        ShoeRing(percent: shoe.percent, color: progressColor(shoe.percent), lineWidth: 5)
                            .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(shoe.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Text(remainingText(shoe.remainingKm))
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(progressColor(shoe.percent))
                            Text("left")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ROTATION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.tertiary)

                    if entry.snapshot.others.isEmpty {
                        Text("Add another pair to start rotating.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        ForEach(entry.snapshot.others.prefix(2), id: \.id) { other in
                            otherRow(other)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .widgetURL(URL(string: "tread://shoe/\(shoe.id)"))
        } else {
            EmptyStateView()
        }
    }

    private func otherRow(_ shoe: WGShoe) -> some View {
        HStack(spacing: 8) {
            ShoeThumb(shoe: shoe, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(shoe.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(progressColor(shoe.percent).gradient)
                            .frame(width: max(2, geo.size.width * min(shoe.percent, 1.0)))
                    }
                }
                .frame(height: 3)
            }
        }
    }
}

// MARK: - Lock screen

struct CircularView: View {
    let entry: TreadEntry

    var body: some View {
        if let shoe = entry.snapshot.active {
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.001, min(shoe.percent, 1.0)))
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(shoe.percent, 1.0) * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
            }
        } else {
            Image(systemName: "shoe.2")
                .font(.system(size: 18, weight: .medium))
        }
    }
}

struct RectangularView: View {
    let entry: TreadEntry

    var body: some View {
        if let shoe = entry.snapshot.active {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "shoe.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(shoe.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                Text("\(remainingText(shoe.remainingKm)) left")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: max(3, geo.size.width * min(shoe.percent, 1.0)))
                    }
                }
                .frame(height: 3)
            }
        } else {
            Text("Set an active pair in Tread")
                .font(.system(size: 12, weight: .medium))
        }
    }
}

struct InlineView: View {
    let entry: TreadEntry

    var body: some View {
        if let shoe = entry.snapshot.active {
            Text("\(shoe.name) · \(remainingText(shoe.remainingKm)) left")
        } else {
            Text("No active pair")
        }
    }
}

// MARK: - Empty

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shoe.2")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Text("Set an active pair")
                .font(.system(size: 12, weight: .semibold))
            Text("in the Tread app")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Entry switch

struct TreadEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TreadEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(entry: entry)
        case .systemMedium:
            MediumView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            SmallView(entry: entry)
        }
    }
}

// MARK: - Widget

struct TreadWidget: Widget {
    let kind: String = "TreadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TreadProvider()) { entry in
            TreadEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Active Pair")
        .description("Track miles remaining on your go-to shoes.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
