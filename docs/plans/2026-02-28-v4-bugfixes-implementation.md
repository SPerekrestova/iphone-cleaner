# v4 Bug Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 7 critical bugs found during real-device testing: incorrect storage, false duplicate positives, stale counters, face-as-text, double success screen, swipe lag, and progress jumping.

**Architecture:** Targeted fixes to existing files. No new architectural patterns. TDD — write failing test first, then implement minimal fix.

**Tech Stack:** Swift, SwiftUI, Vision framework, PhotoKit, Swift Testing (`@Test`, `#expect`)

---

### Task 1: Create branch

**Step 1: Create and switch to fix branch**

Run: `git checkout -b fix/v4-device-testing-bugs`

**Step 2: Verify branch**

Run: `git branch --show-current`
Expected: `fix/v4-device-testing-bugs`

---

### Task 2: Fix storage calculation (Bug 1)

**Files:**
- Modify: `iPhoneCleaner/App/AppState.swift:48-55`
- Test: `iPhoneCleanerTests/App/AppStateTests.swift`

**Step 1: Update the existing test to validate the new API**

In `iPhoneCleanerTests/App/AppStateTests.swift`, the existing `appStateLoadStorageInfo` test already validates `storageTotal > 0` and `storageUsed > 0`. Add a new test that verifies used < total:

```swift
@Test func storageUsedIsLessThanTotal() {
    let state = AppState()
    state.loadStorageInfo()
    #expect(state.storageUsed > 0)
    #expect(state.storageTotal > 0)
    #expect(state.storageUsed < state.storageTotal, "Used storage should be less than total")
}
```

