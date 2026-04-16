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

    private var latestCondition: ConditionLog? {
        store.latestCondition(for: item.id)
    }

    private var daysSinceLastWorn: Int? {
        guard let lastSession = store.sessionsForFootwear(item.id).first else { return nil }
        return Calendar.current.dateComponents([.day], from: lastSession.date, to: Date()).day
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                colorBadge

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                            .lineLimit(1)

                        if item.isDefault {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }

                        if item.status == .retired {
                            Text("RETIRED")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack(spacing: 6) {
                        if !item.brand.isEmpty {
                            Text(item.brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(distance.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(.title3, design: .default, weight: .bold))
                        .monospacedDigit()
                    Text("km")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                lifecycleBar
                    .frame(maxWidth: .infinity)

                if let days = daysSinceLastWorn {
                    Text(days == 0 ? "Worn today" : days == 1 ? "1 day ago" : "\(days)d ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var colorBadge: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorTag.color.gradient)
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: item.type.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }

    private var lifecycleBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 5)

                Capsule()
                    .fill(lifecycleBarColor.gradient)
                    .frame(width: max(5, geo.size.width * lifecyclePercent), height: 5)
            }
        }
        .frame(height: 5)
    }

    private var lifecycleBarColor: Color {
        if lifecyclePercent >= 0.9 { return .red }
        if lifecyclePercent >= 0.7 { return .orange }
        return colorTag.color
    }
}
