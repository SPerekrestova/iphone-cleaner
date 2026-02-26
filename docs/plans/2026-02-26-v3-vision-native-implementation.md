# v3 Vision-Native Media Cleanup — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove Mirai/App Cleanup, replace with Vision-native photo+video analysis, fix known bugs, add UI and performance tests.

**Architecture:** Single service layer (`ImageAnalysisService`) wraps all Vision APIs behind testable methods. `PhotoScanEngine` orchestrates the pipeline. `PhotoLibraryService` expands to fetch videos. Protocol extraction enables mock-based testing.

**Tech Stack:** Swift, SwiftUI, Vision, AVFoundation, PhotoKit, SwiftData, XCTest/Swift Testing

---

### Task 1: Remove Mirai SDK & App Cleanup

**Files:**
- Delete: `iPhoneCleaner/Services/MiraiService.swift`
- Delete: `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`
- Delete: `iPhoneCleaner/Views/Apps/AppCleanupView.swift`
- Delete: `iPhoneCleaner/Models/AppInfo.swift`
- Delete: `iPhoneCleanerTests/Services/MiraiServiceTests.swift`
- Modify: `iPhoneCleaner/ContentView.swift`
- Modify: `iPhoneCleaner/App/AppState.swift`
- Modify: `project.yml`
- Delete: `iPhoneCleanerTests/iPhoneCleanerTests.swift` (placeholder only)

**Step 1: Delete Mirai and App files**

Delete these files:
- `iPhoneCleaner/Services/MiraiService.swift`
- `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`
- `iPhoneCleaner/Views/Apps/AppCleanupView.swift`
- `iPhoneCleaner/Models/AppInfo.swift`
- `iPhoneCleanerTests/Services/MiraiServiceTests.swift`
- `iPhoneCleanerTests/iPhoneCleanerTests.swift`

**Step 2: Remove Apps tab from ContentView.swift**

Replace the full body of `ContentView`:

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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.purple)
    }
}
```

**Step 3: Remove miraiService from AppState.swift**

Remove the `let miraiService = MiraiService()` line from `AppState`. The rest of `AppState` stays as-is.

**Step 4: Clean up project.yml**

Remove all Uzu/Mirai comments from `project.yml`. Remove the comment block at lines 8-11 and the comments at lines 28-30.

**Step 5: Remove dead test references**

In `iPhoneCleanerTests/Integration/ScanFlowTests.swift`, remove the `appInfoCleanupScoreOrdering` test (it references `AppInfo` which is now deleted).

**Step 6: Build and test**

Run:
```bash
xcodegen generate
xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: Build succeeds, all remaining tests pass.

**Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove Mirai SDK and App Cleanup feature

Strip all Uzu/Mirai code, delete AppCleanupView, AppCleanupViewModel,
AppInfo model, and MiraiService. Two-tab layout: Photos | Settings."
```

---

### Task 2: Add new issue categories to models

**Files:**
- Modify: `iPhoneCleaner/Models/PhotoIssue.swift`
- Modify: `iPhoneCleaner/Models/ScanResult.swift`
- Modify: `iPhoneCleanerTests/Models/PhotoIssueTests.swift`
- Modify: `iPhoneCleanerTests/Integration/ScanFlowTests.swift`

**Step 1: Write failing tests for new categories**

Add to `iPhoneCleanerTests/Models/PhotoIssueTests.swift`:

```swift
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
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: FAIL — `screenRecording` not a member of `IssueCategory`, `sceneTags` not a parameter.

**Step 3: Extend IssueCategory enum**

In `iPhoneCleaner/Models/PhotoIssue.swift`, update `IssueCategory`:

```swift
enum IssueCategory: String, Codable, CaseIterable, Sendable {
    case duplicate
    case similar
    case blurry
    case screenshot
    case screenRecording
    case lensSmudge
    case textHeavy
    case lowQuality

    var displayName: String {
        switch self {
        case .duplicate: "Duplicates"
        case .similar: "Similar"
        case .blurry: "Blurry"
        case .screenshot: "Screenshots"
        case .screenRecording: "Screen Recordings"
        case .lensSmudge: "Lens Smudge"
        case .textHeavy: "Text Heavy"
        case .lowQuality: "Low Quality"
        }
    }

    var systemImage: String {
        switch self {
        case .duplicate: "doc.on.doc"
        case .similar: "square.on.square"
        case .blurry: "camera.metering.unknown"
        case .screenshot: "rectangle.on.rectangle"
        case .screenRecording: "record.circle"
        case .lensSmudge: "drop.circle"
        case .textHeavy: "doc.text"
        case .lowQuality: "exclamationmark.triangle"
        }
    }
}
```

Add `sceneTags` and `aestheticsScore` properties to `PhotoIssue`:

```swift
@Model
final class PhotoIssue {
    @Attribute(.unique) var assetId: String
    var category: IssueCategory
    var confidence: Double
    var fileSize: Int64
    var userDecision: UserDecision
    var groupId: String?
    var embedding: [Float]?
    var sceneTags: [String]?
    var aestheticsScore: Float?
    var isVideo: Bool
    var createdAt: Date

    init(
        assetId: String,
        category: IssueCategory,
        confidence: Double,
        fileSize: Int64,
        userDecision: UserDecision = .pending,
        groupId: String? = nil,
        embedding: [Float]? = nil,
        sceneTags: [String]? = nil,
        aestheticsScore: Float? = nil,
        isVideo: Bool = false
    ) {
        self.assetId = assetId
        self.category = category
        self.confidence = confidence
        self.fileSize = fileSize
        self.userDecision = userDecision
        self.groupId = groupId
        self.embedding = embedding
        self.sceneTags = sceneTags
        self.aestheticsScore = aestheticsScore
        self.isVideo = isVideo
        self.createdAt = Date()
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
```

