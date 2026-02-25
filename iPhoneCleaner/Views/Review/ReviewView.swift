import SwiftUI
import Photos

struct ReviewView: View {
    @State var issues: [PhotoIssue]
    let category: IssueCategory
    let photoService: PhotoLibraryService

    @State private var currentIndex = 0
    @State private var currentImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var undoStack: [(Int, UserDecision)] = []
    @Environment(\.dismiss) private var dismiss

    private var pendingIssues: [PhotoIssue] {
        issues.filter { $0.userDecision == .pending }
    }

    private var markedForDeletion: [PhotoIssue] {
        issues.filter { $0.userDecision == .delete }
    }

    private var totalFreeable: Int64 {
        markedForDeletion.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Progress
                ProgressView(value: Double(currentIndex), total: Double(max(issues.count, 1)))
                    .tint(.purple)
                    .padding(.horizontal)

                Text("\(currentIndex + 1) of \(issues.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Swipe card
                if currentIndex < issues.count {
                    let issue = issues[currentIndex]
                    SwipeCardView(
                        image: currentImage,
                        category: issue.category,
                        confidence: issue.confidence,
                        onSwipeLeft: {
                            markForDeletion()
                        },
                        onSwipeRight: {
                            keepPhoto()
                        }
                    )
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("All reviewed!")
                            .font(.title2.bold())
                        if !markedForDeletion.isEmpty {
                            Text("\(markedForDeletion.count) photos marked for deletion")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                // Bottom toolbar
                HStack(spacing: 40) {
                    // Undo
                    Button {
                        undoLast()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title)
                    }
                    .disabled(undoStack.isEmpty)

                    // Delete All
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.title)
                            Text("Delete All")
                                .font(.caption2)
                        }
                    }
                    .tint(.red)

                    // Skip
                    Button {
                        keepPhoto()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .disabled(currentIndex >= issues.count)
                }
                .padding()
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !markedForDeletion.isEmpty {
                        Button("Delete \(markedForDeletion.count)") {
                            showDeleteConfirmation = true
                        }
                        .tint(.red)
                    }
                }
            }
            .alert("Delete Photos?", isPresented: $showDeleteConfirmation) {
                Button("Delete \(markedForDeletion.count) Photos", role: .destructive) {
                    Task {
                        let idsToDelete = markedForDeletion.map { $0.assetId }
                        try? await photoService.deleteAssets(idsToDelete)
                        issues.removeAll { $0.userDecision == .delete }
                        currentIndex = min(currentIndex, issues.count)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move \(markedForDeletion.count) photos to Recently Deleted. They can be recovered for 30 days.")
            }
            .task(id: currentIndex) {
                await loadCurrentImage()
            }
        }
    }

    private func markForDeletion() {
        guard currentIndex < issues.count else { return }
        undoStack.append((currentIndex, issues[currentIndex].userDecision))
        issues[currentIndex].userDecision = .delete
        currentIndex += 1
    }

    private func keepPhoto() {
        guard currentIndex < issues.count else { return }
        undoStack.append((currentIndex, issues[currentIndex].userDecision))
        issues[currentIndex].userDecision = .keep
        currentIndex += 1
    }

    private func undoLast() {
        guard let (index, previousDecision) = undoStack.popLast() else { return }
        issues[index].userDecision = previousDecision
        currentIndex = index
    }

    private func loadCurrentImage() async {
        guard currentIndex < issues.count else { return }
        let assetId = issues[currentIndex].assetId
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId],
            options: nil
        )
        guard let asset = fetchResult.firstObject else { return }
        currentImage = await photoService.loadImage(
            for: asset,
            targetSize: CGSize(width: 600, height: 600)
        )
    }
}
