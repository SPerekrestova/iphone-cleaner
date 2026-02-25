# iPhone Cleaner v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire the app end-to-end so scanning, reviewing, and deleting photos works with real images. Integrate Mirai LLM for app suggestions. Minimal polish.

**Architecture:** Replace scattered `@State` ViewModels with a shared `@Observable AppState` injected via `.environment()`. Settings flow into scan engine. ReviewView connects to DeletionSuccessView. Mirai SDK added via SPM.

**Tech Stack:** Swift, SwiftUI, SwiftData, PhotoKit, Vision, CoreML, Mirai SDK (`uzu-swift` v0.2.10+), XcodeGen, iOS 17+

**Note:** Simulator has photos available for testing. Run `xcodebuild test` with destination `'platform=iOS Simulator,name=iPhone 17 Pro'`.

---

### Task 1: Create AppState and Wire to App Root

**Files:**
- Create: `iPhoneCleaner/App/AppState.swift`
- Modify: `iPhoneCleaner/App/iPhoneCleanerApp.swift`
- Modify: `iPhoneCleaner/ContentView.swift`
- Create: `iPhoneCleanerTests/App/AppStateTests.swift`

**Step 1: Write tests for AppState**

Create `iPhoneCleanerTests/App/AppStateTests.swift`:
```swift
import Testing
import Foundation
@testable import iPhoneCleaner

@Test func appStateInitialValues() {
    let state = AppState()
    #expect(state.scanSettings.blurThreshold == 0.3)
    #expect(state.scanSettings.batchSize == 30)
    #expect(state.storageUsed == 0)
    #expect(state.storageTotal == 0)
    #expect(state.lastScanResult == nil)
}

@Test func appStateStorageFraction() {
    let state = AppState()
    state.storageUsed = 50_000_000_000
    state.storageTotal = 100_000_000_000
    #expect(state.storageFraction == 0.5)
}

@Test func appStateStorageFractionZeroTotal() {
    let state = AppState()
    #expect(state.storageFraction == 0.0)
}

@Test func appStateLoadStorageInfo() {
    let state = AppState()
    state.loadStorageInfo()
    #expect(state.storageTotal > 0)
    #expect(state.storageUsed > 0)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: FAIL — `AppState` not defined.

**Step 3: Implement AppState**

Create `iPhoneCleaner/App/AppState.swift`:
```swift
import Foundation
import SwiftUI

@Observable
final class AppState {
    let scanEngine = PhotoScanEngine()
    let photoService = PhotoLibraryService()
    let miraiService = MiraiService()

    var scanSettings = ScanSettings()
    var lastScanResult: ScanResult?
    var storageUsed: Int64 = 0
    var storageTotal: Int64 = 0

    var storageUsedFormatted: String {
        ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
    }

    var storageTotalFormatted: String {
        ByteCountFormatter.string(fromByteCount: storageTotal, countStyle: .file)
    }

    var storageFraction: Double {
        guard storageTotal > 0 else { return 0 }
        return Double(storageUsed) / Double(storageTotal)
    }

    func loadStorageInfo() {
        let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        storageTotal = (attrs?[.systemSize] as? Int64) ?? 0
        let freeSpace = (attrs?[.systemFreeSize] as? Int64) ?? 0
        storageUsed = storageTotal - freeSpace
    }
}
```

**Step 4: Inject AppState at app root**

Replace `iPhoneCleaner/App/iPhoneCleanerApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }
}
```

**Step 5: Update ContentView to pass environment**

Replace `iPhoneCleaner/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                }

            AppCleanupView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.purple)
    }
}
```

**Step 6: Regenerate project, run tests**

Run: `xcodegen generate && xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS (including 4 new AppState tests).

**Step 7: Commit**

```bash
git add iPhoneCleaner/App/AppState.swift iPhoneCleaner/App/iPhoneCleanerApp.swift iPhoneCleaner/ContentView.swift iPhoneCleanerTests/App/AppStateTests.swift iPhoneCleaner.xcodeproj/project.pbxproj
git commit -m "feat: add shared AppState and inject via environment"
```

---

### Task 2: Wire Settings to AppState

**Files:**
- Modify: `iPhoneCleaner/Views/Settings/SettingsView.swift`

**Step 1: Update SettingsView to use AppState**

