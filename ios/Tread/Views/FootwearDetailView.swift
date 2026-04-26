import SwiftUI

struct FootwearDetailView: View {
    let item: FootwearItem
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showConditionCheck = false
    @State private var showEditSheet = false
    @State private var showRetireAlert = false
    @State private var showDeleteAlert = false
    @State private var showPhotoViewer = false
    @State private var showReceiptViewer = false

    private var colorTag: ColorTag {
        ColorTag(rawValue: currentItem.colorTag) ?? .slate
    }

    private var currentItem: FootwearItem {
        store.footwear.first(where: { $0.id == item.id }) ?? item
    }

    private var distance: Double {
        store.totalDistance(for: item.id)
    }

    private var steps: Int {
        store.totalSteps(for: item.id)
    }

    private var sessionCount: Int {
        store.sessionCount(for: item.id)
    }

    private var lifecyclePercent: Double {
        store.lifecyclePercentage(for: currentItem)
    }

    private var latestCondition: ConditionLog? {
        store.latestCondition(for: item.id)
    }

    private var daysSincePurchase: Int? {
        guard let purchased = currentItem.datePurchased else { return nil }
        return Calendar.current.dateComponents([.day], from: purchased, to: Date()).day
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                quickStats
                lifecycleSection
                conditionSection
                wearHistorySection
                infoSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentItem.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { showEditSheet = true }
                    if currentItem.status == .active {
                        if currentItem.isDefault {
                            Button("Clear Active Pair", systemImage: "star.slash") {
                                store.clearDefault()
                            }
                        } else {
                            Button("Set as Active Pair", systemImage: "star.fill") {
                                store.setAsDefault(currentItem)
                            }
                        }
                        Button("Log Condition", systemImage: "heart.text.clipboard") { showConditionCheck = true }
                        Divider()
                        Button("Retire", systemImage: "archivebox", role: .destructive) { showRetireAlert = true }
                    } else {
                        Button("Reactivate", systemImage: "arrow.uturn.backward") {
                            store.reactivateFootwear(currentItem)
                        }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { showDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showConditionCheck) {
            ConditionCheckView(footwearId: item.id)
        }
        .sheet(isPresented: $showEditSheet) {
            EditFootwearView(item: currentItem)
        }
        .sheet(isPresented: $showPhotoViewer) {
            if let photo {
                PhotoViewer(image: photo, title: currentItem.name)
            }
        }
        .sheet(isPresented: $showReceiptViewer) {
            if let receiptPhoto {
                PhotoViewer(image: receiptPhoto, title: "Receipt")
            }
        }
        .alert("Retire this pair?", isPresented: $showRetireAlert) {
            Button("Retire", role: .destructive) { store.retireFootwear(currentItem) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This marks \(currentItem.name) as retired. You can reactivate it later.")
        }
        .alert("Delete this pair?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                store.deleteFootwear(currentItem)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes \(currentItem.name) and all associated data.")
        }
    }

    private var photo: UIImage? {
        PhotoStorageService.shared.load(currentItem.photoFilename)
    }

    private var receiptPhoto: UIImage? {
        PhotoStorageService.shared.load(currentItem.receiptPhotoFilename)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                if let photo {
                    LinearGradient(
                        colors: [colorTag.color.opacity(0.4), colorTag.color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        colors: [colorTag.color, colorTag.color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: currentItem.type.icon)
                        .font(.system(size: 120, weight: .light))
                        .foregroundStyle(.white.opacity(0.18))
                        .offset(x: 90, y: 30)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        if currentItem.isDefault {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                Text("ACTIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.22))
                            .clipShape(Capsule())
                        }

                        Text(currentItem.status.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentItem.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(currentItem.name)
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        if !currentItem.brand.isEmpty || !currentItem.colorway.isEmpty {
                            HStack(spacing: 6) {
                                if !currentItem.brand.isEmpty {
                                    Text(currentItem.brand)
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                if !currentItem.brand.isEmpty && !currentItem.colorway.isEmpty {
                                    Text("·").foregroundStyle(.white.opacity(0.5))
                                }
                                if !currentItem.colorway.isEmpty {
                                    Text(currentItem.colorway)
                                        .font(.system(.subheadline))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 230)
            .clipShape(.rect(cornerRadius: 24))
            .contentShape(.rect(cornerRadius: 24))
            .onTapGesture {
                if photo != nil { showPhotoViewer = true }
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 0) {
            StatPill(value: distance.formatted(.number.precision(.fractionLength(1))), unit: "km", label: "Distance")
            
            Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1, height: 36)
            
            StatPill(value: formattedSteps, unit: "", label: "Steps")
            
            Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1, height: 36)
            
            StatPill(value: "\(sessionCount)", unit: "days", label: "Worn")
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var formattedSteps: String {
        if steps >= 1000 {
            return (Double(steps) / 1000).formatted(.number.precision(.fractionLength(1))) + "k"
        }
        return "\(steps)"
    }

    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifecycle")
                .font(.headline)

            VStack(spacing: 10) {
                HStack {
                    Text("\(Int(lifecyclePercent * 100))%")
                        .font(.system(.title2, design: .default, weight: .bold))
                        .monospacedDigit()
                    Text("of estimated lifespan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(lifecycleBarColor.gradient)
                            .frame(width: max(6, geo.size.width * lifecyclePercent))
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(distance.formatted(.number.precision(.fractionLength(0)))) km used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentItem.expectedLifespanKm.formatted(.number.precision(.fractionLength(0)))) km expected")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if lifecyclePercent >= 0.8 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("This pair is nearing its estimated retirement point.")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var lifecycleBarColor: Color {
        if lifecyclePercent >= 0.9 { return .red }
        if lifecyclePercent >= 0.7 { return .orange }
        return colorTag.color
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Condition")
                    .font(.headline)
                Spacer()
                if currentItem.status == .active {
                    Button {
                        showConditionCheck = true
                    } label: {
                        Label("Log", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                }
            }

            if let condition = latestCondition {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ConditionRatingView(rating: condition.rating)
                        Spacer()
                        Text(condition.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if !condition.notes.isEmpty {
                        Text(condition.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !condition.affectedAreas.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(condition.affectedAreas, id: \.self) { area in
                                HStack(spacing: 3) {
                                    Image(systemName: area.icon)
                                        .font(.system(size: 9))
                                    Text(area.rawValue)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    let conditionHistory = store.conditionHistory(for: item.id)
                    if conditionHistory.count > 1 {
                        Divider()
                        VStack(spacing: 6) {
                            ForEach(conditionHistory.prefix(4).dropFirst()) { log in
                                HStack {
                                    ConditionRatingView(rating: log.rating)
                                    Spacer()
                                    Text(log.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.quaternary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No condition checks yet. Tap + to log how this pair feels.")
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

    private var wearHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Wear")
                .font(.headline)

            let recentSessions = store.sessionsForFootwear(item.id).prefix(7)

            if recentSessions.isEmpty {
                Text("No wear sessions recorded")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions)) { session in
                        HStack {
                            Text(session.date, style: .date)
                                .font(.subheadline)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("\(session.steps.formatted())")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("\(session.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if session.id != recentSessions.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var infoSection: some View {
        Group {
            let hasNotes = !currentItem.notes.isEmpty
            let hasPurchaseDate = currentItem.datePurchased != nil
            let hasReceipt = receiptPhoto != nil

            if hasNotes || hasPurchaseDate || hasReceipt {
                VStack(spacing: 10) {
                    if hasNotes {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(currentItem.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if hasPurchaseDate, let purchased = currentItem.datePurchased {
                        if hasNotes { Divider() }
                        HStack {
                            Text("Purchased")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(purchased, style: .date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let days = daysSincePurchase {
                                    Text("\(days) days ago")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    if let receipt = receiptPhoto {
                        if hasNotes || hasPurchaseDate { Divider() }
                        Button {
                            showReceiptViewer = true
                        } label: {
                            HStack(spacing: 12) {
                                Color(.tertiarySystemFill)
                                    .frame(width: 38, height: 48)
                                    .overlay {
                                        Image(uiImage: receipt)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .allowsHitTesting(false)
                                    }
                                    .clipShape(.rect(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Receipt")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Tap to view")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }
}

struct StatPill: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .default, weight: .bold))
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConditionRatingView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= rating ? ratingColor : Color.primary.opacity(0.06))
                    .frame(width: 10, height: 10)
            }
            Text(ratingLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    private var ratingColor: Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        default: return .gray
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return ""
        }
    }
}
