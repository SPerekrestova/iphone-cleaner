import Foundation

struct AppInfo: Identifiable {
    let id: String
    let name: String
    let bundleId: String
    let sizeBytes: Int64
    let lastUsedDate: Date?
    var aiSuggestion: String?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var daysSinceLastUsed: Int? {
        guard let lastUsed = lastUsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day
    }

    var cleanupScore: Double {
        let sizeScore = Double(sizeBytes) / 1_000_000_000.0
        let usageScore: Double = if let days = daysSinceLastUsed {
            min(Double(days) / 90.0, 1.0)
        } else {
            0.5
        }
        return (sizeScore * 0.4) + (usageScore * 0.6)
    }
}
