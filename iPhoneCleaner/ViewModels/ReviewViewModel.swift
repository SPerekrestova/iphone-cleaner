import Foundation

enum ReviewState: Equatable {
    case reviewing
    case allReviewed
    case deletionSuccess(count: Int, bytes: Int64)
    case deletionError(String)
}

@Observable
final class ReviewViewModel {
    private(set) var issues: [PhotoIssue]
    let category: IssueCategory
    private(set) var currentIndex: Int = 0
    private(set) var state: ReviewState = .reviewing
    private(set) var undoStack: [(assetId: String, previousDecision: UserDecision)] = []

    var currentIssue: PhotoIssue? {
        guard currentIndex < issues.count else { return nil }
        return issues[currentIndex]
    }

    var markedForDeletion: [PhotoIssue] {
        issues.filter { $0.userDecision == .delete }
    }

    var totalFreeable: Int64 {
        markedForDeletion.reduce(0) { $0 + $1.fileSize }
    }

    var isAllReviewed: Bool {
        !issues.isEmpty && currentIndex >= issues.count
    }

    init(issues: [PhotoIssue], category: IssueCategory) {
        self.issues = issues
        self.category = category
        updateState()
    }

    func markForDeletion() {
        guard currentIndex < issues.count else { return }
        let issue = issues[currentIndex]
        undoStack.append((assetId: issue.assetId, previousDecision: issue.userDecision))
        issues[currentIndex].userDecision = .delete
        currentIndex += 1
        updateState()
    }

    func keepPhoto() {
        guard currentIndex < issues.count else { return }
        let issue = issues[currentIndex]
        undoStack.append((assetId: issue.assetId, previousDecision: issue.userDecision))
        issues[currentIndex].userDecision = .keep
        currentIndex += 1
        updateState()
    }

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        // Bug 1 fix: find by asset ID, not by stored index
        guard let index = issues.firstIndex(where: { $0.assetId == entry.assetId }) else { return }
        issues[index].userDecision = entry.previousDecision
        currentIndex = index
        updateState()
    }

    func applyDeletion() {
        let count = markedForDeletion.count
        let bytes = totalFreeable
        issues.removeAll { $0.userDecision == .delete }
        // Bug 1 fix: clear undo stack — deleted items no longer exist
        undoStack.removeAll()
        // Bug 2 fix: clamp to last valid index, not issues.count
        currentIndex = min(currentIndex, max(issues.count - 1, 0))
        state = .deletionSuccess(count: count, bytes: bytes)
    }

    func handleDeletionError(_ error: Error) {
        state = .deletionError(error.localizedDescription)
    }

    func resetState() {
        updateState()
    }

    private func updateState() {
        if currentIndex >= issues.count && !issues.isEmpty {
            state = .allReviewed
        } else {
            state = .reviewing
        }
    }
}