Replace `iPhoneCleaner/Views/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section("Detection Sensitivity") {
                    VStack(alignment: .leading) {
                        Text("Blur Threshold: \(Int(appState.scanSettings.blurThreshold * 100))%")
                        Slider(value: $appState.scanSettings.blurThreshold, in: 0.1...0.8, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as blurry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Similarity Threshold: \(Int(Double(appState.scanSettings.similarThreshold) * 100))%")
                        Slider(value: Binding(
                            get: { Double(appState.scanSettings.similarThreshold) },
                            set: { appState.scanSettings.similarThreshold = Float($0) }
                        ), in: 0.5...0.99, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as similar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Privacy") {
                    Label("All processing happens on your device", systemImage: "lock.shield")
                    Label("No data is sent to any server", systemImage: "wifi.slash")
                    Label("No account required", systemImage: "person.slash")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Step 2: Build and run**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add iPhoneCleaner/Views/Settings/SettingsView.swift
git commit -m "feat: wire SettingsView sliders to AppState.scanSettings"
```

---

### Task 3: Wire HomeView to AppState

**Files:**
- Modify: `iPhoneCleaner/Views/Home/HomeView.swift`
- Delete: `iPhoneCleaner/ViewModels/HomeViewModel.swift`

**Step 1: Replace HomeView to use AppState instead of HomeViewModel**

Replace `iPhoneCleaner/Views/Home/HomeView.swift`:
```swift
import SwiftUI
import Photos

struct HomeView: View {
    @Environment(AppState.self) private var appState
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
                ScanningView(scanEngine: appState.scanEngine) { result in
                    appState.lastScanResult = result
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
            }
        }
    }
}
```

**Step 2: Delete HomeViewModel**

Delete `iPhoneCleaner/ViewModels/HomeViewModel.swift` — its logic is now in AppState.

**Step 3: Build and run tests**

Run: `xcodegen generate && xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS. BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add iPhoneCleaner/Views/Home/HomeView.swift iPhoneCleaner.xcodeproj/project.pbxproj
git rm iPhoneCleaner/ViewModels/HomeViewModel.swift
git commit -m "feat: wire HomeView to shared AppState, remove HomeViewModel"
```

---

### Task 4: Wire Scan Engine to Use AppState Settings

**Files:**
- Modify: `iPhoneCleaner/Views/Scanning/ScanningView.swift`

**Step 1: Update ScanningView to pass settings from AppState**

Replace `iPhoneCleaner/Views/Scanning/ScanningView.swift`:
```swift
import SwiftUI

struct ScanningView: View {
    let scanEngine: PhotoScanEngine
    let settings: ScanSettings
    let onComplete: (ScanResult) -> Void

    @State private var hasStarted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: scanEngine.progress.fraction)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: scanEngine.progress.fraction)

                VStack(spacing: 4) {
                    Text(scanEngine.progress.percentFormatted)
                        .font(.largeTitle.bold())
                    Text("\(scanEngine.progress.processed) of \(scanEngine.progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Analyzing your photos...")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Live category counts
            VStack(spacing: 8) {
                ForEach(IssueCategory.allCases, id: \.self) { category in
                    let count = scanEngine.progress.categoryCounts[category] ?? 0
                    HStack {
                        Image(systemName: category.systemImage)
                            .frame(width: 24)
                        Text(category.displayName)
                        Spacer()
                        Text("\(count)")
                            .bold()
                    }
                    .foregroundStyle(count > 0 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            do {
                let issues = try await scanEngine.scan(settings: settings)
                let result = ScanResult(
                    totalPhotosScanned: scanEngine.progress.total,
                    duplicatesFound: issues.filter { $0.category == .duplicate }.count,
                    similarFound: issues.filter { $0.category == .similar }.count,
                    blurryFound: issues.filter { $0.category == .blurry }.count,
                    screenshotsFound: issues.filter { $0.category == .screenshot }.count,
                    totalSizeReclaimable: issues.reduce(0) { $0 + $1.fileSize }
                )
                onComplete(result)
            } catch {
                dismiss()
            }
        }
    }
}
```

**Step 2: Update HomeView call site to pass settings**

In `iPhoneCleaner/Views/Home/HomeView.swift`, update the `ScanningView` init in the `.fullScreenCover`:
```swift
            .fullScreenCover(isPresented: $isScanning) {
                ScanningView(scanEngine: appState.scanEngine, settings: appState.scanSettings) { result in
                    appState.lastScanResult = result
                    isScanning = false
                    appState.loadStorageInfo()
                }
            }
```

