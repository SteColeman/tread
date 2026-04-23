import SwiftUI

struct CollectionView: View {
    @Environment(FootwearStore.self) private var store
    @State private var showAddSheet = false
    @State private var selectedFilter: FootwearStatus? = .active
    @State private var appeared = false

    private var filteredFootwear: [FootwearItem] {
        guard let filter = selectedFilter else { return store.footwear }
        return store.footwear.filter { $0.status == filter }
    }

    private var totalKm: Double {
        store.activeFootwear.reduce(0.0) { $0 + store.totalDistance(for: $1.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !store.footwear.isEmpty {
                        editorialHeader
                            .padding(.horizontal, 20)
                    }

                    filterBar
                        .padding(.horizontal, 20)

                    if filteredFootwear.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(filteredFootwear.enumerated()), id: \.element.id) { index, item in
                                NavigationLink(value: item) {
                                    FootwearCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if item.status == .active {
                                        if item.isDefault {
                                            Button("Clear Active Pair", systemImage: "star.slash") {
                                                store.clearDefault()
                                            }
                                        } else {
                                            Button("Set as Active Pair", systemImage: "star.fill") {
                                                store.setAsDefault(item)
                                            }
                                        }
                                    }
                                }
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.04), value: appeared)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 48)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Collection")
            .navigationDestination(for: FootwearItem.self) { item in
                FootwearDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddFootwearView()
            }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }

    private var editorialHeader: some View {
        let activeCount = store.activeFootwear.count
        let nearRetirement = store.pairsNearingRetirement().count

        return VStack(alignment: .leading, spacing: 14) {
            Text("TOTAL WEAR")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(totalKm >= 1000
                     ? (totalKm / 1000).formatted(.number.precision(.fractionLength(1)))
                     : totalKm.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 56, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(totalKm >= 1000 ? "thousand km" : "km")
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                HeaderStat(label: "Active", value: "\(activeCount)")

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 18)

                HeaderStat(label: "Sessions", value: "\(store.sessions.filter { $0.isAssigned }.count)")

                if nearRetirement > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1, height: 18)

                    HeaderStat(label: "Retiring", value: "\(nearRetirement)", accent: .orange)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterChip(title: "Active", isSelected: selectedFilter == .active) {
                selectedFilter = .active
            }
            FilterChip(title: "Retired", isSelected: selectedFilter == .retired) {
                selectedFilter = .retired
            }
            FilterChip(title: "All", isSelected: selectedFilter == nil) {
                selectedFilter = nil
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 108, height: 108)
                Image(systemName: "shoe.2")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Nothing here yet")
                    .font(.title2.weight(.semibold))
                Text(selectedFilter == .active
                     ? "Add your first pair to start tracking real-world wear and lifecycle."
                     : "No footwear matches this filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if selectedFilter == .active || selectedFilter == nil {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Footwear", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.primary)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .padding(.horizontal, 40)
    }
}

struct HeaderStat: View {
    let label: String
    let value: String
    var accent: Color = .primary

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent)
            Text(label.lowercased())
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(Color.primary)
                    } else {
                        Capsule().fill(Color(.secondarySystemGroupedBackground))
                    }
                }
                .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
