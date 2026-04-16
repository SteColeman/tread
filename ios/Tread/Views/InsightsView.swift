import SwiftUI

struct InsightsView: View {
    @Environment(FootwearStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.activeFootwear.isEmpty {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.04))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            VStack(spacing: 6) {
                                Text("No Insights Yet")
                                    .font(.title3.bold())
                                Text("Add footwear and log some activity to see rotation and lifecycle insights.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 80)
                        .padding(.horizontal, 40)
                    } else {
                        rotationOverview
                        lifecycleAlerts
                        wearDistribution
                        rotationBalance
                        summaryGrid
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }

    private var rotationOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rotation")
                .font(.headline)

            VStack(spacing: 0) {
                if let mostWorn = store.mostWornPair() {
                    RotationRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: .orange,
                        title: "Most Worn",
                        name: mostWorn.name,
                        value: "\(store.totalDistance(for: mostWorn.id).formatted(.number.precision(.fractionLength(1)))) km",
                        colorTag: ColorTag(rawValue: mostWorn.colorTag) ?? .slate
                    )
                }

                if let leastWorn = store.leastWornPair() {
                    Divider().padding(.leading, 48)
                    RotationRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: .blue,
                        title: "Least Worn",
                        name: leastWorn.name,
                        value: "\(store.totalDistance(for: leastWorn.id).formatted(.number.precision(.fractionLength(1)))) km",
                        colorTag: ColorTag(rawValue: leastWorn.colorTag) ?? .slate
                    )
                }

                if let defaultPair = store.defaultPair {
                    Divider().padding(.leading, 48)
                    RotationRow(
                        icon: "star.circle.fill",
                        iconColor: .yellow,
                        title: "Default Pair",
                        name: defaultPair.name,
                        value: "\(store.totalDistance(for: defaultPair.id).formatted(.number.precision(.fractionLength(1)))) km",
                        colorTag: ColorTag(rawValue: defaultPair.colorTag) ?? .slate
                    )
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var lifecycleAlerts: some View {
        Group {
            let nearRetirement = store.pairsNearingRetirement()

            if !nearRetirement.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Attention")
                            .font(.headline)
                    }

                    VStack(spacing: 10) {
                        ForEach(nearRetirement) { item in
                            let percent = store.lifecyclePercentage(for: item)
                            let distance = store.totalDistance(for: item.id)
                            let colorTag = ColorTag(rawValue: item.colorTag) ?? .slate

                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorTag.color.gradient)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Image(systemName: item.type.icon)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(distance.formatted(.number.precision(.fractionLength(0)))) / \(item.expectedLifespanKm.formatted(.number.precision(.fractionLength(0)))) km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(Int(percent * 100))%")
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.orange.opacity(0.06))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var wearDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wear Distribution")
                .font(.headline)

            let totalKm = store.activeFootwear.reduce(0.0) { $0 + store.totalDistance(for: $1.id) }

            if totalKm > 0 {
                let sorted = store.activeFootwear.sorted(by: { store.totalDistance(for: $0.id) > store.totalDistance(for: $1.id) })

                VStack(spacing: 0) {
                    distributionBar(items: sorted, totalKm: totalKm)
                        .padding(.bottom, 14)

                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                        let distance = store.totalDistance(for: item.id)
                        let proportion = distance / totalKm
                        let colorTag = ColorTag(rawValue: item.colorTag) ?? .slate

                        if index > 0 {
                            Divider().padding(.leading, 20)
                        }

                        HStack(spacing: 10) {
                            Circle()
                                .fill(colorTag.color.gradient)
                                .frame(width: 10, height: 10)

                            Text(item.name)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(distance.formatted(.number.precision(.fractionLength(1))) + " km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Text("\(Int(proportion * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No distance data yet. Sync from Health to see your wear distribution.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func distributionBar(items: [FootwearItem], totalKm: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(items) { item in
                    let distance = store.totalDistance(for: item.id)
                    let proportion = distance / totalKm
                    let colorTag = ColorTag(rawValue: item.colorTag) ?? .slate

                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorTag.color.gradient)
                        .frame(width: max(4, (geo.size.width - CGFloat(items.count - 1) * 2) * proportion))
                }
            }
        }
        .frame(height: 12)
    }

    private var rotationBalance: some View {
        Group {
            let active = store.activeFootwear
            guard active.count >= 2 else { return AnyView(EmptyView()) }

            let distances = active.map { store.totalDistance(for: $0.id) }
            let maxDist = distances.max() ?? 1
            let minDist = distances.min() ?? 0
            let imbalance = maxDist > 0 ? (maxDist - minDist) / maxDist : 0

            let balanceLabel: String
            let balanceIcon: String
            let balanceColor: Color

            if imbalance < 0.3 {
                balanceLabel = "Well balanced"
                balanceIcon = "checkmark.circle.fill"
                balanceColor = .green
            } else if imbalance < 0.6 {
                balanceLabel = "Slightly uneven"
                balanceIcon = "minus.circle.fill"
                balanceColor = .yellow
            } else {
                balanceLabel = "Heavily unbalanced"
                balanceIcon = "exclamationmark.circle.fill"
                balanceColor = .orange
            }

            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rotation Balance")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Image(systemName: balanceIcon)
                            .font(.title2)
                            .foregroundStyle(balanceColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(balanceLabel)
                                .font(.subheadline.weight(.medium))
                            Text("Based on distance spread across \(active.count) active pairs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 14))
                }
            )
        }
    }

    private var summaryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            let totalDistance = store.sessions.reduce(0.0) { $0 + $1.distanceKm }
            let totalSteps = store.sessions.reduce(0) { $0 + $1.steps }
            let unassignedCount = store.unassignedSessions.count

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SummaryCard(
                    title: "Total Distance",
                    value: "\(totalDistance.formatted(.number.precision(.fractionLength(1)))) km",
                    icon: "map.fill"
                )
                SummaryCard(
                    title: "Total Steps",
                    value: totalSteps >= 1000 ? "\((Double(totalSteps) / 1000).formatted(.number.precision(.fractionLength(0))))k" : "\(totalSteps)",
                    icon: "figure.walk"
                )
                SummaryCard(
                    title: "Days Tracked",
                    value: "\(store.sessions.count)",
                    icon: "calendar"
                )
                SummaryCard(
                    title: "Unassigned",
                    value: "\(unassignedCount)",
                    icon: "questionmark.circle",
                    isWarning: unassignedCount > 0
                )
            }
        }
    }
}

struct RotationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let name: String
    let value: String
    let colorTag: ColorTag

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorTag.color.gradient)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    var isWarning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isWarning ? .orange : .secondary)

            Text(value)
                .font(.system(.title2, design: .default, weight: .bold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}
