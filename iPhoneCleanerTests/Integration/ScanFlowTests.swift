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
    #expect(result.totalMediaScanned == 1000)
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