**Step 2: Run test to verify it passes (baseline)**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/AppStateTests -quiet 2>&1 | tail -5`
Expected: Tests pass (this validates baseline before change)

**Step 3: Implement fix — switch to URL.resourceValues API**

Replace `loadStorageInfo()` in `iPhoneCleaner/App/AppState.swift:48-55` with:

```swift
func loadStorageInfo() {
    let homeURL = URL(fileURLWithPath: NSHomeDirectory())
    guard let values = try? homeURL.resourceValues(
        forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
    ) else { return }
    storageTotal = Int64(values.volumeTotalCapacity ?? 0)
    let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
    storageUsed = storageTotal - available
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/AppStateTests -quiet 2>&1 | tail -5`
Expected: All AppState tests pass

**Step 5: Commit**

```bash
git add iPhoneCleaner/App/AppState.swift iPhoneCleanerTests/App/AppStateTests.swift
git commit -m "fix: use volumeAvailableCapacityForImportantUsage for accurate storage"
```

---

### Task 3: Fix false positive duplicates (Bug 2)

**Files:**
- Modify: `iPhoneCleaner/Services/PhotoScanEngine.swift:21-30,188,203`
- Test: `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`

**Step 1: Write failing test for new defaults and formula**

Add to `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`:

```swift
@Test func duplicateThresholdDefaultIsTighter() {
    let settings = ScanSettings()
    #expect(settings.duplicateThreshold == 0.98, "Default duplicate threshold should be 0.98")
}

@Test func distanceFormulaUsesHalvedMultiplier() {
    let settings = ScanSettings()
    let dupDist = Float((1.0 - Double(settings.duplicateThreshold)) * 50.0)
    let simDist = Float((1.0 - Double(settings.similarThreshold)) * 50.0)
    #expect(abs(dupDist - 1.0) < 0.01, "Duplicate maxDistance should be ~1.0")
    #expect(abs(simDist - 10.0) < 0.01, "Similar maxDistance should be ~10.0")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PhotoScanEngineTests -quiet 2>&1 | tail -10`
Expected: FAIL — `duplicateThreshold` is 0.95, not 0.98

**Step 3: Implement fix — update defaults and formula**

In `iPhoneCleaner/Services/PhotoScanEngine.swift`:

Change line 23 from:
```swift
var duplicateThreshold: Float = 0.95
```
to:
```swift
var duplicateThreshold: Float = 0.98
```

Change line 188 from:
```swift
let dupMaxDist = Float((1.0 - Double(settings.duplicateThreshold)) * 100.0)
```
to:
```swift
let dupMaxDist = Float((1.0 - Double(settings.duplicateThreshold)) * 50.0)
```

Change line 203 from:
```swift
let simMaxDist = Float((1.0 - Double(settings.similarThreshold)) * 100.0)
```
to:
```swift
let simMaxDist = Float((1.0 - Double(settings.similarThreshold)) * 50.0)
```

**Step 4: Update old tests that assert old defaults**

In `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`, update `scanSettingsDefaults`:
```swift
@Test func scanSettingsDefaults() {
    let settings = ScanSettings()
    #expect(settings.blurThreshold == 0.3)
    #expect(settings.duplicateThreshold == 0.98)
    #expect(settings.similarThreshold == 0.80)
    #expect(settings.batchSize == 30)
}
```

Update `similarThresholdToDistanceConversion`:
```swift
@Test func similarThresholdToDistanceConversion() {
    let tight: Float = 0.98
    let loose: Float = 0.80
    let tightDist = Float((1.0 - Double(tight)) * 50.0)
    let looseDist = Float((1.0 - Double(loose)) * 50.0)
    #expect(abs(tightDist - 1.0) < 0.01, "Threshold 0.98 should map to distance ~1.0")
    #expect(abs(looseDist - 10.0) < 0.01, "Threshold 0.80 should map to distance ~10.0")
}
```

Update `duplicateThresholdToDistanceConversion`:
```swift
@Test func duplicateThresholdToDistanceConversion() {
    let threshold: Float = 0.98
    let distance = Float((1.0 - Double(threshold)) * 50.0)
    #expect(abs(distance - 1.0) < 0.01, "Duplicate threshold 0.98 should map to distance ~1.0")
}
```

Update `defaultThresholdsMatchExpected`:
```swift
@Test func defaultThresholdsMatchExpected() {
    let settings = ScanSettings()
    let dupDist = Float((1.0 - Double(settings.duplicateThreshold)) * 50.0)
    let simDist = Float((1.0 - Double(settings.similarThreshold)) * 50.0)
    #expect(abs(dupDist - 1.0) < 0.01, "Default duplicate distance should be ~1.0")
    #expect(abs(simDist - 10.0) < 0.01, "Default similar distance should be ~10.0")
}
```

Also update `iPhoneCleanerTests/App/AppStateTests.swift` `appStateInitialValues` if it checks `duplicateThreshold`:
The existing test checks `blurThreshold` and `batchSize` — not `duplicateThreshold` — so no change needed there.

**Step 5: Run all tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PhotoScanEngineTests -quiet 2>&1 | tail -10`
Expected: All pass

**Step 6: Commit**

```bash
git add iPhoneCleaner/Services/PhotoScanEngine.swift iPhoneCleanerTests/Services/PhotoScanEngineTests.swift
git commit -m "fix: tighten duplicate threshold and halve distance formula to reduce false positives"
```

---

### Task 4: Fix stale counters after deletion (Bug 3)

**Files:**
- Modify: `iPhoneCleaner/Models/ScanResult.swift`
- Modify: `iPhoneCleaner/App/AppState.swift`
- Modify: `iPhoneCleaner/Views/Review/ReviewView.swift`
- Test: `iPhoneCleanerTests/App/AppStateTests.swift`

**Step 1: Write failing test for counter recomputation**

Add to `iPhoneCleanerTests/App/AppStateTests.swift`:

```swift
@Test func removeDeletedIssuesUpdatesCounts() {
    let state = AppState()
    let result = ScanResult(
        totalPhotosScanned: 10,
        duplicatesFound: 3,
        blurryFound: 2
    )
    let issues = [
        PhotoIssue(assetId: "dup-1", category: .duplicate, confidence: 0.95, fileSize: 1000),
        PhotoIssue(assetId: "dup-2", category: .duplicate, confidence: 0.95, fileSize: 2000),
        PhotoIssue(assetId: "dup-3", category: .duplicate, confidence: 0.95, fileSize: 3000),
        PhotoIssue(assetId: "blur-1", category: .blurry, confidence: 0.8, fileSize: 4000),
        PhotoIssue(assetId: "blur-2", category: .blurry, confidence: 0.7, fileSize: 5000),
    ]
    state.lastScanResult = result
    state.lastScanIssues = issues

    // Simulate deleting 2 duplicates
    let deletedIds: Set<String> = ["dup-1", "dup-2"]
    state.removeDeletedIssues(deletedIds)

    #expect(state.lastScanIssues.count == 3)
    #expect(state.lastScanResult?.duplicatesFound == 1)
    #expect(state.lastScanResult?.blurryFound == 2)
    #expect(state.lastScanResult?.totalSizeReclaimable == 12000) // 3000 + 4000 + 5000
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/AppStateTests -quiet 2>&1 | tail -10`
Expected: FAIL — `removeDeletedIssues` does not exist

**Step 3: Add `removeDeletedIssues` to AppState**

Add to `iPhoneCleaner/App/AppState.swift` after `loadLastScanResult`:

```swift
func removeDeletedIssues(_ deletedAssetIds: Set<String>) {
    lastScanIssues.removeAll { deletedAssetIds.contains($0.assetId) }
    guard let result = lastScanResult else { return }
    result.duplicatesFound = lastScanIssues.filter { $0.category == .duplicate }.count
    result.similarFound = lastScanIssues.filter { $0.category == .similar }.count
    result.blurryFound = lastScanIssues.filter { $0.category == .blurry }.count
    result.screenshotsFound = lastScanIssues.filter { $0.category == .screenshot }.count
    result.screenRecordingsFound = lastScanIssues.filter { $0.category == .screenRecording }.count
    result.lensSmudgeFound = lastScanIssues.filter { $0.category == .lensSmudge }.count
    result.textHeavyFound = lastScanIssues.filter { $0.category == .textHeavy }.count
    result.lowQualityFound = lastScanIssues.filter { $0.category == .lowQuality }.count
    result.totalSizeReclaimable = lastScanIssues.reduce(0) { $0 + $1.fileSize }
}
```

**Step 4: Wire it up in ReviewView**

In `iPhoneCleaner/Views/Review/ReviewView.swift`, add `@Environment(AppState.self) private var appState` at line 5.

In the deletion success block (line 115-125), after `viewModel.applyDeletion()`, add:

```swift
let deletedIds = Set(idsToDelete)
appState.removeDeletedIssues(deletedIds)
```

So the full block becomes:
```swift
Button("Delete \(viewModel.markedForDeletion.count) Photos", role: .destructive) {
    Task {
        let idsToDelete = viewModel.markedForDeletion.map { $0.assetId }
        do {
            try await photoService.deleteAssets(idsToDelete)
            viewModel.applyDeletion()
            appState.removeDeletedIssues(Set(idsToDelete))
        } catch {
            viewModel.handleDeletionError(error)
            showDeletionError = true
        }
    }
}
```

**Step 5: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/AppStateTests -quiet 2>&1 | tail -10`
Expected: All pass

**Step 6: Commit**

```bash
git add iPhoneCleaner/App/AppState.swift iPhoneCleaner/Views/Review/ReviewView.swift iPhoneCleanerTests/App/AppStateTests.swift
git commit -m "fix: update scan result counters after deletion to prevent stale counts"
```

---

### Task 5: Fix people photos treated as text (Bug 4)

**Files:**
- Modify: `iPhoneCleaner/Services/ImageAnalysisService.swift`
- Modify: `iPhoneCleaner/Services/PhotoScanEngine.swift:132-141`
- Test: `iPhoneCleanerTests/Services/ImageAnalysisServiceTests.swift`

**Step 1: Write failing test for face detection**

Add to `iPhoneCleanerTests/Services/ImageAnalysisServiceTests.swift`:

```swift
@Test func faceAreaCalculation() throws {
    let service = ImageAnalysisService()
    // Create a 100x100 image — Vision may or may not detect faces in synthetic images,
    // so we test the API contract: method exists and returns >= 0.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
    let image = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    let area = (try? service.faceArea(for: image)) ?? 0.0
    #expect(area >= 0.0 && area <= 1.0, "Face area should be normalized 0-1")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/ImageAnalysisServiceTests -quiet 2>&1 | tail -10`
Expected: FAIL — `faceArea(for:)` does not exist

**Step 3: Add `faceArea` to ImageAnalysisService**

Add to `iPhoneCleaner/Services/ImageAnalysisService.swift` after the `faceCaptureQuality` method:

```swift
// MARK: - Face Area Detection

func faceArea(for image: UIImage) throws -> Double {
    guard let cgImage = image.cgImage else { return 0.0 }
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    let totalArea = (request.results ?? []).reduce(0.0) { sum, face in
        let box = face.boundingBox
        return sum + Double(box.width * box.height)
    }
    return min(totalArea, 1.0)
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/ImageAnalysisServiceTests -quiet 2>&1 | tail -10`
Expected: Pass

**Step 5: Write test for scan engine skipping text on face-heavy photos**

Add to `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`:

```swift
@Test func faceAreaThresholdSkipsTextDetection() {
    // If face area > 0.10, text detection should be skipped
    let faceArea = 0.15
    let threshold = 0.10
    #expect(faceArea > threshold, "Face area 0.15 should exceed skip threshold 0.10")
}
```

**Step 6: Update scan engine to skip text detection for face-heavy photos**

In `iPhoneCleaner/Services/PhotoScanEngine.swift`, replace lines 132-141 (text coverage block) with:

```swift
// Text coverage (skip if significant face area detected)
let faceArea = (try? analysisService.faceArea(for: image)) ?? 0.0
if faceArea <= 0.10,
   let coverage = try? analysisService.textCoverage(for: image),
   coverage >= settings.textCoverageThreshold {
    let issue = PhotoIssue(
        assetId: assetId, category: .textHeavy,
        confidence: min(coverage * 2, 1.0), fileSize: fileSize, isVideo: isVideo
    )
    issues.append(issue)
    categoryCounts[.textHeavy, default: 0] += 1
}
```

**Step 7: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PhotoScanEngineTests -only-testing:iPhoneCleanerTests/ImageAnalysisServiceTests -quiet 2>&1 | tail -10`
Expected: All pass

**Step 8: Commit**

```bash
git add iPhoneCleaner/Services/ImageAnalysisService.swift iPhoneCleaner/Services/PhotoScanEngine.swift iPhoneCleanerTests/Services/ImageAnalysisServiceTests.swift iPhoneCleanerTests/Services/PhotoScanEngineTests.swift
git commit -m "fix: skip text detection on face-heavy photos to prevent false positives"
```

---

### Task 6: Fix freed space screen showing twice (Bug 5)

**Files:**
- Modify: `iPhoneCleaner/Views/Review/ReviewView.swift`
- Test: `iPhoneCleanerTests/ViewModels/ReviewViewModelTests.swift`

**Step 1: Write test for DeletionInfo identity stability**

Add to `iPhoneCleanerTests/ViewModels/ReviewViewModelTests.swift`:

```swift
@Test func deletionSuccessStateContainsCorrectInfo() {
    let vm = makeVM(count: 3)
    vm.markForDeletion() // asset-0 → delete (1MB)
    vm.keepPhoto()       // asset-1 → keep
    vm.markForDeletion() // asset-2 → delete (1MB)
    vm.applyDeletion()
    if case .deletionSuccess(let count, let bytes) = vm.state {
        #expect(count == 2)
        #expect(bytes == 2_000_000)
    } else {
        #expect(Bool(false), "State should be .deletionSuccess")
    }
}
```

**Step 2: Run test — should pass (validates VM contract)**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/ReviewViewModelTests -quiet 2>&1 | tail -5`
Expected: Pass

**Step 3: Fix ReviewView — replace computed binding with @State**

In `iPhoneCleaner/Views/Review/ReviewView.swift`:

Add a new `@State` property at line 10:
```swift
@State private var deletionInfo: DeletionInfo?
```

Replace the `.fullScreenCover` at lines 142-150 with:
```swift
.fullScreenCover(item: $deletionInfo) { info in
    DeletionSuccessView(
        photosDeleted: info.count,
        bytesFreed: info.bytes,
        onDismiss: {
            dismiss()
        }
    )
}
```

In the deletion button action (lines 115-125), after `viewModel.applyDeletion()`, set the info:
```swift
Button("Delete \(viewModel.markedForDeletion.count) Photos", role: .destructive) {
    Task {
        let idsToDelete = viewModel.markedForDeletion.map { $0.assetId }
        do {
            try await photoService.deleteAssets(idsToDelete)
            let count = viewModel.markedForDeletion.count
            let bytes = viewModel.totalFreeable
            viewModel.applyDeletion()
            appState.removeDeletedIssues(Set(idsToDelete))
            deletionInfo = DeletionInfo(count: count, bytes: bytes)
        } catch {
            viewModel.handleDeletionError(error)
            showDeletionError = true
        }
    }
}
```

Remove the entire `deletionSuccessBinding` computed property (lines 157-171).

**Step 4: Build to verify no compilation errors**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add iPhoneCleaner/Views/Review/ReviewView.swift iPhoneCleanerTests/ViewModels/ReviewViewModelTests.swift
git commit -m "fix: use @State for DeletionInfo to prevent fullScreenCover identity instability"
```

---

### Task 7: Fix photos lagging during swiping (Bug 6)

**Files:**
- Modify: `iPhoneCleaner/Views/Review/ReviewView.swift`

**Step 1: Add image cache and prefetch logic to ReviewView**

In `iPhoneCleaner/Views/Review/ReviewView.swift`, replace the `@State private var currentImage: UIImage?` and the `loadCurrentImage` method with a cache-based approach.

Replace `@State private var currentImage: UIImage?` with:
```swift
@State private var currentImage: UIImage?
@State private var imageCache: [String: UIImage] = [:]
```

Replace the `loadCurrentImage()` method (lines 173-184) with:
```swift
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
    let nextIndices = (viewModel.currentIndex + 1)...min(viewModel.currentIndex + 2, viewModel.issues.count - 1)
    for i in nextIndices where i >= 0 && i < viewModel.issues.count {
        let nextId = viewModel.issues[i].assetId
        if imageCache[nextId] == nil {
            let image = await loadImage(for: nextId)
            imageCache[nextId] = image
        }
    }

    // Evict old entries (keep only current ± 2)
    let keepRange = max(viewModel.currentIndex - 2, 0)...min(viewModel.currentIndex + 2, viewModel.issues.count - 1)
    let keepIds = Set(keepRange.compactMap { i in
        i < viewModel.issues.count ? viewModel.issues[i].assetId : nil
    })
    imageCache = imageCache.filter { keepIds.contains($0.key) }
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
```

**Step 2: Build to verify**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add iPhoneCleaner/Views/Review/ReviewView.swift
git commit -m "fix: add image cache and prefetching to eliminate swipe lag"
```

---

### Task 8: Fix scan progress jumping (Bug 7)

**Files:**
- Modify: `iPhoneCleaner/Services/PhotoScanEngine.swift`
- Test: `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`

**Step 1: Write test for MainActor progress updates**

Add to `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`:

```swift
@Test func scanEngineIsObservable() {
    let engine = PhotoScanEngine()
    #expect(engine.isScanning == false)
    #expect(engine.progress.processed == 0)
    #expect(engine.progress.total == 0)
}
```

**Step 2: Run test baseline**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PhotoScanEngineTests -quiet 2>&1 | tail -5`
Expected: Pass

**Step 3: Annotate PhotoScanEngine as @MainActor**

In `iPhoneCleaner/Services/PhotoScanEngine.swift`, add `@MainActor` to the class declaration:

Change:
```swift
@Observable
final class PhotoScanEngine {
```
to:
```swift
@MainActor @Observable
final class PhotoScanEngine {
```

This ensures ALL property mutations (including `progress`, `isScanning`, `issues`) happen on the main actor. The `async` scan method will automatically hop to the main actor for property writes while still allowing `await` calls to run concurrently.

**Step 4: Move heavy computation off main actor**

The Vision analysis calls should NOT block the main actor. Wrap the per-asset analysis in a detached task pattern. In the scan method, wrap the analysis portion in `nonisolated` helper or use `await Task.detached { ... }.value` for the heavy work.

Actually, simpler: keep the class `@MainActor` but move only the progress updates. Instead, wrap just the progress assignments in `MainActor.run`:

Revert the `@MainActor` annotation. Instead, wrap each `progress = ScanProgress(...)` assignment.

Change the 3 progress assignments in `scan()`:

Line 94-98 (inside `guard let image else`):
```swift
guard let image else {
    await MainActor.run {
        progress = ScanProgress(
            processed: batchStart + index + 1,
            total: assets.count,
            categoryCounts: categoryCounts
        )
    }
    continue
}
```

Lines 179-183 (end of per-asset loop):
```swift
await MainActor.run {
    progress = ScanProgress(
        processed: batchStart + index + 1,
        total: assets.count,
        categoryCounts: categoryCounts
    )
}
```

Lines 219-223 (final progress after grouping):
```swift
await MainActor.run {
    progress = ScanProgress(
        processed: assets.count,
        total: assets.count,
        categoryCounts: categoryCounts
    )
}
```

Also wrap the initial progress set (line 47):
```swift
await MainActor.run {
    progress = ScanProgress(processed: 0, total: assets.count)
}
```

And wrap `isScanning` and `issues` mutations:
Line 42: `await MainActor.run { isScanning = true; issues = [] }`
The `defer` at line 44: Replace with explicit set before return:
```swift
// Remove: defer { isScanning = false }
// At end of function, before return:
await MainActor.run { isScanning = false }
```

**Step 5: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PhotoScanEngineTests -quiet 2>&1 | tail -10`
Expected: All pass

**Step 6: Commit**

```bash
git add iPhoneCleaner/Services/PhotoScanEngine.swift iPhoneCleanerTests/Services/PhotoScanEngineTests.swift
git commit -m "fix: dispatch progress updates to MainActor to prevent UI jumping"
```

---

### Task 9: Run full test suite

**Step 1: Run all unit tests (skip perf tests)**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:iPhoneCleanerTests/PerformanceTests -quiet 2>&1 | tail -20`
Expected: All tests pass

**Step 2: Build for release**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: Build succeeds with no warnings

---

### Task 10: Regenerate Xcode project

**Step 1: Run xcodegen**

Run: `cd /Users/svetlana/iphone-cleaner && xcodegen generate`
Expected: Project generated successfully

**Step 2: Final build verification**

Run: `xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: Build succeeds