**Step 3: Build and run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add iPhoneCleaner/Views/Scanning/ScanningView.swift iPhoneCleaner/Views/Home/HomeView.swift
git commit -m "feat: pass ScanSettings from AppState to scan engine"
```

---

### Task 5: Connect ReviewView to DeletionSuccessView

**Files:**
- Modify: `iPhoneCleaner/Views/Review/ReviewView.swift`

**Step 1: Update ReviewView to show DeletionSuccessView after batch delete**

In `iPhoneCleaner/Views/Review/ReviewView.swift`, add a `@State private var deletionResult: (count: Int, bytes: Int64)?` property and a `.fullScreenCover` for `DeletionSuccessView`.

Replace the delete confirmation handler to track results:
```swift
// Add to state properties (after showDeleteConfirmation):
    @State private var deletionResult: (count: Int, bytes: Int64)?
```

Replace the `.alert` delete button action:
```swift
            .alert("Delete Photos?", isPresented: $showDeleteConfirmation) {
                Button("Delete \(markedForDeletion.count) Photos", role: .destructive) {
                    let count = markedForDeletion.count
                    let bytes = totalFreeable
                    Task {
                        let idsToDelete = markedForDeletion.map { $0.assetId }
                        try? await photoService.deleteAssets(idsToDelete)
                        issues.removeAll { $0.userDecision == .delete }
                        currentIndex = min(currentIndex, issues.count)
                        deletionResult = (count: count, bytes: bytes)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move \(markedForDeletion.count) photos to Recently Deleted. They can be recovered for 30 days.")
            }
```

Add after the `.alert` modifier:
```swift
            .fullScreenCover(item: Binding(
                get: { deletionResult.map { DeletionInfo(count: $0.count, bytes: $0.bytes) } },
                set: { if $0 == nil { deletionResult = nil } }
            )) { info in
                DeletionSuccessView(
                    photosDeleted: info.count,
                    bytesFreed: info.bytes,
                    onDismiss: {
                        deletionResult = nil
                        dismiss()
                    }
                )
            }
```

Add a small helper struct at the bottom of the file (before the closing brace or after the struct):
```swift
private struct DeletionInfo: Identifiable {
    let id = UUID()
    let count: Int
    let bytes: Int64
}
```

**Step 2: Build and run**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add iPhoneCleaner/Views/Review/ReviewView.swift
git commit -m "feat: show DeletionSuccessView after batch delete in ReviewView"
```

---

### Task 6: Add Mirai SDK as SPM Dependency

**Files:**
- Modify: `project.yml`
- Modify: `iPhoneCleaner/Services/MiraiService.swift`

**Step 1: Uncomment and update Mirai SDK in project.yml**

Update `project.yml` to enable the Mirai SDK package:
```yaml
name: iPhoneCleaner
options:
  bundleIdPrefix: com.svetlana
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"

packages:
  MiraiSDK:
    url: https://github.com/trymirai/uzu-swift.git
    from: "0.2.10"

targets:
  iPhoneCleaner:
    type: application
    platform: iOS
    sources:
      - iPhoneCleaner
    settings:
      base:
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "iPhone Cleaner needs access to your photo library to find duplicates, blurry photos, and screenshots for cleanup."
        INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription: "iPhone Cleaner needs write access to move selected photos to Recently Deleted."
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: YES
        INCREASED_MEMORY_LIMIT: YES
    dependencies:
      - package: MiraiSDK

  iPhoneCleanerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - iPhoneCleanerTests
    settings:
      base:
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: iPhoneCleaner
```

Note: `INCREASED_MEMORY_LIMIT: YES` is recommended by Mirai docs for on-device model inference.

**Step 2: Remove `#if canImport(Uzu)` conditionals from MiraiService**

Replace `iPhoneCleaner/Services/MiraiService.swift`:
```swift
import Foundation
import Uzu

final class MiraiService {
    private var engine: UzuEngine?
    private var chatModel: ChatModel?

    func initialize(apiKey: String) async throws {
        engine = try await UzuEngine.create(apiKey: apiKey)
    }

    func loadModel(repoId: String = "Qwen/Qwen3-0.6B") async throws {
        guard let engine else { throw MiraiError.notInitialized }

        let model = try await engine.chatModel(repoId: repoId)
        try await engine.downloadChatModel(model) { update in
            print("Model download progress: \(update.progress)")
        }
        self.chatModel = model
    }

    func generateAppSuggestions(for apps: [AppInfo]) async throws -> String {
        guard let engine, let model = chatModel else {
            throw MiraiError.notInitialized
        }

        let prompt = Self.buildAppSuggestionPrompt(for: apps)

        let session = try engine.chatSession(model)
        let input: Input = .messages(messages: [
            Message(role: .system, content: """
                You are a helpful iPhone storage assistant. Analyze the user's installed apps \
                and provide brief, actionable suggestions for which apps to delete to free up space. \
                Focus on large, rarely-used apps. Be concise — one line per app suggestion.
                """),
            Message(role: .user, content: prompt)
        ])

        let config = RunConfig().tokensLimit(512).enableThinking(false)
        let output = try session.run(input: input, config: config) { _ in true }

        return output.text.original
    }

    static func buildAppSuggestionPrompt(for apps: [AppInfo]) -> String {
        var lines = ["Here are my installed apps:\n"]
        for app in apps.sorted(by: { $0.cleanupScore > $1.cleanupScore }) {
            let lastUsed: String
            if let days = app.daysSinceLastUsed {
                lastUsed = "\(days) days ago"
            } else {
                lastUsed = "unknown"
            }
            lines.append("- \(app.name): \(app.sizeFormatted), last used: \(lastUsed)")
        }
        lines.append("\nWhich apps should I consider deleting to free up space?")
        return lines.joined(separator: "\n")
    }

    enum MiraiError: Error {
        case notInitialized
        case modelNotLoaded
    }
}
```

**Step 3: Regenerate project, build**

Run: `xcodegen generate && xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED (SPM resolves and downloads uzu-swift).

Note: If SPM resolution fails, the Uzu API may have changed. Check https://github.com/trymirai/uzu-swift for the latest version and API. If types like `ChatModel`, `Input`, `Message`, `RunConfig` have different names, update accordingly.

**Step 4: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS.

**Step 5: Commit**

```bash
git add project.yml iPhoneCleaner/Services/MiraiService.swift iPhoneCleaner.xcodeproj/project.pbxproj
git commit -m "feat: integrate Mirai SDK (uzu-swift) and remove conditional compilation"
```

---

### Task 7: Add Demo App Data and Wire AppCleanupView

**Files:**
- Modify: `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`

**Step 1: Add demo apps to loadApps()**

Replace `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`:
```swift
import Foundation
import UIKit

@Observable
final class AppCleanupViewModel {
    var apps: [AppInfo] = []
    var isLoadingSuggestions = false
    var suggestionError: String?

    private let miraiService = MiraiService()

    func loadApps() {
        // Demo data — iOS doesn't allow listing installed apps
        apps = [
            AppInfo(
                id: "1", name: "Forgotten RPG",
                bundleId: "com.example.rpg",
                sizeBytes: 3_200_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -180, to: Date())
            ),
            AppInfo(
                id: "2", name: "Video Editor Pro",
                bundleId: "com.example.videoeditor",
                sizeBytes: 1_800_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -45, to: Date())
            ),
            AppInfo(
                id: "3", name: "Social Media X",
                bundleId: "com.example.social",
                sizeBytes: 450_000_000,
                lastUsedDate: Date()
            ),
            AppInfo(
                id: "4", name: "Old Navigation",
                bundleId: "com.example.nav",
                sizeBytes: 280_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -90, to: Date())
            ),
            AppInfo(
                id: "5", name: "Fitness Tracker",
                bundleId: "com.example.fitness",
                sizeBytes: 150_000_000,
                lastUsedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())
            ),
            AppInfo(
                id: "6", name: "Weather Widget",
                bundleId: "com.example.weather",
                sizeBytes: 35_000_000,
                lastUsedDate: Date()
            ),
        ]
    }

    func generateSuggestions() async {
        guard !apps.isEmpty else { return }
        isLoadingSuggestions = true
        suggestionError = nil
        defer { isLoadingSuggestions = false }

        do {
            try await miraiService.initialize(apiKey: MiraiConfig.apiKey)
            try await miraiService.loadModel()
            let suggestions = try await miraiService.generateAppSuggestions(for: apps)

            // Assign the full suggestion text to the top-scoring apps
            for i in 0..<apps.count {
                apps[i].aiSuggestion = suggestions
            }
        } catch {
            suggestionError = "Failed to generate suggestions: \(error.localizedDescription)"
            print("Mirai error: \(error)")
        }
    }
}

