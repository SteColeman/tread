import SwiftUI
import UIKit

struct ScanResultView: View {
    let scan: WearScan
    let footwear: FootwearItem
    let onDone: () -> Void

    @State private var selectedShotIndex: Int = 0
    @State private var showShare: Bool = false
    @State private var shareImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                heatmapViewer
                gaitCard
                if !scan.injuryNotes.isEmpty {
                    injuryCard
                }
                lifeRemainingCard

                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
            .padding(.top, 18)
        }
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await prepareShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareSheet(items: [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Hero score card

    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(scan.score) / 100.0)
                    .stroke(scoreGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: scan.score)
                VStack(spacing: 0) {
                    Text("\(scan.score)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(scan.scoreBand.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(scoreColor)
                }
            }
            .frame(width: 150, height: 150)

            Text(scan.verdict)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var scoreColor: Color {
        switch scan.scoreBand {
        case .fresh: return .green
        case .moderate: return .orange
        case .worn: return .red
        }
    }

    private var scoreGradient: LinearGradient {
        switch scan.scoreBand {
        case .fresh:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .moderate:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .worn:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - Heatmap viewer

    private var heatmapViewer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Wear Heatmap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if scan.shots.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<scan.shots.count, id: \.self) { i in
                            Circle()
                                .fill(i == selectedShotIndex ? Color.white : Color.white.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            TabView(selection: $selectedShotIndex) {
                ForEach(Array(scan.shots.enumerated()), id: \.offset) { idx, shot in
                    HeatmapPhotoView(shot: shot)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 360)
            .clipShape(.rect(cornerRadius: 22))

            if !scan.shots.isEmpty {
                Text(scan.shots[min(selectedShotIndex, scan.shots.count - 1)].shot.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 8) {
                LinearGradient(
                    colors: [.blue.opacity(0.0), .yellow.opacity(0.85), .red],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 4)
                .clipShape(Capsule())
                Text("Worn")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .overlay(alignment: .leading) {
                Text("Fresh")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: 14)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Gait card

    private var gaitCard: some View {
        HStack(spacing: 14) {
            InfoTile(
                icon: scan.strikePattern.icon,
                label: "Strike",
                value: scan.strikePattern.rawValue,
                tint: .blue
            )
            InfoTile(
                icon: "figure.run",
                label: "Pronation",
                value: scan.pronation.rawValue,
                subtitle: scan.pronation.subtitle,
                tint: .purple
            )
        }
    }

    // MARK: - Injury notes

    private var injuryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch‑outs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(scan.injuryNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: severityIcon(note.severity))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(severityColor(note.severity))
                            .frame(width: 28, height: 28)
                            .background(severityColor(note.severity).opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(note.body)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }

    private func severityIcon(_ s: Int) -> String {
        switch s {
        case 1: return "info"
        case 2: return "exclamationmark"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func severityColor(_ s: Int) -> Color {
        switch s {
        case 1: return .blue
        case 2: return .orange
        default: return .red
        }
    }

    // MARK: - Life remaining

    private var lifeRemainingCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated life left")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(scan.estimatedKmRemaining))")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("km")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("Total life: ~\(Int(scan.estimatedKmTotalLife)) km")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "road.lanes")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Share

    @MainActor
    private func prepareShare() async {
        let renderer = ImageRenderer(content:
            ShareCard(scan: scan, footwear: footwear)
                .frame(width: 380, height: 560)
        )
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage {
            shareImage = img
            showShare = true
        }
    }
}

// MARK: - Heatmap photo

struct HeatmapPhotoView: View {
    let shot: ScanShotData

    var body: some View {
        ZStack {
            Color.black
            if let img = PhotoStorageService.shared.load(shot.photoFilename) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        HeatmapOverlay(grid: shot.heatmap)
                            .blendMode(.screen)
                    }
            }
        }
    }
}

struct HeatmapOverlay: View {
    let grid: HeatmapGrid

    var body: some View {
        Canvas { ctx, size in
            let cellW = size.width / CGFloat(grid.cols)
            let cellH = size.height / CGFloat(grid.rows)
            for r in 0..<grid.rows {
                for c in 0..<grid.cols {
                    let idx = r * grid.cols + c
                    guard idx < grid.values.count else { continue }
                    let v = grid.values[idx]
                    if v < 0.05 { continue }
                    let color = heatColor(for: v)
                    let rect = CGRect(
                        x: CGFloat(c) * cellW,
                        y: CGFloat(r) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: -cellW * 0.4, dy: -cellH * 0.4)), with: .color(color))
                }
            }
        }
        .blur(radius: 14)
        .opacity(0.85)
    }

    private func heatColor(for value: Double) -> Color {
        // 0 -> transparent, 0.5 -> amber, 1 -> red
        let v = max(0, min(1, value))
        if v < 0.4 {
            return Color.yellow.opacity(v * 1.2)
        } else if v < 0.75 {
            let t = (v - 0.4) / 0.35
            return Color(
                red: 1.0,
                green: 0.7 - 0.5 * t,
                blue: 0.0,
                opacity: 0.6 + 0.25 * t
            )
        } else {
            let t = (v - 0.75) / 0.25
            return Color(
                red: 1.0,
                green: 0.2 * (1 - t),
                blue: 0.0,
                opacity: 0.85 + 0.15 * t
            )
        }
    }
}

// MARK: - Info tile

private struct InfoTile: View {
    let icon: String
    let label: String
    let value: String
    var subtitle: String? = nil
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.45))
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Share card

private struct ShareCard: View {
    let scan: WearScan
    let footwear: FootwearItem

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TREAD WEAR SCAN")
                        .font(.caption2.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(footwear.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "shoeprint.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(scan.score) / 100.0)
                    .stroke(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(scan.score)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 180, height: 180)

            Text(scan.verdict)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                ShareStat(label: "Strike", value: scan.strikePattern.rawValue)
                ShareStat(label: "Pronation", value: scan.pronation.rawValue)
                ShareStat(label: "Life Left", value: "\(Int(scan.estimatedKmRemaining))km")
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 380, height: 560)
        .background(
            LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.10), Color.black],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

private struct ShareStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.caption2)
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
