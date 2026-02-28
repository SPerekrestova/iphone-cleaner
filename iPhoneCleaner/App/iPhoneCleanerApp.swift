import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("UI_TESTING_SEED_DATA") {
                        seedTestData()
                    }
                }
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }

    private func seedTestData() {
        let result = ScanResult(
            totalPhotosScanned: 100,
            duplicatesFound: 3,
            blurryFound: 2,
            screenshotsFound: 5
        )
        let issues: [PhotoIssue] = [
            PhotoIssue(assetId: "test-dup-1", category: .duplicate, confidence: 0.95, fileSize: 1_000_000),
            PhotoIssue(assetId: "test-dup-2", category: .duplicate, confidence: 0.90, fileSize: 900_000),
            PhotoIssue(assetId: "test-dup-3", category: .duplicate, confidence: 0.88, fileSize: 800_000),
            PhotoIssue(assetId: "test-blur-1", category: .blurry, confidence: 0.80, fileSize: 500_000),
            PhotoIssue(assetId: "test-blur-2", category: .blurry, confidence: 0.75, fileSize: 400_000),
            PhotoIssue(assetId: "test-ss-1", category: .screenshot, confidence: 1.0, fileSize: 200_000),
            PhotoIssue(assetId: "test-ss-2", category: .screenshot, confidence: 1.0, fileSize: 200_000),
            PhotoIssue(assetId: "test-ss-3", category: .screenshot, confidence: 1.0, fileSize: 200_000),
            PhotoIssue(assetId: "test-ss-4", category: .screenshot, confidence: 1.0, fileSize: 200_000),
            PhotoIssue(assetId: "test-ss-5", category: .screenshot, confidence: 1.0, fileSize: 200_000),
        ]
        result.issues = issues
        appState.lastScanResult = result
        appState.lastScanIssues = issues
    }
}