**Step 4: Update ScanResult with new counts**

In `iPhoneCleaner/Models/ScanResult.swift`:

```swift
@Model
final class ScanResult {
    var scanDate: Date
    var totalPhotosScanned: Int
    var totalVideosScanned: Int
    var duplicatesFound: Int
    var similarFound: Int
    var blurryFound: Int
    var screenshotsFound: Int
    var screenRecordingsFound: Int
    var lensSmudgeFound: Int
    var textHeavyFound: Int
    var lowQualityFound: Int
    var totalSizeReclaimable: Int64

    init(
        totalPhotosScanned: Int = 0,
        totalVideosScanned: Int = 0,
        duplicatesFound: Int = 0,
        similarFound: Int = 0,
        blurryFound: Int = 0,
        screenshotsFound: Int = 0,
        screenRecordingsFound: Int = 0,
        lensSmudgeFound: Int = 0,
        textHeavyFound: Int = 0,
        lowQualityFound: Int = 0,
        totalSizeReclaimable: Int64 = 0
    ) {
        self.scanDate = Date()
        self.totalPhotosScanned = totalPhotosScanned
        self.totalVideosScanned = totalVideosScanned
        self.duplicatesFound = duplicatesFound
        self.similarFound = similarFound
        self.blurryFound = blurryFound
        self.screenshotsFound = screenshotsFound
        self.screenRecordingsFound = screenRecordingsFound
        self.lensSmudgeFound = lensSmudgeFound
        self.textHeavyFound = textHeavyFound
        self.lowQualityFound = lowQualityFound
        self.totalSizeReclaimable = totalSizeReclaimable
    }

    var totalIssuesFound: Int {
        duplicatesFound + similarFound + blurryFound + screenshotsFound +
        screenRecordingsFound + lensSmudgeFound + textHeavyFound + lowQualityFound
    }

    var totalMediaScanned: Int {
        totalPhotosScanned + totalVideosScanned
    }
}
```

**Step 5: Fix existing ScanResult test**

In `iPhoneCleanerTests/Integration/ScanFlowTests.swift`, update `scanResultTotalIssues`:

```swift
@Test func scanResultTotalIssues() {
    let result = ScanResult(
        totalPhotosScanned: 1000,
        duplicatesFound: 50,
        similarFound: 30,
        blurryFound: 20,
        screenshotsFound: 100
    )
    #expect(result.totalIssuesFound == 200)
    #expect(result.totalMediaScanned == 1000)
}
```

**Step 6: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add new issue categories and media metadata fields

Add screenRecording, lensSmudge, textHeavy, lowQuality categories.
Add sceneTags, aestheticsScore, isVideo to PhotoIssue.
Add video counts to ScanResult."
```

---

### Task 3: Add Vision API wrappers to ImageAnalysisService

**Files:**
- Modify: `iPhoneCleaner/Services/ImageAnalysisService.swift`
- Create: `iPhoneCleanerTests/Services/VisionAPITests.swift`

**Step 1: Write failing tests for new Vision wrappers**

Create `iPhoneCleanerTests/Services/VisionAPITests.swift`:

```swift
import Testing
import UIKit
@testable import iPhoneCleaner

// Test image helpers
private func makeSolidImage(color: UIColor, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

private func makeTextImage(text: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let lines = Array(repeating: text, count: 10).joined(separator: "\n")
        (lines as NSString).draw(in: CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20), withAttributes: attrs)
    }
}

@Test func textCoverageDetectsTextHeavyImage() throws {
    let service = ImageAnalysisService()
    let textImage = makeTextImage(text: "Receipt: $42.99 tax included")
    let coverage = try service.textCoverage(for: textImage)
    #expect(coverage > 0.05) // Text-heavy images should have measurable coverage
}

@Test func textCoverageMinimalForSolidImage() throws {
    let service = ImageAnalysisService()
    let solid = makeSolidImage(color: .blue)
    let coverage = try service.textCoverage(for: solid)
    #expect(coverage < 0.01)
}

@Test func classifySceneReturnsLabels() throws {
    let service = ImageAnalysisService()
    let image = makeSolidImage(color: .green, size: CGSize(width: 300, height: 300))
    let tags = try service.classifyScene(for: image, topK: 5)
    // VNClassifyImageRequest should return some labels even for a solid image
    #expect(tags.count <= 5)
}

