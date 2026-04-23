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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if !store.footwear.isEmpty {
                        summaryHeader
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    filterBar
                        .padding(.horizontal)
                        .padding(.bottom, 12)

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
                                .offset(y: appeared ? 0 : 16)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.04), value: appeared)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Collection")
            .navigationDestination(for: FootwearItem.self) { item in
                FootwearDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Footwear", systemImage: "plus") {
                        showAddSheet = true
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddFootwearView()
            }
            .onAppear {
                withAnimation {
                    appeared = true
                }
            }
        }
    }

    private var summaryHeader: some View {
        let totalKm = store.activeFootwear.reduce(0.0) { $0 + store.totalDistance(for: $1.id) }
        let activeCount = store.activeFootwear.count
        let nearRetirement = store.pairsNearingRetirement().count

        return HStack(spacing: 0) {
            SummaryPill(value: "\(activeCount)", label: "Active", icon: "shoe.2.fill")
            
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1, height: 32)

            SummaryPill(
                value: totalKm >= 1000 ? "\(Int(totalKm / 1000))k" : "\(Int(totalKm))",
                label: "km total",
                icon: "point.bottomleft.forward.to.arrow.triangle.uturn.scurvepath.fill"
            )

            if nearRetirement > 0 {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1, height: 32)

                SummaryPill(value: "\(nearRetirement)", label: "Retiring", icon: "exclamationmark.triangle.fill", accent: .orange)
            }
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterChip(title: "Active", isSelected: selectedFilter == .active) {
                selectedFilter = selectedFilter == .active ? nil : .active
            }
            FilterChip(title: "Retired", isSelected: selectedFilter == .retired) {
                selectedFilter = selectedFilter == .retired ? nil : .retired
            }
            FilterChip(title: "All", isSelected: selectedFilter == nil) {
                selectedFilter = nil
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 100, height: 100)
                Image(systemName: "shoe.2")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("No Footwear")
                    .font(.title3.bold())
                Text(selectedFilter == .active
                     ? "Add your first pair to start tracking wear and lifecycle."
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
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }
}

struct SummaryPill: View {
    let value: String
    let label: String
    let icon: String
    var accent: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(accent == .primary ? .secondary : accent)
                Text(value)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(accent == .primary ? .primary : accent)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
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
                .background(isSelected ? Color.primary.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .clipShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
