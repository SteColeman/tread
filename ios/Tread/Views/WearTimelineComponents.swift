import SwiftUI

struct WearSparkline: View {
    let scans: [WearScan]  // ascending by date

    var body: some View {
        GeometryReader { geo in
            let points = pointsIn(rect: geo.frame(in: .local))
            ZStack {
                if points.count >= 2 {
                    // Filled gradient under line
                    Path { path in
                        path.move(to: CGPoint(x: points.first!.x, y: geo.size.height))
                        for p in points { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    // Line
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .leading, endPoint: .trailing
                    ), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Dots
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 5, height: 5)
                            .position(p)
                    }
                }
            }
        }
    }

    private func pointsIn(rect: CGRect) -> [CGPoint] {
        guard scans.count > 1 else { return [] }
        let w = rect.width
        let h = rect.height
        let count = scans.count
        return scans.enumerated().map { idx, s in
            let x = CGFloat(idx) / CGFloat(max(1, count - 1)) * w
            let y = h - (CGFloat(s.score) / 100.0) * h
            return CGPoint(x: x, y: max(2, min(h - 2, y)))
        }
    }
}

struct WearScanRowView: View {
    let scan: WearScan

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color(.tertiarySystemFill)
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 10))
                if let firstShot = scan.shots.first,
                   let img = PhotoStorageService.shared.load(firstShot.photoFilename) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 10))
                        .saturation(0.4)
                        .overlay {
                            HeatmapOverlay(grid: firstShot.heatmap)
                                .frame(width: 44, height: 44)
                                .blendMode(.screen)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                } else {
                    Image(systemName: "shoeprint.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(scan.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.semibold))
                    if scan.isBaseline {
                        Text("BASELINE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                Text("\(Int(scan.kmAtScan)) km · \(scan.strikePattern.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scan.score)")
                    .font(.system(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(scoreColor(scan.score))
                Text(scan.scoreBand.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }

    private func scoreColor(_ s: Int) -> Color {
        switch s {
        case ..<40: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}
