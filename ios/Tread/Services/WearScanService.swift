import Foundation
import UIKit

nonisolated enum WearScanError: LocalizedError {
    case noToolkitKey
    case noToolkitURL
    case requestFailed(String)
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noToolkitKey: return "AI service not configured."
        case .noToolkitURL: return "AI service URL missing."
        case .requestFailed(let s): return "Couldn't reach analysis service: \(s)"
        case .invalidResponse: return "Unexpected response from analysis."
        case .decodingFailed(let s): return "Couldn't read result: \(s)"
        }
    }
}

nonisolated struct WearScanInput: Sendable {
    let footwearName: String
    let footwearBrand: String
    let kmUsed: Double
    let kmGoal: Double
    let priorScore: Int?
    let shots: [(shot: ScanShot, image: UIImage)]
}

nonisolated struct WearScanResult: Sendable {
    let score: Int
    let verdict: String
    let estimatedKmRemaining: Double
    let estimatedKmTotalLife: Double
    let strikePattern: StrikePattern
    let pronation: Pronation
    let dominantZones: [WearZone]
    let injuryNotes: [InjuryNote]
    let heatmapsByShot: [ScanShot: HeatmapGrid]
}

nonisolated final class WearScanService: Sendable {
    static let shared = WearScanService()

    private static var toolkitURL: String {
        let info = Bundle.main.infoDictionary?["ToolkitURL"] as? String
        if let info, !info.isEmpty { return info }
        return "https://toolkit.rork.com"
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        return cfg == cfg ? URLSession(configuration: cfg) : URLSession.shared
    }()

    func analyze(_ input: WearScanInput) async throws -> WearScanResult {
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !key.isEmpty else { throw WearScanError.noToolkitKey }
        let base = Self.toolkitURL
        guard let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else {
            throw WearScanError.noToolkitURL
        }

        let userContent = try buildUserContent(input)

        let body: [String: Any] = [
            "model": "google/gemini-2.5-flash",
            "temperature": 0.2,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": Self.systemPrompt
                ],
                [
                    "role": "user",
                    "content": userContent
                ]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw WearScanError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw WearScanError.requestFailed("HTTP \(http.statusCode) \(snippet)")
        }

        return try parseResponse(data: data, input: input)
    }

    // MARK: - Prompt

    private static let systemPrompt: String = """
    You are an expert running-shoe outsole wear analyst.
    The user will send 1-3 photos of the bottom of a single shoe (heel / midfoot / forefoot).
    Analyse the visible rubber wear and return ONLY a strict JSON object with this exact shape:

    {
      "score": int 0..100  // 0 = brand new, 100 = fully worn out
      "verdict": string  // one short sentence, friendly, no quotes inside
      "estimated_km_remaining": number  // realistic estimate of km of useful life left
      "estimated_km_total_life": number  // expected total life in km for this pair
      "strike_pattern": "Heel" | "Midfoot" | "Forefoot" | "Mixed"
      "pronation": "Neutral" | "Overpronation" | "Underpronation" | "Unclear"
      "dominant_zones": array of strings drawn ONLY from
         ["Outer Heel","Inner Heel","Center Heel","Outer Midfoot","Inner Midfoot",
          "Outer Forefoot","Inner Forefoot","Big Toe","Even"]
      "injury_notes": array of up to 3 objects {"title": string, "body": string, "severity": 1|2|3}
      "shots": array of objects, one per provided photo, in the SAME ORDER as user supplied:
        {
          "shot": "heel" | "midfoot" | "forefoot",
          "heatmap": {
            "cols": 12,
            "rows": 20,
            "values": array of 240 numbers in 0..1 representing wear intensity per cell,
                      row-major (top-left to bottom-right), aligned to the photo orientation
          }
        }
    }

    Rules:
    - Output JSON only, no markdown.
    - Heatmap values must be 0..1 (1 = most worn). Be generous with 0 in pristine areas so the overlay reads cleanly.
    - Be honest but kind. If photos are unclear, set pronation = "Unclear" and mention it in verdict.
    - Use the user-provided context (km used, goal) to calibrate estimated_km_remaining.
    """

    private func buildUserContent(_ input: WearScanInput) throws -> [[String: Any]] {
        var parts: [[String: Any]] = []

        let priorLine = input.priorScore.map { "Prior wear score: \($0)/100." } ?? "No prior scan."
        let context = """
        Shoe: \(input.footwearName) \(input.footwearBrand.isEmpty ? "" : "by \(input.footwearBrand)")
        Distance used: \(Int(input.kmUsed)) km of \(Int(input.kmGoal)) km goal.
        \(priorLine)
        Provided shots in order: \(input.shots.map { $0.shot.rawValue }.joined(separator: ", ")).
        Analyse and return the strict JSON described in the system prompt.
        """
        parts.append(["type": "text", "text": context])

        for entry in input.shots {
            guard let data = entry.image.resizedForUpload().jpegData(compressionQuality: 0.7) else {
                continue
            }
            let b64 = data.base64EncodedString()
            parts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
            ])
        }
        return parts
    }

    // MARK: - Parse

    private func parseResponse(data: Data, input: WearScanInput) throws -> WearScanResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw WearScanError.invalidResponse
        }

        let contentString: String
        if let s = message["content"] as? String {
            contentString = s
        } else if let arr = message["content"] as? [[String: Any]],
                  let text = arr.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String {
            contentString = text
        } else {
            throw WearScanError.invalidResponse
        }

        let cleaned = stripCodeFences(contentString)
        guard let payload = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw WearScanError.decodingFailed("not valid JSON")
        }

        let score = (json["score"] as? Int) ?? Int((json["score"] as? Double) ?? 0)
        let verdict = (json["verdict"] as? String) ?? "Scan complete."
        let kmRem = (json["estimated_km_remaining"] as? Double) ?? Double((json["estimated_km_remaining"] as? Int) ?? 0)
        let kmTotal = (json["estimated_km_total_life"] as? Double) ?? Double((json["estimated_km_total_life"] as? Int) ?? Int(input.kmGoal))

        let strike = StrikePattern(rawValue: (json["strike_pattern"] as? String) ?? "") ?? .mixed
        let pronation = Pronation(rawValue: (json["pronation"] as? String) ?? "") ?? .unclear

        let zones: [WearZone] = ((json["dominant_zones"] as? [String]) ?? []).compactMap {
            WearZone(rawValue: $0)
        }

        var notes: [InjuryNote] = []
        if let arr = json["injury_notes"] as? [[String: Any]] {
            for n in arr {
                let title = (n["title"] as? String) ?? ""
                let body = (n["body"] as? String) ?? ""
                let sev = (n["severity"] as? Int) ?? 1
                if !title.isEmpty {
                    notes.append(InjuryNote(title: title, body: body, severity: max(1, min(3, sev))))
                }
            }
        }

        var heatmaps: [ScanShot: HeatmapGrid] = [:]
        if let shotsArr = json["shots"] as? [[String: Any]] {
            for s in shotsArr {
                guard let shotStr = s["shot"] as? String,
                      let shot = ScanShot(rawValue: shotStr),
                      let hm = s["heatmap"] as? [String: Any] else { continue }
                let cols = (hm["cols"] as? Int) ?? HeatmapGrid.columns
                let rows = (hm["rows"] as? Int) ?? HeatmapGrid.rowsCount
                let raw = (hm["values"] as? [Any]) ?? []
                let values = raw.map { v -> Double in
                    if let d = v as? Double { return max(0, min(1, d)) }
                    if let i = v as? Int { return max(0, min(1, Double(i))) }
                    return 0
                }
                let expected = cols * rows
                let normalized: [Double]
                if values.count == expected {
                    normalized = values
                } else if values.count > expected {
                    normalized = Array(values.prefix(expected))
                } else {
                    normalized = values + Array(repeating: 0.0, count: expected - values.count)
                }
                heatmaps[shot] = HeatmapGrid(cols: cols, rows: rows, values: normalized)
            }
        }

        return WearScanResult(
            score: max(0, min(100, score)),
            verdict: verdict,
            estimatedKmRemaining: max(0, kmRem),
            estimatedKmTotalLife: max(kmRem, kmTotal),
            strikePattern: strike,
            pronation: pronation,
            dominantZones: zones,
            injuryNotes: notes,
            heatmapsByShot: heatmaps
        )
    }

    private func stripCodeFences(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.hasPrefix("```") {
            if let nl = out.firstIndex(of: "\n") {
                out = String(out[out.index(after: nl)...])
            }
            if out.hasSuffix("```") {
                out = String(out.dropLast(3))
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIImage {
    nonisolated func resizedForUpload(maxDimension: CGFloat = 1024) -> UIImage {
        let m = max(size.width, size.height)
        guard m > maxDimension else { return self }
        let scale = maxDimension / m
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