enum MiraiConfig {
    static var apiKey: String {
        ProcessInfo.processInfo.environment["MIRAI_API_KEY"] ?? ""
    }
}
```

**Step 2: Build and run**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add iPhoneCleaner/ViewModels/AppCleanupViewModel.swift
git commit -m "feat: add demo app data and error handling to AppCleanupViewModel"
```

---

### Task 8: Persist ScanResult to SwiftData

**Files:**
- Modify: `iPhoneCleaner/App/AppState.swift`

**Step 1: Add SwiftData persistence to AppState**

Add a method to save scan results and load the last one. Update `iPhoneCleaner/App/AppState.swift`:

Add `import SwiftData` at the top.

Add these methods to `AppState`:
```swift
    func saveScanResult(_ result: ScanResult, context: ModelContext) {
        context.insert(result)
        try? context.save()
        lastScanResult = result
    }

    func loadLastScanResult(context: ModelContext) {
        let descriptor = FetchDescriptor<ScanResult>(
            sortBy: [SortDescriptor(\.scanDate, order: .reverse)]
        )
        lastScanResult = try? context.fetch(descriptor).first
    }
```

**Step 2: Update HomeView to persist and load scan results**

In `iPhoneCleaner/Views/Home/HomeView.swift`, add `@Environment(\.modelContext) private var modelContext`.

