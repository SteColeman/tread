import SwiftUI

struct ActivityView: View {
    @Environment(FootwearStore.self) private var store
    @Environment(HealthKitService.self) private var healthKit
    @State private var isLoading = false
    @State private var selectedSession: WearSession?
    @State private var showActivePicker = false

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
            formatter.dateFormat = "EEEEE"
            return (formatter.string(from: date), dist, date)
        }
    }

    private var maxWeeklyDistance: Double {
        max(weeklyData.map(\.distance).max() ?? 1, 0.1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    activePairPill
                        .padding(.horizontal, 20)

                    todayHero
                        .padding(.horizontal, 20)

                    weeklyChart
                        .padding(.horizontal, 20)

                    unassignedSection
                        .padding(.horizontal, 16)

                    recentActivitySection
                        .padding(.horizontal, 16)
                }
                .padding(.top, 4)
                .padding(.bottom, 48)
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
            .sheet(isPresented: $showActivePicker) {
                ActivePairPickerView()
            }
            .task {
                await syncHealthKit()
            }
            .onChange(of: store.defaultPair?.id) { _, _ in
                Task { await syncHealthKit() }
            }
        }
    }

    private var activePairPill: some View {
        Button {
            showActivePicker = true
        } label: {
            HStack(spacing: 12) {
                if let pair = store.defaultPair {
                    let colorTag = ColorTag(rawValue: pair.colorTag) ?? .slate
                    Circle()
                        .fill(colorTag.color.gradient)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: pair.type.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("WEARING NOW")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                        Text(pair.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "shoe.2")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.06)))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("NO ACTIVE PAIR")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                        Text("Tap to select")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule().fill(Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showActivePicker)
    }

    private var todayHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(todayDistance.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 64, weight: .bold))
                    .monospacedDigit()

                Text("km")
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(todaySteps.formatted()) steps")
                        .font(.system(.subheadline, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)

                if let todayPair = todaySessions.first(where: { $0.footwearId != nil }),
                   let name = store.footwear.first(where: { $0.id == todayPair.footwearId })?.name {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(.system(size: 10))
                        Text(name)
                            .font(.system(.subheadline, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                Spacer()
                let weekTotal = weeklyData.reduce(0.0) { $0 + $1.distance }
                Text("\(weekTotal.formatted(.number.precision(.fractionLength(1)))) km")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyData, id: \.day) { entry in
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 110)
                            Capsule()
                                .fill(isToday ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.primary.opacity(0.35)))
                                .frame(height: max(4, 110 * (entry.distance / maxWeeklyDistance)))
                        }
                        .frame(maxWidth: .infinity)

                        Text(entry.day)
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? .primary : .tertiary)
                    }
                }
            }
        }
    }

    private var unassignedSection: some View {
        Group {
            let unassigned = store.unassignedSessions.sorted(by: { $0.date > $1.date })

            if !unassigned.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                            Text("UNASSIGNED")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let defaultPair = store.defaultPair {
                            Button {
                                withAnimation(.snappy) {
                                    store.assignAllUnassigned(to: defaultPair.id)
                                }
                            } label: {
                                Text("Assign all")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: store.unassignedSessions.count)
                        }
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(unassigned.prefix(8)) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.date, style: .date)
                                            .font(.system(.subheadline, weight: .medium))
                                        Text("\(session.steps.formatted()) steps · \(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.quaternary)
                                }
                                .padding(.vertical, 12)
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
                    .clipShape(.rect(cornerRadius: 18))
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

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
                .clipShape(.rect(cornerRadius: 18))
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
                                    .font(.system(.subheadline, weight: .medium))
                                Text(footwear?.name ?? "Unknown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if session.id != recent.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 18))
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

struct ActivePairPickerView: View {
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your active pair is used as the default fallback for new walking activity from Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section("Choose Active Pair") {
                    ForEach(store.activeFootwear) { item in
                        Button {
                            store.setAsDefault(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                let colorTag = ColorTag(rawValue: item.colorTag) ?? .slate
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorTag.color.gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: item.type.icon)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !item.brand.isEmpty {
                                        Text(item.brand)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if item.isDefault {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if store.activeFootwear.isEmpty {
                        Text("Add an active pair from Collection first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.defaultPair != nil {
                    Section {
                        Button(role: .destructive) {
                            store.clearDefault()
                            dismiss()
                        } label: {
                            Text("Clear Active Pair")
                        }
                    }
                }
            }
            .navigationTitle("Active Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
