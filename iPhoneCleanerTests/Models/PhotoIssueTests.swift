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

@Test func newCategoryDisplayNames() {
    #expect(IssueCategory.screenRecording.displayName == "Screen Recordings")
    #expect(IssueCategory.lensSmudge.displayName == "Lens Smudge")
    #expect(IssueCategory.textHeavy.displayName == "Text Heavy")
    #expect(IssueCategory.lowQuality.displayName == "Low Quality")
}

@Test func newCategorySystemImages() {
    #expect(!IssueCategory.screenRecording.systemImage.isEmpty)
    #expect(!IssueCategory.lensSmudge.systemImage.isEmpty)
    #expect(!IssueCategory.textHeavy.systemImage.isEmpty)
    #expect(!IssueCategory.lowQuality.systemImage.isEmpty)
}

@Test func photoIssueWithSceneTags() {
    let issue = PhotoIssue(
        assetId: "test1",
        category: .blurry,
        confidence: 0.8,
        fileSize: 1_000_000,
        sceneTags: ["food", "indoor"]
    )
    #expect(issue.sceneTags == ["food", "indoor"])
}

@Test func photoIssueFileSizeFormatted() {
    let small = PhotoIssue(assetId: "a", category: .blurry, confidence: 0.9, fileSize: 500_000)
    #expect(small.fileSizeFormatted.contains("KB") || small.fileSizeFormatted.contains("kB"))

    let large = PhotoIssue(assetId: "b", category: .blurry, confidence: 0.9, fileSize: 2_500_000)
    #expect(large.fileSizeFormatted.contains("MB"))
}
