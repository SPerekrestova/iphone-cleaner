import SwiftUI
import Photos

struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    let photoService: PhotoLibraryService

    @State private var currentImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var showDeletionError = false
    @Environment(\.dismiss) private var dismiss

    init(issues: [PhotoIssue], category: IssueCategory, photoService: PhotoLibraryService) {
        self._viewModel = State(initialValue: ReviewViewModel(issues: issues, category: category))
        self.photoService = photoService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Progress
                ProgressView(value: Double(viewModel.currentIndex), total: Double(max(viewModel.issues.count, 1)))
                    .tint(.purple)
                    .padding(.horizontal)

                Text("\(min(viewModel.currentIndex + 1, viewModel.issues.count)) of \(viewModel.issues.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("reviewProgress")

                // Swipe card
                if let issue = viewModel.currentIssue {
                    SwipeCardView(
                        image: currentImage,
                        category: issue.category,
                        confidence: issue.confidence,
                        onSwipeLeft: {
                            viewModel.markForDeletion()
                        },
                        onSwipeRight: {
                            viewModel.keepPhoto()
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
                            .accessibilityIdentifier("allReviewedText")
                        if !viewModel.markedForDeletion.isEmpty {
                            Text("\(viewModel.markedForDeletion.count) photos marked for deletion")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                // Bottom toolbar
                HStack(spacing: 40) {
                    // Undo
                    Button {
                        viewModel.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title)
                    }
                    .disabled(viewModel.undoStack.isEmpty)
                    .accessibilityIdentifier("undoButton")

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
                    .accessibilityIdentifier("deleteAllButton")

                    // Skip
                    Button {
                        viewModel.keepPhoto()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .disabled(viewModel.currentIndex >= viewModel.issues.count)
                    .accessibilityIdentifier("skipButton")
                }
                .padding()
            }
            .navigationTitle(viewModel.category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.markedForDeletion.isEmpty {
                        Button("Delete \(viewModel.markedForDeletion.count)") {
                            showDeleteConfirmation = true
                        }
                        .tint(.red)
                    }
                }
            }
            .alert("Delete Photos?", isPresented: $showDeleteConfirmation) {
                Button("Delete \(viewModel.markedForDeletion.count) Photos", role: .destructive) {
                    Task {
                        let idsToDelete = viewModel.markedForDeletion.map { $0.assetId }
                        do {
                            try await photoService.deleteAssets(idsToDelete)
                            viewModel.applyDeletion()
                        } catch {
                            viewModel.handleDeletionError(error)
                            showDeletionError = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move \(viewModel.markedForDeletion.count) photos to Recently Deleted. They can be recovered for 30 days.")
            }
            .alert("Deletion Failed", isPresented: $showDeletionError) {
                Button("OK") {
                    viewModel.resetState()
                }
            } message: {
                if case .deletionError(let message) = viewModel.state {
                    Text(message)
                } else {
                    Text("An unknown error occurred.")
                }
            }
            .fullScreenCover(item: deletionSuccessBinding) { info in
                DeletionSuccessView(
                    photosDeleted: info.count,
                    bytesFreed: info.bytes,
                    onDismiss: {
                        dismiss()
                    }
                )
            }
            .task(id: viewModel.currentIndex) {
                await loadCurrentImage()
            }
        }
    }

    private var deletionSuccessBinding: Binding<DeletionInfo?> {
        Binding(
            get: {
                if case .deletionSuccess(let count, let bytes) = viewModel.state {
                    return DeletionInfo(count: count, bytes: bytes)
                }
                return nil
            },
            set: { newValue in
                if newValue == nil {
                    viewModel.resetState()
                }
            }
        )
    }

    private func loadCurrentImage() async {
        guard let issue = viewModel.currentIssue else { return }
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [issue.assetId],
            options: nil
        )
        guard let asset = fetchResult.firstObject else { return }
        currentImage = await photoService.loadImageWithTimeout(
            for: asset,
            targetSize: CGSize(width: 600, height: 600)
        )
    }
}

private struct DeletionInfo: Identifiable {
    let id = UUID()
    let count: Int
    let bytes: Int64
}
