import Foundation
import UIKit

@Observable
final class AppCleanupViewModel {
    var apps: [AppInfo] = []
    var isLoadingSuggestions = false
    var suggestionError: String?

    private let miraiService = MiraiService()

    func loadApps() {
        // Demo data — iOS doesn't allow listing installed apps
        apps = [
            AppInfo(
                id: "1", name: "Forgotten RPG",
                bundleId: "com.example.rpg",
                sizeBytes: 3_200_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -180, to: Date())
            ),
            AppInfo(
                id: "2", name: "Video Editor Pro",
                bundleId: "com.example.videoeditor",
                sizeBytes: 1_800_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -45, to: Date())
            ),
            AppInfo(
                id: "3", name: "Social Media X",
                bundleId: "com.example.social",
                sizeBytes: 450_000_000,
                lastUsedDate: Date()
            ),
            AppInfo(
                id: "4", name: "Old Navigation",
                bundleId: "com.example.nav",
                sizeBytes: 280_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -90, to: Date())
            ),
            AppInfo(
                id: "5", name: "Fitness Tracker",
                bundleId: "com.example.fitness",
                sizeBytes: 150_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())
            ),
            AppInfo(
                id: "6", name: "Weather Widget",
                bundleId: "com.example.weather",
                sizeBytes: 35_000_000,
                lastUsedDate: Date()
            ),
        ]
    }

    func generateSuggestions() async {
        guard !apps.isEmpty else { return }
        isLoadingSuggestions = true
        suggestionError = nil
        defer { isLoadingSuggestions = false }

        do {
            try await miraiService.initialize(apiKey: MiraiConfig.apiKey)
            try await miraiService.loadModel()
            let suggestions = try await miraiService.generateAppSuggestions(for: apps)

            for i in 0..<apps.count {
                apps[i].aiSuggestion = suggestions
            }
        } catch {
            suggestionError = "Failed to generate suggestions: \(error.localizedDescription)"
            print("Mirai error: \(error)")
        }
    }
}

enum MiraiConfig {
    static var apiKey: String {
        ProcessInfo.processInfo.environment["MIRAI_API_KEY"] ?? ""
    }
}
