import Testing
import Foundation
@testable import iPhoneCleaner

@Test func scanSettingsIntegration() {
    var settings = ScanSettings()
    settings.blurThreshold = 0.5
    settings.duplicateThreshold = 0.9
    settings.batchSize = 10

    #expect(settings.blurThreshold == 0.5)
    #expect(settings.duplicateThreshold == 0.9)
    #expect(settings.batchSize == 10)
}

@Test func scanResultTotalIssues() {
    let result = ScanResult(
        totalPhotosScanned: 1000,
        duplicatesFound: 50,
        similarFound: 30,
        blurryFound: 20,
        screenshotsFound: 100
    )
    #expect(result.totalIssuesFound == 200)
}

@Test func photoIssueUserDecisionWorkflow() {
    var issue = PhotoIssue(
        assetId: "test1",
        category: .blurry,
        confidence: 0.85,
        fileSize: 1_000_000
    )
    #expect(issue.userDecision == .pending)

    issue.userDecision = .delete
    #expect(issue.userDecision == .delete)

    issue.userDecision = .keep
    #expect(issue.userDecision == .keep)
}

@Test func appInfoCleanupScoreOrdering() {
    let oldLargeApp = AppInfo(
        id: "1", name: "Big Old Game", bundleId: "com.test.game",
        sizeBytes: 3_000_000_000,
        lastUsedDate: Calendar.current.date(byAdding: .day, value: -90, to: Date())
    )
    let newSmallApp = AppInfo(
        id: "2", name: "Daily App", bundleId: "com.test.daily",
        sizeBytes: 10_000_000,
        lastUsedDate: Date()
    )

    #expect(oldLargeApp.cleanupScore > newSmallApp.cleanupScore)
}
