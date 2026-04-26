import SwiftUI

struct EditFootwearView: View {
    let item: FootwearItem
    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var brand: String
    @State private var colorway: String
    @State private var type: FootwearType
    @State private var isDefault: Bool
    @State private var expectedLifespan: Double
    @State private var datePurchased: Date
    @State private var hasPurchaseDate: Bool
    @State private var notes: String
    @State private var selectedColor: ColorTag
    @State private var photo: UIImage?
    @State private var receiptPhoto: UIImage?
    @State private var photoChanged = false
    @State private var receiptChanged = false

    init(item: FootwearItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _brand = State(initialValue: item.brand)
        _colorway = State(initialValue: item.colorway)
        _type = State(initialValue: item.type)
        _isDefault = State(initialValue: item.isDefault)
        _expectedLifespan = State(initialValue: item.expectedLifespanKm)
        _datePurchased = State(initialValue: item.datePurchased ?? Date())
        _hasPurchaseDate = State(initialValue: item.datePurchased != nil)
        _notes = State(initialValue: item.notes)
        _selectedColor = State(initialValue: ColorTag(rawValue: item.colorTag) ?? .slate)
        _photo = State(initialValue: PhotoStorageService.shared.load(item.photoFilename))
        _receiptPhoto = State(initialValue: PhotoStorageService.shared.load(item.receiptPhotoFilename))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotoPickerTile(
                        title: "Add Photo",
                        subtitle: "Choose from library",
                        icon: "shoe.2",
                        image: Binding(
                            get: { photo },
                            set: { photo = $0; photoChanged = true }
                        )
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Colorway, e.g. Triple Black", text: $colorway)
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

                Section("Color Tag") {
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
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Expected Lifespan") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(expectedLifespan)) km")
                                .font(.headline)
                                .monospacedDigit()
                            Spacer()
                        }
                        Slider(value: $expectedLifespan, in: 200...2000, step: 50)
                    }
                }

                Section("Purchase") {
                    Toggle("Purchase Date", isOn: $hasPurchaseDate.animation(.snappy))
                    if hasPurchaseDate {
                        DatePicker("Purchased", selection: $datePurchased, in: ...Date(), displayedComponents: .date)
                    }
                    PhotoPickerTile(
                        title: "Add Receipt",
                        subtitle: "Keep for warranty claims",
                        icon: "doc.text.viewfinder",
                        image: Binding(
                            get: { receiptPhoto },
                            set: { receiptPhoto = $0; receiptChanged = true }
                        ),
                        aspectRatio: 3.0 / 4.0
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    Toggle("Set as Active Pair", isOn: $isDefault)
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Footwear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        var updated = item
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.brand = brand.trimmingCharacters(in: .whitespaces)
        updated.colorway = colorway.trimmingCharacters(in: .whitespaces)
        updated.type = type
        updated.isDefault = isDefault
        updated.expectedLifespanKm = expectedLifespan
        updated.datePurchased = hasPurchaseDate ? datePurchased : nil
        updated.notes = notes.trimmingCharacters(in: .whitespaces)
        updated.colorTag = selectedColor.rawValue

        if photoChanged {
            PhotoStorageService.shared.delete(item.photoFilename)
            updated.photoFilename = photo.flatMap { PhotoStorageService.shared.save($0) }
        }
        if receiptChanged {
            PhotoStorageService.shared.delete(item.receiptPhotoFilename)
            updated.receiptPhotoFilename = receiptPhoto.flatMap { PhotoStorageService.shared.save($0, maxDimension: 2200) }
        }

        store.updateFootwear(updated)
        dismiss()
    }
}