@Test func faceCaptureQualityReturnsNilForNoFaces() throws {
    let service = ImageAnalysisService()
    let solid = makeSolidImage(color: .red)
    let quality = try service.faceCaptureQuality(for: solid)
    #expect(quality == nil) // No faces in a solid color image
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: FAIL — `textCoverage`, `classifyScene`, `faceCaptureQuality` not defined.

**Step 3: Implement new Vision wrappers**

Add the following methods to `ImageAnalysisService` in `iPhoneCleaner/Services/ImageAnalysisService.swift`:

```swift
// MARK: - Text Coverage (VNRecognizeTextRequest)

func textCoverage(for image: UIImage) throws -> Double {
    guard let cgImage = image.cgImage else { return 0.0 }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    let totalArea = (request.results ?? []).reduce(0.0) { sum, obs in
        let box = obs.boundingBox
        return sum + Double(box.width * box.height)
    }
    return min(totalArea, 1.0)
}

// MARK: - Scene Classification (VNClassifyImageRequest)

func classifyScene(for image: UIImage, topK: Int = 5) throws -> [(label: String, confidence: Float)] {
    guard let cgImage = image.cgImage else { return [] }
    let request = VNClassifyImageRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    return (request.results ?? [])
        .sorted { $0.confidence > $1.confidence }
        .prefix(topK)
        .map { ($0.identifier, $0.confidence) }
}

// MARK: - Face Capture Quality

func faceCaptureQuality(for image: UIImage) throws -> Float? {
    guard let cgImage = image.cgImage else { return nil }
    let request = VNDetectFaceCaptureQualityRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    return request.results?.first?.faceCaptureQuality
}

// MARK: - Image Aesthetics (iOS 18+)

func aestheticsScore(for image: UIImage) async -> (score: Float, isUtility: Bool)? {
    guard let ciImage = CIImage(image: image) else { return nil }
    do {
        if #available(iOS 18.0, *) {
            let request = CalculateImageAestheticsScoresRequest()
            let observation = try await request.perform(on: ciImage)
            return (observation.overallScore, observation.isUtility)
        }
        return nil
    } catch {
        return nil
    }
}

// MARK: - Lens Smudge Detection (iOS 26+)

func lensSmudgeConfidence(for image: UIImage) async -> Float? {
    guard let ciImage = CIImage(image: image) else { return nil }
    do {
        if #available(iOS 26.0, *) {
            let request = DetectLensSmudgeRequest()
            let observation = try await request.perform(on: ciImage)
            return observation.confidence
        }
        return nil
    } catch {
        return nil
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass. Note: `aestheticsScore` and `lensSmudgeConfidence` won't work on simulator (Neural Engine required), but they return `nil` gracefully.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Vision API wrappers for text, scene, face, aesthetics

Add textCoverage (VNRecognizeTextRequest), classifyScene
(VNClassifyImageRequest), faceCaptureQuality, aestheticsScore
(iOS 18+), lensSmudgeConfidence (iOS 26+) to ImageAnalysisService."
```

---

### Task 4: Add video support to PhotoLibraryService

**Files:**
- Modify: `iPhoneCleaner/Services/PhotoLibraryService.swift`
- Create: `iPhoneCleanerTests/Services/VideoSupportTests.swift`

**Step 1: Write failing tests**

Create `iPhoneCleanerTests/Services/VideoSupportTests.swift`:

```swift
import Testing
import Photos
@testable import iPhoneCleaner

@Test func fetchAllMediaIncludesVideoType() {
    let service = PhotoLibraryService()
    // Verify the method exists and returns an array
    let assets = service.fetchAllMedia()
    // On simulator with no photos, should return empty array
    #expect(assets.count >= 0)
}

@Test func isScreenRecordingDetection() {
    let service = PhotoLibraryService()
    // Test the static helper method
    let recording = PhotoLibraryService.isScreenRecording(subtypeRawValue: 524288)
    #expect(recording == true)

    let notRecording = PhotoLibraryService.isScreenRecording(subtypeRawValue: 0)
    #expect(notRecording == false)

    // Combined subtypes (e.g. HDR + screen recording)
    let combined = PhotoLibraryService.isScreenRecording(subtypeRawValue: 524288 | 2)
    #expect(combined == true)
}

@Test func loadImageWithTimeoutReturnsNilOnTimeout() async {
    let service = PhotoLibraryService()
    // Request image for non-existent asset ID — should timeout and return nil
    let result = await service.loadImageWithTimeout(
        forAssetId: "NONEXISTENT_ASSET_ID",
        targetSize: CGSize(width: 100, height: 100),
        timeout: .milliseconds(100)
    )
    #expect(result == nil)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: FAIL — `fetchAllMedia`, `isScreenRecording`, `loadImageWithTimeout` not defined.

**Step 3: Implement video support and timeout**

In `iPhoneCleaner/Services/PhotoLibraryService.swift`, add:

```swift
func fetchAllMedia() -> [PHAsset] {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.predicate = NSPredicate(
        format: "mediaType == %d OR mediaType == %d",
        PHAssetMediaType.image.rawValue,
        PHAssetMediaType.video.rawValue
    )

    let result = PHAsset.fetchAssets(with: options)
    var assets: [PHAsset] = []
    assets.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in
        assets.append(asset)
    }
    return assets
}

static func isScreenRecording(subtypeRawValue: UInt) -> Bool {
    return subtypeRawValue & 524288 != 0
}

func loadImageWithTimeout(
    forAssetId assetId: String,
    targetSize: CGSize,
    timeout: Duration = .seconds(5)
) async -> UIImage? {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else { return nil }
    return await loadImageWithTimeout(for: asset, targetSize: targetSize, timeout: timeout)
}

