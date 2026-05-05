import SwiftUI
import PhotosUI
import UIKit

struct WearScanFlow: View {
    let footwear: FootwearItem
    var isBaseline: Bool = false

    @Environment(FootwearStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .intro
    @State private var capturedShots: [ScanShot: UIImage] = [:]
    @State private var currentShot: ScanShot = .heel
    @State private var pickerSelection: PhotosPickerItem?
    @State private var processingError: String?
    @State private var resultScan: WearScan?
    @State private var showSourcePicker: Bool = false
    @State private var showCamera: Bool = false

    enum Stage: Equatable {
        case intro
        case capture
        case processing
        case result
    }

    private let shotOrder: [ScanShot] = [.heel, .midfoot, .forefoot]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .intro:
            ScanIntroView(footwear: footwear, isBaseline: isBaseline) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    stage = .capture
                }
            }
        case .capture:
            captureView
        case .processing:
            ProcessingView(image: capturedShots[shotOrder.last!] ?? capturedShots[currentShot])
        case .result:
            if let scan = resultScan {
                ScanResultView(scan: scan, footwear: footwear) {
                    dismiss()
                }
            }
        }
    }

    private var captureView: some View {
        CaptureGuideView(
            shot: currentShot,
            shotIndex: shotOrder.firstIndex(of: currentShot) ?? 0,
            totalShots: shotOrder.count,
            captured: capturedShots[currentShot],
            onPick: { showSourcePicker = true },
            onRetake: { capturedShots[currentShot] = nil },
            onNext: advanceShot
        )
        .confirmationDialog("Add photo", isPresented: $showSourcePicker, titleVisibility: .hidden) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose From Library") {
                Task { @MainActor in
                    pickerSelection = nil
                    showLibraryPicker = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $pickerSelection, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerSelection) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        capturedShots[currentShot] = img
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image { capturedShots[currentShot] = image }
            }
            .ignoresSafeArea()
        }
        .alert("Scan failed", isPresented: errorBinding) {
            Button("OK") { processingError = nil }
        } message: {
            Text(processingError ?? "")
        }
    }

    @State private var showLibraryPicker: Bool = false

    private var errorBinding: Binding<Bool> {
        Binding(get: { processingError != nil }, set: { if !$0 { processingError = nil } })
    }

    private func advanceShot() {
        guard let idx = shotOrder.firstIndex(of: currentShot) else { return }
        if idx + 1 < shotOrder.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentShot = shotOrder[idx + 1]
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            beginProcessing()
        }
    }

    private func beginProcessing() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            stage = .processing
        }

        let kmUsed = store.totalDistance(for: footwear.id)
        let priorScore = store.latestScan(for: footwear.id)?.score
        let shotsToSend: [(ScanShot, UIImage)] = shotOrder.compactMap { s in
            if let img = capturedShots[s] { return (s, img) }
            return nil
        }

        Task { @MainActor in
            do {
                let result = try await WearScanService.shared.analyze(
                    WearScanInput(
                        footwearName: footwear.name,
                        footwearBrand: footwear.brand,
                        kmUsed: kmUsed,
                        kmGoal: footwear.expectedLifespanKm,
                        priorScore: priorScore,
                        shots: shotsToSend
                    )
                )

                var savedShots: [ScanShotData] = []
                for entry in shotsToSend {
                    if let filename = PhotoStorageService.shared.save(entry.1, maxDimension: 1400) {
                        let heatmap = result.heatmapsByShot[entry.0] ?? HeatmapGrid.empty
                        savedShots.append(ScanShotData(shot: entry.0, photoFilename: filename, heatmap: heatmap))
                    }
                }

                let scan = WearScan(
                    footwearId: footwear.id,
                    date: Date(),
                    kmAtScan: kmUsed,
                    stepsAtScan: store.totalSteps(for: footwear.id),
                    score: result.score,
                    verdict: result.verdict,
                    estimatedKmRemaining: result.estimatedKmRemaining,
                    estimatedKmTotalLife: result.estimatedKmTotalLife,
                    strikePattern: result.strikePattern,
                    pronation: result.pronation,
                    dominantZones: result.dominantZones,
                    injuryNotes: result.injuryNotes,
                    shots: savedShots,
                    isBaseline: isBaseline
                )
                store.addWearScan(scan)
                resultScan = scan
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    stage = .result
                }
            } catch {
                processingError = error.localizedDescription
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    stage = .capture
                }
            }
        }
    }
}

