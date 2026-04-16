import SwiftUI

struct ActivityView: View {
    @Environment(FootwearStore.self) private var store
    @Environment(HealthKitService.self) private var healthKit
    @State private var isLoading = false
    @State private var showAssignSheet = false
    @State private var selectedSession: WearSession?

    private var todaySessions: [WearSession] {
        store.sessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todaySteps: Int {
        todaySessions.reduce(0) { $0 + $1.steps }
    }

    private var todayDistance: Double {
        todaySessions.reduce(0) { $0 + $1.distanceKm }
    }

    private var weeklyData: [(day: String, distance: Double, date: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> (String, Double, Date)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let daySessions = store.sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let dist = daySessions.reduce(0.0) { $0 + $1.distanceKm }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return (formatter.string(from: date), dist, date)
        }
    }

    private var maxWeeklyDistance: Double {
        max(weeklyData.map(\.distance).max() ?? 1, 0.1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayCard
                    weeklyChart
                    unassignedSection
                    recentActivitySection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await syncHealthKit() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, isActive: isLoading)
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(item: $selectedSession) { session in
                AssignSessionView(session: session)
            }
            .task {
                if store.sessions.isEmpty {
                    await syncHealthKit()
                }
            }
        }
    }

    private var todayCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                if let todayPair = todaySessions.first(where: { $0.footwearId != nil }),
                   let name = store.footwear.first(where: { $0.id == todayPair.footwearId })?.name {
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(.caption2)
                        Text(name)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todaySteps.formatted())
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .monospacedDigit()
                    Text("steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(todayDistance.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .monospacedDigit()
                    Text("km walked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
                let weekTotal = weeklyData.reduce(0.0) { $0 + $1.distance }
                Text("\(weekTotal.formatted(.number.precision(.fractionLength(1)))) km")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weeklyData, id: \.day) { entry in
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isToday ? Color.primary : Color.primary.opacity(0.15))
                            .frame(height: max(4, 80 * (entry.distance / maxWeeklyDistance)))
                            .frame(maxWidth: .infinity)

                        Text(entry.day)
                            .font(.system(size: 10, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .primary : .tertiary)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var unassignedSection: some View {
        Group {
            let unassigned = store.unassignedSessions.sorted(by: { $0.date > $1.date })

            if !unassigned.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                            Text("Unassigned")
                                .font(.headline)
                        }
                        Spacer()
                        if let defaultPair = store.defaultPair {
                            Button {
                                withAnimation(.snappy) {
                                    store.assignAllUnassigned(to: defaultPair.id)
                                }
                            } label: {
                                Text("Assign All")
                                    .font(.caption.weight(.medium))
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: store.unassignedSessions.count)
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(unassigned.prefix(8)) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.date, style: .date)
                                            .font(.subheadline)
                                        Text("\(session.steps.formatted()) steps · \(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.quaternary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if session.id != unassigned.prefix(8).last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)

            let recent = store.sessions
                .filter { $0.isAssigned }
                .sorted(by: { $0.date > $1.date })
                .prefix(12)

            if recent.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "shoe.2")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No assigned activity yet. Sync from Health and assign to your footwear.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent)) { session in
                        let footwear = store.footwear.first(where: { $0.id == session.footwearId })
                        let colorTag = ColorTag(rawValue: footwear?.colorTag ?? "slate") ?? .slate

                        HStack(spacing: 12) {
                            Circle()
                                .fill(colorTag.color.gradient)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.date, style: .date)
                                    .font(.subheadline)
                                Text(footwear?.name ?? "Unknown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if session.id != recent.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func syncHealthKit() async {
        guard healthKit.isAvailable else { return }

        isLoading = true
        defer { isLoading = false }

        if !healthKit.isAuthorized {
            await healthKit.requestAuthorization()
        }

        guard healthKit.isAuthorized else { return }

        let weeklyData = await healthKit.fetchWeeklyData()
        store.importHealthKitData(weeklyData)
    }
}

struct AssignSessionView: View {
    let session: WearSession
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(session.date, style: .date)
                        Spacer()
                        Text("\(session.steps.formatted()) steps · \(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Section("Assign to") {
                    ForEach(store.activeFootwear) { item in
                        Button {
                            store.assignSession(session.id, to: item.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                let colorTag = ColorTag(rawValue: item.colorTag) ?? .slate
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorTag.color.gradient)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Image(systemName: item.type.icon)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.body)
                                    if item.isDefault {
                                        Text("Default")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Assign Wear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