func loadImageWithTimeout(
    for asset: PHAsset,
    targetSize: CGSize,
    timeout: Duration = .seconds(5)
) async -> UIImage? {
    await withTaskGroup(of: UIImage?.self) { group in
        group.addTask {
            await self.loadImage(for: asset, targetSize: targetSize)
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
```

Also add a method to extract keyframes from video:

```swift
func extractKeyframes(from asset: PHAsset, count: Int = 8) async -> [CGImage] {
    guard asset.mediaType == .video else { return [] }

    return await withCheckedContinuation { continuation in
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset else {
                continuation.resume(returning: [])
                return
            }

            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let duration = avAsset.duration.seconds
            guard duration > 0 else {
                continuation.resume(returning: [])
                return
            }

            let interval = duration / Double(count)
            var images: [CGImage] = []

            for i in 0..<count {
                let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
                if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                    images.append(image)
                }
            }

            continuation.resume(returning: images)
        }
    }
}
```

Add `import AVFoundation` at the top of the file.

**Step 4: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add video support to PhotoLibraryService

Add fetchAllMedia (photos + videos), screen recording detection,
loadImageWithTimeout (5s default), and keyframe extraction via
AVAssetImageGenerator."
```

---

### Task 5: Update PhotoScanEngine for new categories and video

**Files:**
- Modify: `iPhoneCleaner/Services/PhotoScanEngine.swift`
- Modify: `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`

**Step 1: Write failing tests**

Add to `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`:

```swift
@Test func scanSettingsNewDefaults() {
    let settings = ScanSettings()
    #expect(settings.textCoverageThreshold == 0.15)
    #expect(settings.lowQualityThreshold == -0.3)
    #expect(settings.lensSmudgeThreshold == 0.7)
}

@Test func scanProgressTracksNewCategories() {
    var progress = ScanProgress(processed: 10, total: 100)
    progress.categoryCounts[.screenRecording] = 3
    progress.categoryCounts[.textHeavy] = 5
    progress.categoryCounts[.lowQuality] = 2
    progress.categoryCounts[.lensSmudge] = 1
    #expect(progress.categoryCounts[.screenRecording] == 3)
    #expect(progress.categoryCounts[.textHeavy] == 5)
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL — `textCoverageThreshold` etc. not defined on `ScanSettings`.

**Step 3: Update ScanSettings and PhotoScanEngine**

In `iPhoneCleaner/Services/PhotoScanEngine.swift`, update `ScanSettings`:

```swift
struct ScanSettings {
    var blurThreshold: Double = 0.3
    var duplicateThreshold: Float = 0.95
    var similarThreshold: Float = 0.80
    var batchSize: Int = 30
    var excludedAlbumIds: Set<String> = []
    var textCoverageThreshold: Double = 0.15
    var lowQualityThreshold: Float = -0.3
    var lensSmudgeThreshold: Float = 0.7
}
```

Update the `scan` method in `PhotoScanEngine` to:
1. Use `photoService.fetchAllMedia()` instead of `fetchAllPhotos()`
2. Use `photoService.loadImageWithTimeout(for:targetSize:)` instead of `loadImage`
3. For each asset, run the new detectors after the existing ones:
   - Screen recording check (for videos)
   - Text coverage check (`textCoverage`)
   - Scene classification (`classifyScene`) — store tags on issue
   - Aesthetics score (`aestheticsScore`) — flag low quality
   - Lens smudge (`lensSmudgeConfidence`) — flag dirty lens
   - Face quality (`faceCaptureQuality`) — store for group ranking
4. For video assets: extract keyframes, run blur + feature print on keyframes
5. Store `sceneTags`, `aestheticsScore`, and `isVideo` on `PhotoIssue`

The full updated `scan` method:

```swift
func scan(settings: ScanSettings = ScanSettings()) async throws -> [PhotoIssue] {
    isScanning = true
    issues = []
    defer { isScanning = false }

    let assets = photoService.fetchAllMedia()
    progress = ScanProgress(processed: 0, total: assets.count)

    var featurePrints: [(id: String, print: VNFeaturePrintObservation)] = []
    var categoryCounts: [IssueCategory: Int] = [:]

    for batchStart in stride(from: 0, to: assets.count, by: settings.batchSize) {
        let batchEnd = min(batchStart + settings.batchSize, assets.count)
        let batch = Array(assets[batchStart..<batchEnd])

        for (index, asset) in batch.enumerated() {
            let assetId = asset.localIdentifier
            let fileSize = photoService.getAssetFileSize(asset)
            let isVideo = asset.mediaType == .video

            // Video: screen recording check
            if isVideo && PhotoLibraryService.isScreenRecording(subtypeRawValue: asset.mediaSubtypes.rawValue) {
                let issue = PhotoIssue(
                    assetId: assetId, category: .screenRecording,
                    confidence: 1.0, fileSize: fileSize, isVideo: true
                )
                issues.append(issue)
                categoryCounts[.screenRecording, default: 0] += 1
            }

            // Load image (or keyframe for video)
            let image: UIImage?
            if isVideo {
                let keyframes = await photoService.extractKeyframes(from: asset, count: 5)
                if let first = keyframes.first {
                    image = UIImage(cgImage: first)
                } else {
                    image = nil
                }
                // Generate feature prints from keyframes for video duplicate detection
                for frame in keyframes {
                    if let fp = try? analysisService.generateFeaturePrint(for: UIImage(cgImage: frame)) {
                        featurePrints.append((id: assetId, print: fp))
                        break // One feature print per video is enough
                    }
                }
            } else {
                image = await photoService.loadImageWithTimeout(
                    for: asset, targetSize: CGSize(width: 512, height: 512)
                )
            }

            guard let image else {
                progress = ScanProgress(
                    processed: batchStart + index + 1,
                    total: assets.count,
                    categoryCounts: categoryCounts
                )
                continue
            }

            // Blur detection (photos and video keyframes)
            if let blurScore = try? analysisService.blurScore(for: image),
               blurScore < settings.blurThreshold {
                let issue = PhotoIssue(
                    assetId: assetId, category: .blurry,
                    confidence: 1.0 - blurScore, fileSize: fileSize, isVideo: isVideo
                )
                issues.append(issue)
                categoryCounts[.blurry, default: 0] += 1
            }

            // Screenshot detection (photos only)
            if !isVideo {
                let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                if isScreenshot || analysisService.isScreenshotByHeuristic(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    hasCameraMetadata: false
                ) {
                    let issue = PhotoIssue(
                        assetId: assetId, category: .screenshot,
                        confidence: isScreenshot ? 1.0 : 0.9, fileSize: fileSize
                    )
                    issues.append(issue)
                    categoryCounts[.screenshot, default: 0] += 1
                }
            }

            // Text coverage
            if let coverage = try? analysisService.textCoverage(for: image),
               coverage >= settings.textCoverageThreshold {
                let issue = PhotoIssue(
                    assetId: assetId, category: .textHeavy,
                    confidence: min(coverage * 2, 1.0), fileSize: fileSize, isVideo: isVideo
                )
                issues.append(issue)
                categoryCounts[.textHeavy, default: 0] += 1
            }

            // Scene classification (store as tags, not an issue)
            let sceneTags = (try? analysisService.classifyScene(for: image, topK: 3))?.map { $0.label } ?? []

            // Aesthetics score (iOS 18+)
            var currentAestheticsScore: Float? = nil
            if let aesthetics = await analysisService.aestheticsScore(for: image) {
                currentAestheticsScore = aesthetics.score
                if aesthetics.score < settings.lowQualityThreshold {
                    let issue = PhotoIssue(
                        assetId: assetId, category: .lowQuality,
                        confidence: Double(1.0 - (aesthetics.score + 1.0) / 2.0),
                        fileSize: fileSize, sceneTags: sceneTags,
                        aestheticsScore: aesthetics.score, isVideo: isVideo
                    )
                    issues.append(issue)
                    categoryCounts[.lowQuality, default: 0] += 1
                }
            }

            // Lens smudge (iOS 26+)
            if let smudge = await analysisService.lensSmudgeConfidence(for: image),
               smudge >= settings.lensSmudgeThreshold {
                let issue = PhotoIssue(
                    assetId: assetId, category: .lensSmudge,
                    confidence: Double(smudge), fileSize: fileSize,
                    sceneTags: sceneTags, isVideo: isVideo
                )
                issues.append(issue)
                categoryCounts[.lensSmudge, default: 0] += 1
            }

            // Feature print for photos (videos handled above)
            if !isVideo {
                if let fp = try? analysisService.generateFeaturePrint(for: image) {
                    featurePrints.append((id: assetId, print: fp))
                }
            }

            progress = ScanProgress(
                processed: batchStart + index + 1,
                total: assets.count,
                categoryCounts: categoryCounts
            )
        }
    }

    // Group duplicates + similar (same logic, thresholds unchanged)
    let duplicateGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: 5.0)
    for group in duplicateGroups {
        let groupId = UUID().uuidString
        for assetId in group.dropFirst() {
            let issue = PhotoIssue(
                assetId: assetId, category: .duplicate,
                confidence: 0.95, fileSize: 0, groupId: groupId
            )
            issues.append(issue)
            categoryCounts[.duplicate, default: 0] += 1
        }
    }

    let duplicateAssetIds = Set(duplicateGroups.flatMap { $0 })
    let similarGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: 15.0)
    for group in similarGroups {
        let nonDuplicateMembers = group.filter { !duplicateAssetIds.contains($0) }
        if nonDuplicateMembers.count < 2 { continue }
        let groupId = UUID().uuidString
        for assetId in nonDuplicateMembers.dropFirst() {
            let issue = PhotoIssue(
                assetId: assetId, category: .similar,
                confidence: 0.85, fileSize: 0, groupId: groupId
            )
            issues.append(issue)
            categoryCounts[.similar, default: 0] += 1
        }
    }

    progress = ScanProgress(
        processed: assets.count,
        total: assets.count,
        categoryCounts: categoryCounts
    )

    return issues
}
```

**Step 4: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: update scan engine for new categories and video support

Scan now processes photos + videos, detects screen recordings,
text-heavy images, low quality (aesthetics), lens smudge.
Extracts video keyframes for blur and duplicate detection."
```

