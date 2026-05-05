import SwiftUI

struct GoalPresetPicker: View {
    @Binding var selected: ReplacementGoalPreset
    @Binding var expectedLifespan: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ReplacementGoalPreset.allCases) { preset in
                        chip(for: preset)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(expectedLifespan))")
                        .font(.system(size: 32, weight: .bold))
                        .monospacedDigit()
                    Text("km")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(selected.subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if selected == .custom {
                    Slider(value: $expectedLifespan, in: 200...4000, step: 50)
                        .tint(.primary)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .onChange(of: selected) { _, newValue in
            if newValue != .custom {
                withAnimation(.snappy) {
                    expectedLifespan = newValue.distanceKm
                }
            }
        }
    }

    private func chip(for preset: ReplacementGoalPreset) -> some View {
        let isSelected = selected == preset
        return Button {
            withAnimation(.snappy) { selected = preset }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(preset.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(Color.primary)
                } else {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
            }
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
