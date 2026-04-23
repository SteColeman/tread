import SwiftUI

struct FootwearCard: View {
    let item: FootwearItem
    @Environment(FootwearStore.self) private var store

    private var colorTag: ColorTag {
        ColorTag(rawValue: item.colorTag) ?? .slate
    }

    private var distance: Double {
        store.totalDistance(for: item.id)
    }

    private var lifecyclePercent: Double {
        store.lifecyclePercentage(for: item)
    }

    private var daysSinceLastWorn: Int? {
        guard let lastSession = store.sessionsForFootwear(item.id).first else { return nil }
        return Calendar.current.dateComponents([.day], from: lastSession.date, to: Date()).day
    }

    private var wornLabel: String {
        guard let days = daysSinceLastWorn else { return "Not worn yet" }
        if days == 0 { return "Worn today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }

    var body: some View {
        HStack(spacing: 16) {
            accentRail

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if item.isDefault {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    Spacer(minLength: 0)

                    Text(distance.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(.title3, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        + Text(" km")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 6) {
                    Image(systemName: item.type.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colorTag.color)
                    Text(item.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)

                    if !item.brand.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text(item.brand)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if item.status == .retired {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text("RETIRED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    lifecycleBar
                        .frame(maxWidth: .infinity)
                    Text(wornLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var accentRail: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(colorTag.color.gradient)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .center) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        Circle().fill(colorTag.color.gradient)
                    )
            }
            .frame(width: 36)
    }

    private var lifecycleBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 3)

                Capsule()
                    .fill(lifecycleBarColor.gradient)
                    .frame(width: max(3, geo.size.width * lifecyclePercent), height: 3)
            }
        }
        .frame(height: 3)
    }

    private var lifecycleBarColor: Color {
        if lifecyclePercent >= 0.9 { return .red }
        if lifecyclePercent >= 0.7 { return .orange }
        return colorTag.color
    }
}
