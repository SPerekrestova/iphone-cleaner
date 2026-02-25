import Testing
import Foundation
@testable import iPhoneCleaner

@Test func appSuggestionPromptGeneration() {
    let apps = [
        AppInfo(
            id: "1",
            name: "Old Game",
            bundleId: "com.example.game",
            sizeBytes: 2_000_000_000,
            lastUsedDate: Calendar.current.date(byAdding: .day, value: -120, to: Date())
        ),
        AppInfo(
            id: "2",
            name: "Camera App",
            bundleId: "com.example.camera",
            sizeBytes: 50_000_000,
            lastUsedDate: Date()
        )
    ]
    let prompt = MiraiService.buildAppSuggestionPrompt(for: apps)
    #expect(prompt.contains("Old Game"))
    #expect(prompt.contains("2.0 GB") || prompt.contains("2 GB"))
    #expect(prompt.contains("Camera App"))
}
