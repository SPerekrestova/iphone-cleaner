import Testing
import Foundation
@testable import iPhoneCleaner

@Test func photoIssueCreation() {
    let issue = PhotoIssue(
        assetId: "ABC123",
        category: .blurry,
        confidence: 0.85,
        fileSize: 2_500_000
    )
    #expect(issue.assetId == "ABC123")
    #expect(issue.category == .blurry)
    #expect(issue.confidence == 0.85)
    #expect(issue.fileSize == 2_500_000)
    #expect(issue.userDecision == .pending)
}

@Test func photoIssueCategoryDisplayName() {
    #expect(IssueCategory.duplicate.displayName == "Duplicates")
    #expect(IssueCategory.similar.displayName == "Similar")
    #expect(IssueCategory.blurry.displayName == "Blurry")
    #expect(IssueCategory.screenshot.displayName == "Screenshots")
}

@Test func photoIssueFileSizeFormatted() {
    let small = PhotoIssue(assetId: "a", category: .blurry, confidence: 0.9, fileSize: 500_000)
    #expect(small.fileSizeFormatted.contains("KB") || small.fileSizeFormatted.contains("kB"))

    let large = PhotoIssue(assetId: "b", category: .blurry, confidence: 0.9, fileSize: 2_500_000)
    #expect(large.fileSizeFormatted.contains("MB"))
}
