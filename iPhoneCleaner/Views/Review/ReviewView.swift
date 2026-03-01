import SwiftUI
import Photos

struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    let photoService: PhotoLibraryService

    @State private var currentImage: UIImage?
    @State private var imageCache: [String: UIImage] = [:]
    @State private var showDeleteConfirmation = false
    @State private var showDeletionError = false
    @State private var deletionInfo: DeletionInfo?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

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
                        let count = viewModel.markedForDeletion.count
                        let bytes = viewModel.totalFreeable
                        do {
                            try await photoService.deleteAssets(idsToDelete)
                            viewModel.applyDeletion()
                            appState.removeDeletedIssues(Set(idsToDelete))
                            deletionInfo = DeletionInfo(count: count, bytes: bytes)
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
            .fullScreenCover(item: $deletionInfo) { info in
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

    private func loadCurrentImage() async {
        guard let issue = viewModel.currentIssue else { return }

        // Use cache if available
        if let cached = imageCache[issue.assetId] {
            currentImage = cached
        } else {
            currentImage = nil
        }

        // Load current image if not cached
        if imageCache[issue.assetId] == nil {
            let image = await loadImage(for: issue.assetId)
            imageCache[issue.assetId] = image
            if viewModel.currentIssue?.assetId == issue.assetId {
                currentImage = image
            }
        }

        // Prefetch next 2
        let prefetchStart = viewModel.currentIndex + 1
        let prefetchEnd = min(viewModel.currentIndex + 2, viewModel.issues.count - 1)
        if prefetchStart <= prefetchEnd {
            for i in prefetchStart...prefetchEnd {
                let nextId = viewModel.issues[i].assetId
                if imageCache[nextId] == nil {
                    let image = await loadImage(for: nextId)
                    imageCache[nextId] = image
                }
            }
        }

        // Evict old entries (keep only current ± 2)
        let lo = max(viewModel.currentIndex - 2, 0)
        let hi = min(viewModel.currentIndex + 2, viewModel.issues.count - 1)
        if lo <= hi {
            let keepIds = Set((lo...hi).compactMap { i in
                i < viewModel.issues.count ? viewModel.issues[i].assetId : nil
            })
            imageCache = imageCache.filter { keepIds.contains($0.key) }
        }
    }

    private func loadImage(for assetId: String) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId],
            options: nil
        )
        guard let asset = fetchResult.firstObject else { return nil }
        return await photoService.loadImageWithTimeout(
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
