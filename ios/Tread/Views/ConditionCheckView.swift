import SwiftUI

struct ConditionCheckView: View {
    let footwearId: UUID
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 3
    @State private var notes = ""
    @State private var selectedAreas: Set<WearArea> = []

    private var footwearName: String {
        store.footwear.first(where: { $0.id == footwearId })?.name ?? "Footwear"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 20) {
                        Text("How does this pair feel?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        rating = i
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(i <= rating ? ratingColor(for: rating) : Color.primary.opacity(0.06))
                                                .frame(width: 40, height: 40)

                                            if i <= rating {
                                                Image(systemName: ratingIcon(for: i, maxRating: rating))
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }

                                        if i == rating {
                                            Text(ratingLabel)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .transition(.opacity)
                                        }
                                    }
                                }
                                .sensoryFeedback(.selection, trigger: rating)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                }

                Section("Wear Areas") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(WearArea.allCases, id: \.self) { area in
                            let isSelected = selectedAreas.contains(area)
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    if isSelected {
                                        selectedAreas.remove(area)
                                    } else {
                                        selectedAreas.insert(area)
                                    }
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: area.icon)
                                        .font(.system(size: 16))
                                    Text(area.rawValue)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.03))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(isSelected ? Color.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                                )
                            }
                            .sensoryFeedback(.selection, trigger: isSelected)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Notes") {
                    TextField("Any observations? (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Condition Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let log = ConditionLog(
                            footwearId: footwearId,
                            rating: rating,
                            notes: notes.trimmingCharacters(in: .whitespaces),
                            affectedAreas: Array(selectedAreas)
                        )
                        store.addConditionLog(log)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
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

    private func ratingColor(for value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        default: return .gray
        }
    }

    private func ratingIcon(for index: Int, maxRating: Int) -> String {
        if index == maxRating {
            switch maxRating {
            case 1: return "xmark"
            case 2: return "minus"
            case 3: return "checkmark"
            case 4: return "hand.thumbsup.fill"
            case 5: return "star.fill"
            default: return "checkmark"
            }
        }
        return "circle.fill"
    }
}
