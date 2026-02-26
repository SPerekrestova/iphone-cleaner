import SwiftUI
import Photos

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isScanning = false
    @State private var showReview = false
    @State private var showPermission = false
    @State private var selectedCategory: IssueCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Storage Ring
                    StorageRingView(
                        fraction: appState.storageFraction,
                        usedText: appState.storageUsedFormatted,
                        totalText: appState.storageTotalFormatted
                    )
                    .padding(.top)

                    // Scan Button
                    Button {
                        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                        if status == .authorized || status == .limited {
                            isScanning = true
                        } else {
                            showPermission = true
                        }
                    } label: {
                        Label("Scan Photos", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accentGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Category Results
                    if let result = appState.lastScanResult {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last Scan")
                                .font(.headline)
                                .padding(.horizontal)

                            CategoryCardView(category: .duplicate, count: result.duplicatesFound) {
                                selectedCategory = .duplicate
                                showReview = true
                            }
                            CategoryCardView(category: .similar, count: result.similarFound) {
                                selectedCategory = .similar
                                showReview = true
                            }
                            CategoryCardView(category: .blurry, count: result.blurryFound) {
                                selectedCategory = .blurry
                                showReview = true
                            }
                            CategoryCardView(category: .screenshot, count: result.screenshotsFound) {
                                selectedCategory = .screenshot
                                showReview = true
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("iPhone Cleaner")
            .fullScreenCover(isPresented: $isScanning) {
                ScanningView(scanEngine: appState.scanEngine, settings: appState.scanSettings) { result in
                    appState.saveScanResult(result, context: modelContext)
                    isScanning = false
                    appState.loadStorageInfo()
                }
            }
            .sheet(isPresented: $showReview) {
                if let category = selectedCategory {
                    ReviewView(
                        issues: appState.scanEngine.issues.filter { $0.category == category },
                        category: category,
                        photoService: appState.photoService
                    )
                }
            }
            .sheet(isPresented: $showPermission) {
                PhotoPermissionView {
                    showPermission = false
                    isScanning = true
                }
            }
            .onAppear {
                appState.loadStorageInfo()
                appState.loadLastScanResult(context: modelContext)
            }
        }
    }
}