// MARK: - Intro

private struct ScanIntroView: View {
    let footwear: FootwearItem
    let isBaseline: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.55), Color.red.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)

                Image(systemName: "shoeprint.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(180))
                    .shadow(color: .orange.opacity(0.6), radius: 20)
            }

            VStack(spacing: 10) {
                Text(isBaseline ? "Capture your baseline" : "Scan the wear")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(.white)
                Text(isBaseline
                     ? "Three quick photos of the outsole now will make every future scan more accurate."
                     : "We'll take three quick photos of the outsole and analyse the wear pattern.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(spacing: 14) {
                IntroStep(number: 1, title: "Heel", subtitle: "Frame the back block")
                IntroStep(number: 2, title: "Midfoot", subtitle: "Center the arch")
                IntroStep(number: 3, title: "Forefoot", subtitle: "Toe area, including big toe")
            }
            .padding(.horizontal, 36)

            Label("Use bright, even light. Wipe off dirt for best results.", systemImage: "lightbulb.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.yellow.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.yellow.opacity(0.1), in: Capsule())

            Spacer(minLength: 0)

            Button(action: onContinue) {
                HStack {
                    Text(isBaseline ? "Capture baseline" : "Start scan")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(.white, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .padding(.top, 40)
    }
}

private struct IntroStep: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().stroke(.white.opacity(0.25), lineWidth: 1.2))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Capture

private struct CaptureGuideView: View {
    let shot: ScanShot
    let shotIndex: Int
    let totalShots: Int
    let captured: UIImage?
    let onPick: () -> Void
    let onRetake: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalShots, id: \.self) { i in
                    Capsule()
                        .fill(i == shotIndex ? Color.white : Color.white.opacity(0.25))
                        .frame(width: i == shotIndex ? 28 : 8, height: 4)
                        .animation(.spring(response: 0.4), value: shotIndex)
                }
            }
            .padding(.top, 8)

            // Title
            VStack(spacing: 4) {
                Text("Shot \(shotIndex + 1) of \(totalShots)")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                Text(shot.title)
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(.white)
                Text(shot.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 30)

            // Frame guide / preview
            ZStack {
                Color.white.opacity(0.04)

                if let img = captured {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    OutsoleGuideShape(shot: shot)
                        .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        .padding(40)

                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Tap below to capture")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipShape(.rect(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)

            Spacer(minLength: 0)

            // Action area
            HStack(spacing: 16) {
                if captured != nil {
                    Button(action: onRetake) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retake")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.1), in: Capsule())
                    }

                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text(shotIndex == totalShots - 1 ? "Analyse" : "Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                    }
                } else {
                    Button(action: onPick) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 2)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
            .padding(.top, 14)
        }
    }
}

private struct OutsoleGuideShape: Shape {
    let shot: ScanShot

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        switch shot {
        case .heel:
            // Heel oval — wider than tall, top portion only
            path.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.20, width: w * 0.64, height: h * 0.45))
        case .midfoot:
            // Tall arched rectangle
            path.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.12, width: w * 0.56, height: h * 0.76), cornerSize: CGSize(width: 30, height: 30))
        case .forefoot:
            // Wider rounded rectangle for toe area
            path.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.15, width: w * 0.76, height: h * 0.7), cornerSize: CGSize(width: 60, height: 60))
        }
        return path
    }
}

// MARK: - Camera (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            picker.dismiss(animated: true) { [parent] in
                parent.onPicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { [parent] in
                parent.onPicked(nil)
            }
        }
    }
}

// MARK: - Processing

private struct ProcessingView: View {
    let image: UIImage?
    @State private var sweep: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 260, height: 260)
                        .clipShape(.rect(cornerRadius: 28))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        }
                        .overlay {
                            // Sweeping scan line
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [.clear, .orange.opacity(0.8), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 60)
                                .blur(radius: 10)
                                .offset(y: sweep * (geo.size.height - 60))
                            }
                            .clipShape(.rect(cornerRadius: 28))
                        }
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 260, height: 260)
                }

                Circle()
                    .stroke(.orange.opacity(0.4), lineWidth: 2)
                    .frame(width: pulse ? 320 : 260, height: pulse ? 320 : 260)
                    .opacity(pulse ? 0 : 0.7)
            }

            VStack(spacing: 8) {
                Text("Analysing wear pattern…")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Reading rubber depth, stride asymmetry, and pressure zones.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: true)) {
                sweep = 1
            }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