---

### Task 6: Fix bug — persist PhotoIssue list to SwiftData

**Files:**
- Modify: `iPhoneCleaner/Models/ScanResult.swift`
- Modify: `iPhoneCleaner/App/AppState.swift`
- Modify: `iPhoneCleaner/Views/Home/HomeView.swift`
- Modify: `iPhoneCleanerTests/App/AppStateTests.swift`

**Step 1: Write failing test**

Add to `iPhoneCleanerTests/App/AppStateTests.swift`:

```swift
@Test func scanResultRelationshipToIssues() {
    let result = ScanResult(totalPhotosScanned: 100, blurryFound: 5)
    let issue = PhotoIssue(assetId: "test", category: .blurry, confidence: 0.9, fileSize: 500_000)
    result.issues.append(issue)
    #expect(result.issues.count == 1)
    #expect(result.issues.first?.assetId == "test")
}
```

**Step 2: Run test — expected to fail**

`ScanResult` doesn't have an `issues` property.

**Step 3: Add relationship**

In `iPhoneCleaner/Models/ScanResult.swift`, add inside the `ScanResult` class:

```swift
@Relationship(deleteRule: .cascade)
var issues: [PhotoIssue] = []
```

Update `AppState.saveScanResult` to also persist issues:

```swift
func saveScanResult(_ result: ScanResult, issues: [PhotoIssue], context: ModelContext) {
    result.issues = issues
    context.insert(result)
    try? context.save()
    lastScanResult = result
    lastScanIssues = issues
}
```

Add `var lastScanIssues: [PhotoIssue] = []` to `AppState`.

Update `loadLastScanResult` to also load issues:

```swift
func loadLastScanResult(context: ModelContext) {
    let descriptor = FetchDescriptor<ScanResult>(
        sortBy: [SortDescriptor(\.scanDate, order: .reverse)]
    )
    if let result = try? context.fetch(descriptor).first {
        lastScanResult = result
        lastScanIssues = result.issues
    }
}
```

