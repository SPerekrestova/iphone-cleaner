import Foundation
import UIKit

@Observable
final class AppCleanupViewModel {
    var apps: [AppInfo] = []
    var isLoadingSuggestions = false
    var selectedApp: AppInfo?

    private let miraiService = MiraiService()

    func loadApps() {
        // Note: iOS has limited APIs for listing installed apps.
        // We can use LSApplicationWorkspace (private API, App Store rejection risk)
        // or DeviceActivityFramework for usage data.
        // For now, we provide a placeholder that works with Screen Time data.
        // Real implementation would use FamilyControls framework.
    }

    func generateSuggestions() async {
        guard !apps.isEmpty else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            // Initialize Mirai with API key from Keychain or bundled config
            try await miraiService.initialize(apiKey: MiraiConfig.apiKey)
            try await miraiService.loadModel()
            let suggestions = try await miraiService.generateAppSuggestions(for: apps)

            // Parse suggestions and assign to apps
            // Simple approach: assign the full text to the top apps
            for i in 0..<apps.count {
                apps[i].aiSuggestion = suggestions
            }
        } catch {
            print("Failed to generate suggestions: \(error)")
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

enum MiraiConfig {
    // In production, store in Keychain. For development, use environment variable or config file.
    static var apiKey: String {
        ProcessInfo.processInfo.environment["MIRAI_API_KEY"] ?? ""
    }
}