Update the `.fullScreenCover` onComplete:
```swift
                ScanningView(scanEngine: appState.scanEngine, settings: appState.scanSettings) { result in
                    appState.saveScanResult(result, context: modelContext)
                    isScanning = false
                    appState.loadStorageInfo()
                }
```

Update `.onAppear`:
```swift
            .onAppear {
                appState.loadStorageInfo()
                appState.loadLastScanResult(context: modelContext)
            }
```

**Step 3: Build and run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add iPhoneCleaner/App/AppState.swift iPhoneCleaner/Views/Home/HomeView.swift
git commit -m "feat: persist ScanResult to SwiftData and load on app launch"
```

---

### Task 9: Simulator Testing and Bug Fixes

**Files:**
- Potentially any file depending on bugs found

**Step 1: Build and run on simulator**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

Launch the app on the simulator:
```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/iPhoneCleaner-*/Build/Products/Debug-iphonesimulator/iPhoneCleaner.app && xcrun simctl launch booted com.svetlana.iPhoneCleaner
```

**Step 2: Test the full flow**

1. App launches → Home with storage ring visible
2. Tap "Scan Photos" → permission prompt (grant access)
3. Scanning view shows progress → scan completes → results appear on Home
4. Tap a category card → ReviewView opens with swipe cards showing real photos
5. Swipe left/right → undo works → tap "Delete N" → confirmation → DeletionSuccessView
6. Navigate to Apps tab → demo apps visible
7. Navigate to Settings → adjust sliders → go back → scan again with new settings

**Step 3: Fix any crashes or issues found**

Document and fix issues as they appear. Common expected issues:
- Photo permission timing
- Empty categories (no duplicates in small library)
- Image loading failures

**Step 4: Run all tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests PASS.

**Step 5: Commit fixes**

```bash
git add -A
git commit -m "fix: address issues found during simulator testing"
```

---

### Task 10: Minimal Polish — App Icon Placeholder

**Files:**
- Modify: `project.yml` (if needed for asset catalog)

**Step 1: Generate a simple app icon**

Create a basic app icon using SF Symbols or a simple design. Add to the Xcode asset catalog.

For a minimal approach, set the app's accent color in the asset catalog and rely on the automatic icon tinting in iOS 18+. Or create a simple 1024x1024 PNG with a purple gradient background and a white broom/sparkle icon.

**Step 2: Build and verify**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED. App icon visible on simulator home screen.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add app icon placeholder"
```

---

## Summary

| Task | Description | Key Files |
|------|------------|-----------|
| 1 | Create AppState, inject at root | `AppState.swift`, `iPhoneCleanerApp.swift`, `ContentView.swift` |
| 2 | Wire Settings to AppState | `SettingsView.swift` |
| 3 | Wire HomeView to AppState | `HomeView.swift`, delete `HomeViewModel.swift` |
| 4 | Pass ScanSettings to scan engine | `ScanningView.swift`, `HomeView.swift` |
| 5 | Connect ReviewView → DeletionSuccessView | `ReviewView.swift` |
| 6 | Add Mirai SDK via SPM | `project.yml`, `MiraiService.swift` |
| 7 | Demo app data for App Cleanup | `AppCleanupViewModel.swift` |
| 8 | Persist ScanResult to SwiftData | `AppState.swift`, `HomeView.swift` |
| 9 | Simulator testing and bug fixes | Various |
| 10 | App icon placeholder | Asset catalog |
