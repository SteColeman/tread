import SwiftUI
import PhotosUI

struct PhotoPickerTile: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var image: UIImage?
    var aspectRatio: CGFloat = 4.0 / 3.0

    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let current = image {
                    Color(.tertiarySystemFill)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .overlay {
                            Image(uiImage: current)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                image = nil
                                selection = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .padding(8)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(.secondary)
                                VStack(spacing: 2) {
                                    Text(title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                                .foregroundStyle(Color.primary.opacity(0.12))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run { self.image = ui }
                }
            }
        }
    }
}