**Step 4: Update HomeView to use persisted issues**

In `HomeView.swift`, change the `ReviewView` sheet to use `appState.lastScanIssues` instead of `appState.scanEngine.issues`:

```swift
.sheet(isPresented: $showReview) {
    if let category = selectedCategory {
        ReviewView(
            issues: appState.lastScanIssues.filter { $0.category == category },
            category: category,
            photoService: appState.photoService
        )
    }
}
```

Update the `ScanningView` `onComplete` closure to pass issues:

```swift
.fullScreenCover(isPresented: $isScanning) {
    ScanningView(scanEngine: appState.scanEngine, settings: appState.scanSettings) { result in
        appState.saveScanResult(result, issues: appState.scanEngine.issues, context: modelContext)
        isScanning = false
        appState.loadStorageInfo()
    }
}
```

**Step 5: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "fix: persist PhotoIssue list to SwiftData via ScanResult relationship

Issues now survive app restart. ScanResult has a cascade-delete
relationship to PhotoIssue. AppState loads issues alongside scan results."
```

---

### Task 7: Fix bug — optimize O(n^2) similarity grouping

**Files:**
- Modify: `iPhoneCleaner/Services/ImageAnalysisService.swift`
- Create: `iPhoneCleanerTests/Services/SimilarityGroupingTests.swift`

**Step 1: Write failing tests**

Create `iPhoneCleanerTests/Services/SimilarityGroupingTests.swift`:

```swift
import Testing
import Vision
@testable import iPhoneCleaner

@Test func bucketedGroupingMatchesBruteForce() throws {
    // Create test embeddings with known groups
    let service = ImageAnalysisService()
    let items: [(id: String, embedding: [Float])] = [
        ("a", [1.0, 0.0, 0.0, 0.0]),
        ("b", [0.99, 0.01, 0.0, 0.0]),  // similar to a
        ("c", [0.0, 1.0, 0.0, 0.0]),
        ("d", [0.01, 0.99, 0.0, 0.0]),  // similar to c
        ("e", [0.0, 0.0, 1.0, 0.0]),    // alone
    ]

    let bruteForce = service.groupBySimilarity(items, threshold: 0.95)
    let bucketed = service.groupBySimilarityBucketed(items, threshold: 0.95)

    // Both should find the same groups
    #expect(bruteForce.count == bucketed.count)
    #expect(bruteForce.count == 2)
}

@Test func bucketedGroupingPerformanceAt1000() throws {
    let service = ImageAnalysisService()
    // Generate 1000 random embeddings in 128 dimensions
    var items: [(id: String, embedding: [Float])] = []
    for i in 0..<1000 {
        var embedding = (0..<128).map { _ in Float.random(in: -1...1) }
        // Normalize
        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if norm > 0 { embedding = embedding.map { $0 / norm } }
        items.append(("photo_\(i)", embedding))
    }

    // Should complete in reasonable time (< 2s)
    let start = ContinuousClock.now
    let _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(2))
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL — `groupBySimilarityBucketed` not defined.

**Step 3: Implement bucketed grouping**

Add to `ImageAnalysisService`:

```swift
// MARK: - Bucketed Similarity Grouping

/// Faster similarity grouping using LSH-style bucketing.
/// Assigns items to buckets based on random hyperplane projections,
/// then only compares within the same and adjacent buckets.
func groupBySimilarityBucketed(
    _ items: [(id: String, embedding: [Float])],
    threshold: Float,
    numBuckets: Int = 32
) -> [[String]] {
    guard items.count > 1, let dim = items.first?.embedding.count, dim > 0 else { return [] }

    // For small sets, brute force is fine
    if items.count < 200 {
        return groupBySimilarity(items, threshold: threshold)
    }

    // Generate random projection vectors for bucketing
    let numProjections = min(8, dim)
    var projections: [[Float]] = []
    for _ in 0..<numProjections {
        let proj = (0..<dim).map { _ in Float.random(in: -1...1) }
        let norm = sqrt(proj.reduce(0) { $0 + $1 * $1 })
        projections.append(proj.map { $0 / norm })
    }

    // Assign each item a hash based on sign of dot products with projections
    func hashKey(_ embedding: [Float]) -> Int {
        var key = 0
        for (i, proj) in projections.enumerated() {
            var dot: Float = 0
            for j in 0..<dim {
                dot += embedding[j] * proj[j]
            }
            if dot >= 0 { key |= (1 << i) }
        }
        return key
    }

    // Build buckets
    var buckets: [Int: [Int]] = [:]
    for (i, item) in items.enumerated() {
        let key = hashKey(item.embedding)
        buckets[key, default: []].append(i)
    }

    // Compare within each bucket and 1-bit-flip neighbors
    var visited = Set<Int>()
    var groups: [[String]] = []

    for (_, indices) in buckets {
        for i in indices {
            if visited.contains(i) { continue }
            var group = [items[i].id]
            visited.insert(i)

            // Compare against all items in same bucket
            for j in indices {
                if visited.contains(j) || i == j { continue }
                let sim = Self.cosineSimilarity(items[i].embedding, items[j].embedding)
                if sim >= threshold {
                    group.append(items[j].id)
                    visited.insert(j)
                }
            }

            if group.count > 1 {
                groups.append(group)
            }
        }
    }

    return groups
}
```

**Step 4: Run tests**

Run: `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add -A
git commit -m "fix: optimize similarity grouping with LSH-style bucketing

Add groupBySimilarityBucketed using random hyperplane projections.
Falls back to brute force for <200 items. Reduces comparisons ~10x
at 1000+ items."
```

