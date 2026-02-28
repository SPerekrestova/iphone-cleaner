import Testing
import Foundation
@testable import iPhoneCleaner

// MARK: - Helpers

private func makeIssue(
    id: String = UUID().uuidString,
    category: IssueCategory = .blurry,
    confidence: Double = 0.9,
    fileSize: Int64 = 1_000_000
) -> PhotoIssue {
    PhotoIssue(assetId: id, category: category, confidence: confidence, fileSize: fileSize)
}

private func makeVM(count: Int = 3) -> ReviewViewModel {
    let issues = (0..<count).map { makeIssue(id: "asset-\($0)") }
    return ReviewViewModel(issues: issues, category: .blurry)
}

// MARK: - Navigation

@Test func markAdvancesIndex() {
    let vm = makeVM()
    #expect(vm.currentIndex == 0)
    vm.markForDeletion()
    #expect(vm.currentIndex == 1)
}

@Test func keepAdvancesIndex() {
    let vm = makeVM()
    vm.keepPhoto()
    #expect(vm.currentIndex == 1)
    #expect(vm.issues[0].userDecision == .keep)
}

@Test func markAtEndIsNoOp() {
    let vm = makeVM(count: 1)
    vm.markForDeletion()
    #expect(vm.currentIndex == 1)
    #expect(vm.isAllReviewed)
    vm.markForDeletion() // should be no-op
    #expect(vm.currentIndex == 1)
    #expect(vm.markedForDeletion.count == 1)
}

// MARK: - Undo

@Test func undoRestoresByAssetId() {
    let vm = makeVM()
    vm.markForDeletion() // asset-0 marked delete
    vm.keepPhoto()       // asset-1 marked keep
    vm.undo()            // should restore asset-1
    #expect(vm.currentIndex == 1)
    #expect(vm.issues[1].userDecision == .pending)
}

@Test func undoClearsAfterDeletion() {
    let vm = makeVM()
    vm.markForDeletion() // asset-0
    vm.keepPhoto()       // asset-1
    #expect(!vm.undoStack.isEmpty)
    vm.applyDeletion()
    #expect(vm.undoStack.isEmpty)
}

@Test func undoNoOpOnEmptyStack() {
    let vm = makeVM()
    let indexBefore = vm.currentIndex
    vm.undo()
    #expect(vm.currentIndex == indexBefore)
}

// MARK: - Bug 1: Undo after deletion doesn't corrupt

@Test func undoAfterDeletionDoesNotCorrupt() {
    let vm = makeVM(count: 3)
    vm.markForDeletion() // asset-0 → delete
    vm.keepPhoto()       // asset-1 → keep
    vm.keepPhoto()       // asset-2 → keep
    vm.applyDeletion()   // removes asset-0, clears undo
    // undo should be no-op since stack was cleared
    vm.undo()
    #expect(vm.issues.count == 2)
    // no wrong photo accessed — all remaining are keep
    for issue in vm.issues {
        #expect(issue.userDecision == .keep)
    }
}

// MARK: - Bug 2: currentIndex valid after operations

@Test func currentIndexValidAfterDeletionAtEnd() {
    let vm = makeVM(count: 2)
    vm.markForDeletion() // asset-0
    vm.markForDeletion() // asset-1
    // currentIndex == 2, both marked
    vm.applyDeletion()
    // all removed, issues empty
    #expect(vm.issues.isEmpty)
    #expect(vm.currentIndex == 0)
}

@Test func currentIndexValidWhenAllDeleted() {
    let vm = makeVM(count: 1)
    vm.markForDeletion()
    vm.applyDeletion()
    #expect(vm.issues.isEmpty)
    #expect(vm.currentIndex == 0)
    #expect(vm.currentIssue == nil)
}

@Test func currentIndexValidOnEmptyArray() {
    let vm = ReviewViewModel(issues: [], category: .blurry)
    #expect(vm.currentIndex == 0)
    #expect(vm.currentIssue == nil)
    #expect(vm.isAllReviewed == false) // empty is not "all reviewed"
}

// MARK: - Edge cases

@Test func singleItemMarkAndUndo() {
    let vm = makeVM(count: 1)
    vm.markForDeletion()
    #expect(vm.isAllReviewed)
    vm.undo()
    #expect(vm.currentIndex == 0)
    #expect(vm.issues[0].userDecision == .pending)
    #expect(!vm.isAllReviewed)
}

@Test func allReviewedStateTransition() {
    let vm = makeVM(count: 2)
    #expect(vm.state == .reviewing)
    vm.keepPhoto()
    #expect(vm.state == .reviewing)
    vm.keepPhoto()
    #expect(vm.state == .allReviewed)
    vm.undo()
    #expect(vm.state == .reviewing)
}

// MARK: - Deletion

@Test func markedForDeletionFilterAccuracy() {
    let vm = makeVM(count: 3)
    vm.markForDeletion() // asset-0 → delete
    vm.keepPhoto()       // asset-1 → keep
    vm.markForDeletion() // asset-2 → delete
    #expect(vm.markedForDeletion.count == 2)
    #expect(vm.markedForDeletion.allSatisfy { $0.userDecision == .delete })
}

@Test func errorStatePropagation() {
    let vm = makeVM()
    struct TestError: Error, LocalizedError {
        var errorDescription: String? { "Photo library access denied" }
    }
    vm.handleDeletionError(TestError())
    #expect(vm.state == .deletionError("Photo library access denied"))
}

@Test func resetStateAfterDeletion() {
    let vm = makeVM(count: 2)
    vm.markForDeletion() // asset-0 → delete
    vm.keepPhoto()       // asset-1 → keep
    vm.applyDeletion()   // removes asset-0, keeps asset-1
    #expect(vm.state == .deletionSuccess(count: 1, bytes: 1_000_000))
    vm.resetState()
    // currentIndex clamped to 0, 1 issue remaining → reviewing
    #expect(vm.state == .reviewing)
}
