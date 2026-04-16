import SwiftUI

struct AddFootwearView: View {
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var type: FootwearType = .casual
    @State private var isDefault = false
    @State private var expectedLifespan: Double = 800
    @State private var datePurchased: Date = Date()
    @State private var hasPurchaseDate = false
    @State private var notes = ""
    @State private var selectedColor: ColorTag = .slate

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Brand (optional)", text: $brand)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(FootwearType.allCases) { footwearType in
                            Label(footwearType.rawValue, systemImage: footwearType.icon)
                                .tag(footwearType)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Color") {
                    colorPicker
                }

                Section("Expected Lifespan") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(expectedLifespan)) km")
                                .font(.headline)
                                .monospacedDigit()
                            Spacer()
                            Text(lifespanHint)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Slider(value: $expectedLifespan, in: 200...2000, step: 50)
                    }
                }

                Section {
                    Toggle("Set as Default Pair", isOn: $isDefault)
                    Toggle("Purchase Date", isOn: $hasPurchaseDate.animation(.snappy))
                    if hasPurchaseDate {
                        DatePicker("Purchased", selection: $datePurchased, in: ...Date(), displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Footwear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = FootwearItem(
                            name: name.trimmingCharacters(in: .whitespaces),
                            brand: brand.trimmingCharacters(in: .whitespaces),
                            type: type,
                            datePurchased: hasPurchaseDate ? datePurchased : nil,
                            isDefault: isDefault,
                            expectedLifespanKm: expectedLifespan,
                            notes: notes.trimmingCharacters(in: .whitespaces),
                            colorTag: selectedColor.rawValue
                        )
                        store.addFootwear(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var lifespanHint: String {
        switch expectedLifespan {
        case 200..<400: return "Light use"
        case 400..<700: return "Moderate use"
        case 700..<1200: return "Standard"
        case 1200...: return "Heavy duty"
        default: return ""
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(ColorTag.allCases) { tag in
                    Button {
                        withAnimation(.snappy) {
                            selectedColor = tag
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(tag.color.gradient)
                                    .frame(width: 38, height: 38)

                                if selectedColor == tag {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(tag.label)
                                .font(.caption2)
                                .foregroundStyle(selectedColor == tag ? .primary : .tertiary)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedColor)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}