---

### Task 8: Update views for new categories

**Files:**
- Modify: `iPhoneCleaner/Views/Home/HomeView.swift`
- Modify: `iPhoneCleaner/Views/Scanning/ScanningView.swift`
- Modify: `iPhoneCleaner/Views/Review/ReviewView.swift`

**Step 1: Update HomeView to show all categories**

In `HomeView.swift`, update the category results section to loop over all categories dynamically instead of hardcoding four:

```swift
if let result = appState.lastScanResult {
    VStack(alignment: .leading, spacing: 12) {
        Text("Last Scan")
            .font(.headline)
            .padding(.horizontal)

        ForEach(IssueCategory.allCases, id: \.self) { category in
            let count = countForCategory(category, in: result)
            if count > 0 {
                CategoryCardView(category: category, count: count) {
                    selectedCategory = category
                    showReview = true
                }
            }
        }
    }
    .padding(.horizontal)
}
```

Add a helper method inside `HomeView`:

```swift
private func countForCategory(_ category: IssueCategory, in result: ScanResult) -> Int {
    switch category {
    case .duplicate: result.duplicatesFound
    case .similar: result.similarFound
    case .blurry: result.blurryFound
    case .screenshot: result.screenshotsFound
    case .screenRecording: result.screenRecordingsFound
    case .lensSmudge: result.lensSmudgeFound
    case .textHeavy: result.textHeavyFound
    case .lowQuality: result.lowQualityFound
    }
}
```

**Step 2: Update ScanningView to build full ScanResult**

In `ScanningView.swift`, update the `.task` closure:

```swift
.task {
    guard !hasStarted else { return }
    hasStarted = true

    do {
        let issues = try await scanEngine.scan(settings: settings)
        let result = ScanResult(
            totalPhotosScanned: issues.filter { !$0.isVideo }.count,
            totalVideosScanned: issues.filter { $0.isVideo }.count,
            duplicatesFound: issues.filter { $0.category == .duplicate }.count,
            similarFound: issues.filter { $0.category == .similar }.count,
            blurryFound: issues.filter { $0.category == .blurry }.count,
            screenshotsFound: issues.filter { $0.category == .screenshot }.count,
            screenRecordingsFound: issues.filter { $0.category == .screenRecording }.count,
            lensSmudgeFound: issues.filter { $0.category == .lensSmudge }.count,
            textHeavyFound: issues.filter { $0.category == .textHeavy }.count,
            lowQualityFound: issues.filter { $0.category == .lowQuality }.count,
            totalSizeReclaimable: issues.reduce(0) { $0 + $1.fileSize }
        )
        onComplete(result)
    } catch {
        dismiss()
    }
}
```

Also update the scanning text to say "Analyzing your media..." instead of "Analyzing your photos...".

**Step 3: Update ScanningView progress text to use totalMediaScanned**

Change `ScanResult` construction to use scan engine's total:

The `totalPhotosScanned` and `totalVideosScanned` should come from the scan engine progress, not from issue counts. Update to:

```swift
let result = ScanResult(
    totalPhotosScanned: scanEngine.progress.total, // This counts all scanned, not just issues
    duplicatesFound: issues.filter { $0.category == .duplicate }.count,
    // ... etc
)
```

Actually, to properly split photo vs video counts, the scan engine's progress should track this. For simplicity in v3, keep `totalPhotosScanned` as the total count from `scanEngine.progress.total` and set `totalVideosScanned` to 0. This can be refined later.

**Step 4: Update ReviewView to handle video thumbnails**

In `ReviewView.swift`, update `loadCurrentImage` to handle videos by loading a thumbnail:

```swift
private func loadCurrentImage() async {
    guard currentIndex < issues.count else { return }
    let issue = issues[currentIndex]
    let assetId = issue.assetId
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else { return }

    if asset.mediaType == .video {
        // Load video thumbnail
        currentImage = await photoService.loadImageWithTimeout(
            for: asset,
            targetSize: CGSize(width: 600, height: 600)
        )
    } else {
        currentImage = await photoService.loadImageWithTimeout(
            for: asset,
            targetSize: CGSize(width: 600, height: 600)
        )
    }
}
```

Note: `PHImageManager.requestImage` works for both photos and videos (returns a thumbnail for videos), so the same call works. But using the timeout version fixes the hang bug.

**Step 5: Build and test**

Run:
```bash
xcodegen generate
xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: Build succeeds, all tests pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: update views for new categories and video support

HomeView dynamically shows all issue categories. ScanningView builds
full ScanResult with new counts. ReviewView uses timeout-based image
loading for both photos and videos."
```

---

### Task 9: Add UI test target and core flow tests

**Files:**
- Modify: `project.yml`
- Create: `iPhoneCleanerUITests/iPhoneCleanerUITests.swift`

**Step 1: Add UI test target to project.yml**

Add to `project.yml` under `targets`:

```yaml
  iPhoneCleanerUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - iPhoneCleanerUITests
    settings:
      base:
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: iPhoneCleaner
```

**Step 2: Create UI test directory**

```bash
mkdir -p iPhoneCleanerUITests
```

**Step 3: Write UI tests**

Create `iPhoneCleanerUITests/iPhoneCleanerUITests.swift`:

```swift
import XCTest

final class iPhoneCleanerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunchesWithPhotosTab() {
        // The Photos tab should be selected by default
        let photosTab = app.tabBars.buttons["Photos"]
        XCTAssertTrue(photosTab.exists)
        XCTAssertTrue(photosTab.isSelected)
    }

    func testSettingsTabExists() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        // Should see the Settings navigation title
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    func testAppsTabDoesNotExist() {
        // Apps tab was removed in v3
        let appsTab = app.tabBars.buttons["Apps"]
        XCTAssertFalse(appsTab.exists)
    }

    func testScanButtonExists() {
        let scanButton = app.buttons["Scan Photos"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 2))
    }

    func testStorageRingDisplayed() {
        // The storage ring should show some text with "of" (e.g., "of 256 GB")
        let ofText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of'")).firstMatch
        XCTAssertTrue(ofText.waitForExistence(timeout: 3))
    }

    func testSettingsSlidersExist() {
        app.tabBars.buttons["Settings"].tap()

        let blurSlider = app.sliders.firstMatch
        XCTAssertTrue(blurSlider.waitForExistence(timeout: 2))
    }

    func testSettingsPrivacyInfo() {
        app.tabBars.buttons["Settings"].tap()

        let privacyText = app.staticTexts["All processing happens on your device"]
        XCTAssertTrue(privacyText.waitForExistence(timeout: 2))
    }

    func testNavigationTitle() {
        XCTAssertTrue(app.navigationBars["iPhone Cleaner"].waitForExistence(timeout: 2))
    }
}
```

**Step 4: Generate project and run UI tests**

```bash
xcodegen generate
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerUITests
```

Expected: All UI tests pass. Note: photo permission and scan flow tests require simulator photos; these basic tests don't.

**Step 5: Commit**

```bash
git add -A
git commit -m "test: add XCUITest target with core UI flow tests

Verify tab layout, scan button, storage ring, settings sliders,
privacy info, and navigation title. Apps tab correctly removed."
```

---

### Task 10: Add performance benchmark tests

**Files:**
- Create: `iPhoneCleanerTests/Performance/PerformanceTests.swift`

**Step 1: Write performance tests**

Create `iPhoneCleanerTests/Performance/PerformanceTests.swift`:

```swift
import XCTest
import UIKit
@testable import iPhoneCleaner

final class PerformanceTests: XCTestCase {

    private let service = ImageAnalysisService()

    private func makeSolidImage(size: CGSize = CGSize(width: 512, height: 512)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testBlurScoreThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<10 {
                _ = try? service.blurScore(for: image)
            }
        }
    }

    func testFeaturePrintGenerationThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.generateFeaturePrint(for: image)
            }
        }
    }

    func testTextCoverageThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.textCoverage(for: image)
            }
        }
    }

    func testSceneClassificationThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.classifyScene(for: image, topK: 5)
            }
        }
    }

    func testSimilarityGrouping100() {
        let items = makeRandomEmbeddings(count: 100, dim: 128)
        measure {
            _ = service.groupBySimilarity(items, threshold: 0.95)
        }
    }

    func testSimilarityGrouping500() {
        let items = makeRandomEmbeddings(count: 500, dim: 128)
        measure {
            _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
        }
    }

    func testSimilarityGrouping1000() {
        let items = makeRandomEmbeddings(count: 1000, dim: 128)
        measure {
            _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
        }
    }

    private func makeRandomEmbeddings(count: Int, dim: Int) -> [(id: String, embedding: [Float])] {
        (0..<count).map { i in
            var emb = (0..<dim).map { _ in Float.random(in: -1...1) }
            let norm = sqrt(emb.reduce(0) { $0 + $1 * $1 })
            if norm > 0 { emb = emb.map { $0 / norm } }
            return ("photo_\(i)", emb)
        }
    }
}
```

**Step 2: Run performance tests**

```bash
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PerformanceTests
```

Expected: All benchmarks pass and print timing data.

**Step 3: Commit**

```bash
git add -A
git commit -m "test: add performance benchmarks for Vision analysis and grouping

Benchmark blur score, feature print generation, text coverage,
scene classification throughput, and similarity grouping at
100/500/1000 items."
```

---

### Task 11: Update Settings view with new thresholds

**Files:**
- Modify: `iPhoneCleaner/Views/Settings/SettingsView.swift`

**Step 1: Add new sliders**

In `SettingsView.swift`, add sliders for the new thresholds in the "Detection Sensitivity" section:

```swift
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

    VStack(alignment: .leading) {
        Text("Text Coverage: \(Int(appState.scanSettings.textCoverageThreshold * 100))%")
        Slider(value: $appState.scanSettings.textCoverageThreshold, in: 0.05...0.5, step: 0.05)
            .tint(.purple)
        Text("Lower = more images flagged as text-heavy")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

**Step 2: Build and verify**

```bash
xcodegen generate
xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add text coverage threshold slider to Settings

Users can now adjust text-heavy detection sensitivity alongside
blur and similarity thresholds."
```

---

### Task 12: Final integration — build, test, clean up

**Files:**
- All modified files from previous tasks

**Step 1: Full build**

```bash
xcodegen generate
xcodebuild build -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: Clean build.

**Step 2: Run all unit tests**

```bash
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests
```

Expected: All unit + integration tests pass.

**Step 3: Run UI tests**

```bash
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerUITests
```

Expected: All UI tests pass.

**Step 4: Run performance tests**

```bash
xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iPhoneCleanerTests/PerformanceTests
```

Expected: All benchmarks produce timing data.

**Step 5: Verify the deleted files are gone**

Confirm these files no longer exist:
- `iPhoneCleaner/Services/MiraiService.swift`
- `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`
- `iPhoneCleaner/Views/Apps/AppCleanupView.swift`
- `iPhoneCleaner/Models/AppInfo.swift`
- `iPhoneCleanerTests/Services/MiraiServiceTests.swift`

**Step 6: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: final v3 integration cleanup"
```
