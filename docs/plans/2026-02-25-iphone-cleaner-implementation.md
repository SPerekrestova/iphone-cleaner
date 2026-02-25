# iPhone Cleaner Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a free iOS app that cleans up photos (duplicates, similar, blurry, screenshots) via swipe cards and suggests apps to delete, using on-device ML.

**Architecture:** SwiftUI MVVM app with 4 layers — UI (SwiftUI views), ViewModels (state management), Services (scanning engine, ML coordinator), Data (PhotoKit, SwiftData cache). Image analysis via Apple Vision/CoreML. Text AI via Mirai SDK.

**Tech Stack:** Swift, SwiftUI, SwiftData, PhotoKit, Vision framework, CoreML, Mirai SDK (`uzu-swift`), Xcode 16+, iOS 17+

**Note on Mirai:** Mirai's current SDK only supports text/message inputs (no image input). All image analysis uses Apple Vision/CoreML. Mirai handles LLM text tasks (app cleanup suggestions). When Mirai adds vision model support, image tasks can be migrated.

---

### Task 1: Xcode Project Setup

**Files:**
- Create: `iPhoneCleaner.xcodeproj` (via Xcode)
- Create: `iPhoneCleaner/iPhoneCleanerApp.swift`
- Create: `iPhoneCleaner/ContentView.swift`
- Create: `iPhoneCleaner/Info.plist`

**Step 1: Create Xcode project**

Open Xcode → File → New → Project → iOS App:
- Product Name: `iPhoneCleaner`
- Organization Identifier: your reverse domain (e.g. `com.yourname`)
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Testing System: Swift Testing
- Uncheck "Include Tests" (we'll add test targets manually for better control)

**Step 2: Configure project settings**

In project settings:
- Deployment Target: iOS 17.0
- Supported Destinations: iPhone, iPad
- Device Orientation: Portrait only

**Step 3: Add Info.plist privacy keys**

Add to `Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>iPhone Cleaner needs access to your photo library to find duplicates, blurry photos, and screenshots for cleanup.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>iPhone Cleaner needs write access to move selected photos to Recently Deleted.</string>
```

**Step 4: Add Mirai SDK via SPM**

In Xcode: File → Add Package Dependencies
- URL: `https://github.com/trymirai/uzu-swift.git`
- Dependency Rule: Up to Next Major Version

**Step 5: Create folder structure**

Create these groups/folders in Xcode:
```
iPhoneCleaner/
├── App/
│   └── iPhoneCleanerApp.swift
├── Models/
├── Views/
│   ├── Home/
│   ├── Scanning/
│   ├── Review/
│   ├── Apps/
│   └── Settings/
├── ViewModels/
├── Services/
└── Utilities/
```

**Step 6: Build and run**

Run: Cmd+B to build, Cmd+R to run on simulator.
Expected: Blank app launches successfully.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: initialize Xcode project with SwiftUI, SwiftData, Mirai SDK"
```

---

### Task 2: Data Models (SwiftData)

**Files:**
- Create: `iPhoneCleaner/Models/PhotoIssue.swift`
- Create: `iPhoneCleaner/Models/ScanResult.swift`
- Create: `iPhoneCleaner/Models/AppInfo.swift`
- Create: `iPhoneCleanerTests/Models/PhotoIssueTests.swift`

**Step 1: Write tests for PhotoIssue model**

Create `iPhoneCleanerTests/Models/PhotoIssueTests.swift`:
```swift
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

@Test func photoIssueFileSizeFormatted() {
    let small = PhotoIssue(assetId: "a", category: .blurry, confidence: 0.9, fileSize: 500_000)
    #expect(small.fileSizeFormatted.contains("KB") || small.fileSizeFormatted.contains("kB"))

    let large = PhotoIssue(assetId: "b", category: .blurry, confidence: 0.9, fileSize: 2_500_000)
    #expect(large.fileSizeFormatted.contains("MB"))
}
```

**Step 2: Run tests to verify they fail**

Run: Cmd+U or `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: FAIL — `PhotoIssue` not defined.

**Step 3: Implement PhotoIssue model**

Create `iPhoneCleaner/Models/PhotoIssue.swift`:
```swift
import Foundation
import SwiftData

enum IssueCategory: String, Codable, CaseIterable {
    case duplicate
    case similar
    case blurry
    case screenshot

    var displayName: String {
        switch self {
        case .duplicate: "Duplicates"
        case .similar: "Similar"
        case .blurry: "Blurry"
        case .screenshot: "Screenshots"
        }
    }

    var systemImage: String {
        switch self {
        case .duplicate: "doc.on.doc"
        case .similar: "square.on.square"
        case .blurry: "camera.metering.unknown"
        case .screenshot: "rectangle.on.rectangle"
        }
    }
}

enum UserDecision: String, Codable {
    case pending
    case keep
    case delete
}

@Model
final class PhotoIssue {
    @Attribute(.unique) var assetId: String
    var category: IssueCategory
    var confidence: Double
    var fileSize: Int64
    var userDecision: UserDecision
    var groupId: String?
    var embedding: [Float]?
    var createdAt: Date

    init(
        assetId: String,
        category: IssueCategory,
        confidence: Double,
        fileSize: Int64,
        userDecision: UserDecision = .pending,
        groupId: String? = nil,
        embedding: [Float]? = nil
    ) {
        self.assetId = assetId
        self.category = category
        self.confidence = confidence
        self.fileSize = fileSize
        self.userDecision = userDecision
        self.groupId = groupId
        self.embedding = embedding
        self.createdAt = Date()
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
```

**Step 4: Implement ScanResult model**

Create `iPhoneCleaner/Models/ScanResult.swift`:
```swift
import Foundation
import SwiftData

@Model
final class ScanResult {
    var scanDate: Date
    var totalPhotosScanned: Int
    var duplicatesFound: Int
    var similarFound: Int
    var blurryFound: Int
    var screenshotsFound: Int
    var totalSizeReclaimable: Int64

    init(
        totalPhotosScanned: Int = 0,
        duplicatesFound: Int = 0,
        similarFound: Int = 0,
        blurryFound: Int = 0,
        screenshotsFound: Int = 0,
        totalSizeReclaimable: Int64 = 0
    ) {
        self.scanDate = Date()
        self.totalPhotosScanned = totalPhotosScanned
        self.duplicatesFound = duplicatesFound
        self.similarFound = similarFound
        self.blurryFound = blurryFound
        self.screenshotsFound = screenshotsFound
        self.totalSizeReclaimable = totalSizeReclaimable
    }

    var totalIssuesFound: Int {
        duplicatesFound + similarFound + blurryFound + screenshotsFound
    }
}
```

**Step 5: Implement AppInfo model**

Create `iPhoneCleaner/Models/AppInfo.swift`:
```swift
import Foundation

struct AppInfo: Identifiable {
    let id: String
    let name: String
    let bundleId: String
    let sizeBytes: Int64
    let lastUsedDate: Date?
    var aiSuggestion: String?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var daysSinceLastUsed: Int? {
        guard let lastUsed = lastUsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day
    }

    var cleanupScore: Double {
        let sizeScore = Double(sizeBytes) / 1_000_000_000.0
        let usageScore: Double = if let days = daysSinceLastUsed {
            min(Double(days) / 90.0, 1.0)
        } else {
            0.5
        }
        return (sizeScore * 0.4) + (usageScore * 0.6)
    }
}
```

**Step 6: Register models with SwiftData container**

Update `iPhoneCleaner/App/iPhoneCleanerApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }
}
```

**Step 7: Run tests to verify they pass**

Run: Cmd+U
Expected: All 3 tests PASS.

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add SwiftData models for PhotoIssue, ScanResult, AppInfo"
```

---

### Task 3: Photo Library Service

**Files:**
- Create: `iPhoneCleaner/Services/PhotoLibraryService.swift`
- Create: `iPhoneCleanerTests/Services/PhotoLibraryServiceTests.swift`

**Step 1: Write tests for PhotoLibraryService**

Create `iPhoneCleanerTests/Services/PhotoLibraryServiceTests.swift`:
```swift
import Testing
import Photos
@testable import iPhoneCleaner

@Test func photoLibraryServiceAuthStatus() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    // On simulator without granting, status is .notDetermined
    #expect(status == .notDetermined || status == .authorized || status == .denied || status == .limited)
}
```

Note: PhotoKit tests are limited in unit test context. We verify the service compiles and the interface is correct. Real testing happens on-device.

**Step 2: Implement PhotoLibraryService**

Create `iPhoneCleaner/Services/PhotoLibraryService.swift`:
```swift
import Photos
import UIKit

final class PhotoLibraryService {
    enum AuthError: Error {
        case denied
        case restricted
    }

    func requestAuthorization() async throws -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return status
        case .denied:
            throw AuthError.denied
        case .restricted:
            throw AuthError.restricted
        default:
            throw AuthError.denied
        }
    }

    func fetchAllPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func loadImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    func deleteAssets(_ assetIds: [String]) async throws {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds,
            options: nil
        )
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }

    func getAssetFileSize(_ asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let size = resource.value(forKey: "fileSize") as? Int64 else {
            return 0
        }
        return size
    }
}
```

**Step 3: Run tests**

Run: Cmd+U
Expected: PASS.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add PhotoLibraryService for photo access, loading, and deletion"
```

---

### Task 4: Image Analysis Service (Vision Framework)

**Files:**
- Create: `iPhoneCleaner/Services/ImageAnalysisService.swift`
- Create: `iPhoneCleanerTests/Services/ImageAnalysisServiceTests.swift`

**Step 1: Write tests for blur detection and similarity**

Create `iPhoneCleanerTests/Services/ImageAnalysisServiceTests.swift`:
```swift
import Testing
import UIKit
import CoreGraphics
@testable import iPhoneCleaner

@Test func cosineSimilarityIdenticalVectors() {
    let a: [Float] = [1.0, 0.0, 0.0, 1.0]
    let b: [Float] = [1.0, 0.0, 0.0, 1.0]
    let similarity = ImageAnalysisService.cosineSimilarity(a, b)
    #expect(abs(similarity - 1.0) < 0.001)
}

@Test func cosineSimilarityOrthogonalVectors() {
    let a: [Float] = [1.0, 0.0]
    let b: [Float] = [0.0, 1.0]
    let similarity = ImageAnalysisService.cosineSimilarity(a, b)
    #expect(abs(similarity) < 0.001)
}

@Test func cosineSimilarityEmptyVectors() {
    let similarity = ImageAnalysisService.cosineSimilarity([], [])
    #expect(similarity == 0.0)
}

@Test func blurScoreReturnsValueInRange() async throws {
    // Create a simple solid color test image
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
    let image = renderer.image { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    let service = ImageAnalysisService()
    let score = try service.blurScore(for: image)
    #expect(score >= 0.0 && score <= 1.0)
}

@Test func screenshotDetectionByMetadata() {
    let service = ImageAnalysisService()
    // A screenshot typically has no camera make/model in EXIF
    let isScreenshot = service.isScreenshotByHeuristic(
        pixelWidth: 1170,
        pixelHeight: 2532,
        hasCameraMetadata: false
    )
    #expect(isScreenshot == true)

    let isNotScreenshot = service.isScreenshotByHeuristic(
        pixelWidth: 4032,
        pixelHeight: 3024,
        hasCameraMetadata: true
    )
    #expect(isNotScreenshot == false)
}

@Test func groupDuplicatesByThreshold() {
    let service = ImageAnalysisService()
    let embeddings: [(String, [Float])] = [
        ("photo1", [1.0, 0.0, 0.0]),
        ("photo2", [0.99, 0.01, 0.0]),  // very similar to photo1
        ("photo3", [0.0, 1.0, 0.0]),     // different
        ("photo4", [0.01, 0.99, 0.0]),   // very similar to photo3
    ]
    let groups = service.groupBySimilarity(embeddings, threshold: 0.95)
    #expect(groups.count == 2)
}
```

**Step 2: Run tests to verify they fail**

Run: Cmd+U
Expected: FAIL — `ImageAnalysisService` not defined.

**Step 3: Implement ImageAnalysisService**

Create `iPhoneCleaner/Services/ImageAnalysisService.swift`:
```swift
import UIKit
import Vision
import Accelerate
import CoreImage

final class ImageAnalysisService {

    // MARK: - Blur Detection

    func blurScore(for image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }

        let ciImage = CIImage(cgImage: cgImage)
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // Use Laplacian variance as blur metric
        let laplacianKernel: [Float] = [
            0,  1, 0,
            1, -4, 1,
            0,  1, 0
        ]

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(grayscale, from: grayscale.extent) else {
            return 0.0
        }

        guard let pixelData = outputCGImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return 0.0
        }

        let width = outputCGImage.width
        let height = outputCGImage.height
        let bytesPerPixel = outputCGImage.bitsPerPixel / 8

        var pixels = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * outputCGImage.bytesPerRow) + (x * bytesPerPixel)
                pixels[y * width + x] = Float(data[offset])
            }
        }

        // Apply Laplacian convolution
        var variance: Float = 0
        var count = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var laplacian: Float = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let px = pixels[(y + ky) * width + (x + kx)]
                        let k = laplacianKernel[(ky + 1) * 3 + (kx + 1)]
                        laplacian += px * k
                    }
                }
                variance += laplacian * laplacian
                count += 1
            }
        }

        let meanVariance = count > 0 ? Double(variance) / Double(count) : 0
        // Normalize: high variance = sharp, low = blurry
        // Typical range: 0-5000+. Map to 0-1 where 1 = perfectly sharp
        let sharpnessScore = min(meanVariance / 2000.0, 1.0)
        return sharpnessScore
    }

    // Returns true if score < threshold (image is blurry)
    func isBlurry(_ image: UIImage, threshold: Double = 0.3) throws -> Bool {
        let score = try blurScore(for: image)
        return score < threshold
    }

    // MARK: - Screenshot Detection

    /// Known iPhone screen resolutions (width x height, portrait)
    private static let iPhoneResolutions: Set<String> = [
        "1170x2532", "1179x2556", "1290x2796", // iPhone 14/15/16 Pro etc.
        "1125x2436", "828x1792", "1242x2688",   // iPhone X/XR/XS Max
        "750x1334", "1080x1920", "640x1136",     // iPhone 6/7/8, SE
        "1284x2778",                              // iPhone 12/13 Pro Max
    ]

    func isScreenshotByHeuristic(pixelWidth: Int, pixelHeight: Int, hasCameraMetadata: Bool) -> Bool {
        if hasCameraMetadata { return false }
        let key = "\(min(pixelWidth, pixelHeight))x\(max(pixelWidth, pixelHeight))"
        return Self.iPhoneResolutions.contains(key)
    }

    // MARK: - Image Embeddings (Vision Feature Print)

    func generateFeaturePrint(for image: UIImage) throws -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return request.results?.first
    }

    func featurePrintDistance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try a.computeDistance(&distance, to: b)
        return distance
    }

    // MARK: - Cosine Similarity (for custom embeddings)

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0.0 }
        return dotProduct / denominator
    }

    // MARK: - Grouping

    func groupBySimilarity(_ items: [(id: String, embedding: [Float])], threshold: Float) -> [[String]] {
        var visited = Set<Int>()
        var groups: [[String]] = []

        for i in 0..<items.count {
            if visited.contains(i) { continue }
            var group = [items[i].id]
            visited.insert(i)

            for j in (i + 1)..<items.count {
                if visited.contains(j) { continue }
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

        return groups
    }

    func groupByFeaturePrint(_ prints: [(id: String, print: VNFeaturePrintObservation)], maxDistance: Float) -> [[String]] {
        var visited = Set<Int>()
        var groups: [[String]] = []

        for i in 0..<prints.count {
            if visited.contains(i) { continue }
            var group = [prints[i].id]
            visited.insert(i)

            for j in (i + 1)..<prints.count {
                if visited.contains(j) { continue }
                do {
                    let dist = try featurePrintDistance(prints[i].print, prints[j].print)
                    if dist <= maxDistance {
                        group.append(prints[j].id)
                        visited.insert(j)
                    }
                } catch {
                    continue
                }
            }

            if group.count > 1 {
                groups.append(group)
            }
        }

        return groups
    }
}
```

**Step 4: Run tests to verify they pass**

Run: Cmd+U
Expected: All 6 tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ImageAnalysisService with blur detection, screenshot heuristic, and similarity grouping"
```

---

### Task 5: Photo Scan Engine (Orchestrator)

**Files:**
- Create: `iPhoneCleaner/Services/PhotoScanEngine.swift`
- Create: `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`

**Step 1: Write tests for scan progress tracking**

Create `iPhoneCleanerTests/Services/PhotoScanEngineTests.swift`:
```swift
import Testing
@testable import iPhoneCleaner

@Test func scanProgressCalculation() {
    let progress = ScanProgress(processed: 50, total: 200)
    #expect(progress.fraction == 0.25)
    #expect(progress.percentFormatted == "25%")
}

@Test func scanProgressZeroTotal() {
    let progress = ScanProgress(processed: 0, total: 0)
    #expect(progress.fraction == 0.0)
}

@Test func scanSettingsDefaults() {
    let settings = ScanSettings()
    #expect(settings.blurThreshold == 0.3)
    #expect(settings.duplicateThreshold == 0.95)
    #expect(settings.similarThreshold == 0.80)
    #expect(settings.batchSize == 30)
}
```

**Step 2: Run tests to verify they fail**

Run: Cmd+U
Expected: FAIL.

**Step 3: Implement PhotoScanEngine**

Create `iPhoneCleaner/Services/PhotoScanEngine.swift`:
```swift
import Foundation
import Photos
import UIKit
import Vision

struct ScanProgress: Sendable {
    let processed: Int
    let total: Int
    var categoryCounts: [IssueCategory: Int] = [:]

    var fraction: Double {
        guard total > 0 else { return 0.0 }
        return Double(processed) / Double(total)
    }

    var percentFormatted: String {
        "\(Int(fraction * 100))%"
    }
}

struct ScanSettings {
    var blurThreshold: Double = 0.3
    var duplicateThreshold: Float = 0.95
    var similarThreshold: Float = 0.80
    var batchSize: Int = 30
    var excludedAlbumIds: Set<String> = []
}

@Observable
final class PhotoScanEngine {
    private let photoService = PhotoLibraryService()
    private let analysisService = ImageAnalysisService()

    var isScanning = false
    var progress = ScanProgress(processed: 0, total: 0)
    var issues: [PhotoIssue] = []

    func scan(settings: ScanSettings = ScanSettings()) async throws -> [PhotoIssue] {
        isScanning = true
        issues = []
        defer { isScanning = false }

        let assets = photoService.fetchAllPhotos()
        progress = ScanProgress(processed: 0, total: assets.count)

        var featurePrints: [(id: String, print: VNFeaturePrintObservation)] = []
        var categoryCounts: [IssueCategory: Int] = [:]

        // Process in batches
        for batchStart in stride(from: 0, to: assets.count, by: settings.batchSize) {
            let batchEnd = min(batchStart + settings.batchSize, assets.count)
            let batch = Array(assets[batchStart..<batchEnd])

            for asset in batch {
                guard let image = await photoService.loadImage(
                    for: asset,
                    targetSize: CGSize(width: 512, height: 512)
                ) else { continue }

                let assetId = asset.localIdentifier
                let fileSize = photoService.getAssetFileSize(asset)

                // 1. Blur detection
                if let blurScore = try? analysisService.blurScore(for: image),
                   blurScore < settings.blurThreshold {
                    let issue = PhotoIssue(
                        assetId: assetId,
                        category: .blurry,
                        confidence: 1.0 - blurScore,
                        fileSize: fileSize
                    )
                    issues.append(issue)
                    categoryCounts[.blurry, default: 0] += 1
                }

                // 2. Screenshot detection
                let hasCameraMake = asset.value(forKey: "cameraMake") != nil
                if analysisService.isScreenshotByHeuristic(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    hasCameraMetadata: hasCameraMake
                ) {
                    let issue = PhotoIssue(
                        assetId: assetId,
                        category: .screenshot,
                        confidence: 0.9,
                        fileSize: fileSize
                    )
                    issues.append(issue)
                    categoryCounts[.screenshot, default: 0] += 1
                }

                // 3. Generate feature print for similarity detection
                if let fp = try? analysisService.generateFeaturePrint(for: image) {
                    featurePrints.append((id: assetId, print: fp))
                }

                progress = ScanProgress(
                    processed: batchStart + batch.firstIndex(where: { $0.localIdentifier == assetId })! + 1,
                    total: assets.count,
                    categoryCounts: categoryCounts
                )
            }
        }

        // 4. Find duplicates (distance <= 5.0 in VNFeaturePrint space)
        let duplicateGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: 5.0)
        for group in duplicateGroups {
            let groupId = UUID().uuidString
            for assetId in group.dropFirst() {
                let issue = PhotoIssue(
                    assetId: assetId,
                    category: .duplicate,
                    confidence: 0.95,
                    fileSize: 0, // Will be populated from asset
                    groupId: groupId
                )
                issues.append(issue)
                categoryCounts[.duplicate, default: 0] += 1
            }
        }

        // 5. Find similar (distance 5.0 - 15.0)
        let similarGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: 15.0)
        for group in similarGroups {
            let isDuplicateGroup = duplicateGroups.contains { dupGroup in
                Set(dupGroup).isSuperset(of: Set(group))
            }
            if isDuplicateGroup { continue }

            let groupId = UUID().uuidString
            for assetId in group.dropFirst() {
                // Skip if already marked as duplicate
                if issues.contains(where: { $0.assetId == assetId && $0.category == .duplicate }) {
                    continue
                }
                let issue = PhotoIssue(
                    assetId: assetId,
                    category: .similar,
                    confidence: 0.85,
                    fileSize: 0,
                    groupId: groupId
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

    func deleteMarkedPhotos() async throws -> Int64 {
        let toDelete = issues.filter { $0.userDecision == .delete }
        let assetIds = toDelete.map { $0.assetId }
        let freedBytes = toDelete.reduce(Int64(0)) { $0 + $1.fileSize }

        try await photoService.deleteAssets(assetIds)
        issues.removeAll { $0.userDecision == .delete }

        return freedBytes
    }
}
```

**Step 4: Run tests to verify they pass**

Run: Cmd+U
Expected: All 3 new tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add PhotoScanEngine orchestrating batch photo analysis with progress tracking"
```

---

### Task 6: Mirai LLM Service (App Suggestions)

**Files:**
- Create: `iPhoneCleaner/Services/MiraiService.swift`
- Create: `iPhoneCleanerTests/Services/MiraiServiceTests.swift`

**Step 1: Write tests**

Create `iPhoneCleanerTests/Services/MiraiServiceTests.swift`:
```swift
import Testing
@testable import iPhoneCleaner

@Test func appSuggestionPromptGeneration() {
    let apps = [
        AppInfo(
            id: "1",
            name: "Old Game",
            bundleId: "com.example.game",
            sizeBytes: 2_000_000_000,
            lastUsedDate: Calendar.current.date(byAdding: .day, value: -120, to: Date())
        ),
        AppInfo(
            id: "2",
            name: "Camera App",
            bundleId: "com.example.camera",
            sizeBytes: 50_000_000,
            lastUsedDate: Date()
        )
    ]
    let prompt = MiraiService.buildAppSuggestionPrompt(for: apps)
    #expect(prompt.contains("Old Game"))
    #expect(prompt.contains("2.0 GB") || prompt.contains("2 GB"))
    #expect(prompt.contains("Camera App"))
}
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: FAIL.

**Step 3: Implement MiraiService**

Create `iPhoneCleaner/Services/MiraiService.swift`:
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

**Step 4: Run tests to verify they pass**

Run: Cmd+U
Expected: PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add MiraiService for LLM-powered app cleanup suggestions"
```

---

### Task 7: Home Dashboard View

**Files:**
- Create: `iPhoneCleaner/Views/Home/HomeView.swift`
- Create: `iPhoneCleaner/Views/Home/StorageRingView.swift`
- Create: `iPhoneCleaner/Views/Home/CategoryCardView.swift`
- Create: `iPhoneCleaner/ViewModels/HomeViewModel.swift`

**Step 1: Implement HomeViewModel**

Create `iPhoneCleaner/ViewModels/HomeViewModel.swift`:
```swift
import Foundation
import SwiftData

@Observable
final class HomeViewModel {
    let scanEngine = PhotoScanEngine()
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

**Step 2: Implement StorageRingView**

Create `iPhoneCleaner/Views/Home/StorageRingView.swift`:
```swift
import SwiftUI

struct StorageRingView: View {
    let fraction: Double
    let usedText: String
    let totalText: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: fraction)

            VStack(spacing: 4) {
                Text(usedText)
                    .font(.title2.bold())
                Text("of \(totalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 150, height: 150)
    }
}
```

**Step 3: Implement CategoryCardView**

Create `iPhoneCleaner/Views/Home/CategoryCardView.swift`:
```swift
import SwiftUI

struct CategoryCardView: View {
    let category: IssueCategory
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.subheadline.bold())
                    Text("\(count) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

**Step 4: Implement HomeView**

Create `iPhoneCleaner/Views/Home/HomeView.swift`:
```swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var isScanning = false
    @State private var showReview = false
    @State private var selectedCategory: IssueCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Storage Ring
                    StorageRingView(
                        fraction: viewModel.storageFraction,
                        usedText: viewModel.storageUsedFormatted,
                        totalText: viewModel.storageTotalFormatted
                    )
                    .padding(.top)

                    // Scan Button
                    Button {
                        isScanning = true
                    } label: {
                        Label("Scan Photos", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Category Results
                    if let result = viewModel.lastScanResult {
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
                ScanningView(scanEngine: viewModel.scanEngine) { result in
                    viewModel.lastScanResult = result
                    isScanning = false
                }
            }
            .sheet(isPresented: $showReview) {
                if let category = selectedCategory {
                    ReviewView(
                        issues: viewModel.scanEngine.issues.filter { $0.category == category },
                        category: category,
                        photoService: PhotoLibraryService()
                    )
                }
            }
            .onAppear {
                viewModel.loadStorageInfo()
            }
        }
    }
}
```

**Step 5: Build and run**

Run: Cmd+B
Expected: Build succeeds (ScanningView and ReviewView referenced but not yet implemented — will show compiler warnings, not errors, if wrapped in conditional checks. If errors, add placeholder views.)

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Home dashboard with storage ring, scan button, and category cards"
```

---

### Task 8: Scanning View

**Files:**
- Create: `iPhoneCleaner/Views/Scanning/ScanningView.swift`

**Step 1: Implement ScanningView**

Create `iPhoneCleaner/Views/Scanning/ScanningView.swift`:
```swift
import SwiftUI

struct ScanningView: View {
    let scanEngine: PhotoScanEngine
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
                let issues = try await scanEngine.scan()
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

**Step 2: Build**

Run: Cmd+B
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ScanningView with animated progress and live category counts"
```

---

### Task 9: Swipe Card Review View

**Files:**
- Create: `iPhoneCleaner/Views/Review/ReviewView.swift`
- Create: `iPhoneCleaner/Views/Review/SwipeCardView.swift`

**Step 1: Implement SwipeCardView**

Create `iPhoneCleaner/Views/Review/SwipeCardView.swift`:
```swift
import SwiftUI

struct SwipeCardView: View {
    let image: UIImage?
    let category: IssueCategory
    let confidence: Double
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    private var swipeThreshold: CGFloat { 120 }

    private var swipeColor: Color {
        if offset.width > 50 { return .green.opacity(0.3) }
        if offset.width < -50 { return .red.opacity(0.3) }
        return .clear
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)

            VStack(spacing: 12) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    Label(category.displayName, systemImage: category.systemImage)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.2))
                        .clipShape(Capsule())

                    Spacer()

                    Text("\(Int(confidence * 100))% match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            // Swipe overlay indicators
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
                    .opacity(offset.width < -50 ? Double(-offset.width - 50) / 100.0 : 0)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                    .opacity(offset.width > 50 ? Double(offset.width - 50) / 100.0 : 0)
            }
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(swipeColor, lineWidth: 3)
        )
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                    rotation = Double(value.translation.width / 20)
                }
                .onEnded { value in
                    if value.translation.width < -swipeThreshold {
                        withAnimation(.easeOut(duration: 0.3)) {
                            offset = CGSize(width: -500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeLeft()
                            offset = .zero
                            rotation = 0
                        }
                    } else if value.translation.width > swipeThreshold {
                        withAnimation(.easeOut(duration: 0.3)) {
                            offset = CGSize(width: 500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeRight()
                            offset = .zero
                            rotation = 0
                        }
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
}
```

**Step 2: Implement ReviewView**

Create `iPhoneCleaner/Views/Review/ReviewView.swift`:
```swift
import SwiftUI

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

import Photos
```

**Step 3: Build**

Run: Cmd+B
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add swipe card review interface with undo, skip, and batch delete"
```

---

### Task 10: App Cleanup View

**Files:**
- Create: `iPhoneCleaner/Views/Apps/AppCleanupView.swift`
- Create: `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`

**Step 1: Implement AppCleanupViewModel**

Create `iPhoneCleaner/ViewModels/AppCleanupViewModel.swift`:
```swift
import Foundation

@Observable
final class AppCleanupViewModel {
    var apps: [AppInfo] = []
    var isLoadingSuggestions = false
    var selectedApp: AppInfo?

    private let miraiService = MiraiService()

    func loadApps() {
        // Note: iOS has limited APIs for listing installed apps.
        // We can use LSApplicationWorkspace (private API, App Store rejection risk)
        // or DeviceActivityFramework for usage data.
        // For now, we provide a placeholder that works with Screen Time data.
        // Real implementation would use FamilyControls framework.
    }

    func generateSuggestions() async {
        guard !apps.isEmpty else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            // Initialize Mirai with API key from Keychain or bundled config
            try await miraiService.initialize(apiKey: MiraiConfig.apiKey)
            try await miraiService.loadModel()
            let suggestions = try await miraiService.generateAppSuggestions(for: apps)

            // Parse suggestions and assign to apps
            // Simple approach: assign the full text to the top apps
            for i in 0..<apps.count {
                apps[i].aiSuggestion = suggestions
            }
        } catch {
            print("Failed to generate suggestions: \(error)")
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

import UIKit

enum MiraiConfig {
    // In production, store in Keychain. For development, use environment variable or config file.
    static var apiKey: String {
        ProcessInfo.processInfo.environment["MIRAI_API_KEY"] ?? ""
    }
}
```

**Step 2: Implement AppCleanupView**

Create `iPhoneCleaner/Views/Apps/AppCleanupView.swift`:
```swift
import SwiftUI

struct AppCleanupView: View {
    @State private var viewModel = AppCleanupViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.apps.isEmpty {
                    ContentUnavailableView(
                        "No App Data",
                        systemImage: "square.grid.2x2",
                        description: Text("App usage data requires Screen Time access. Enable it in Settings > Screen Time.")
                    )
                } else {
                    List(viewModel.apps) { app in
                        AppRow(app: app)
                    }
                }
            }
            .navigationTitle("App Cleanup")
            .toolbar {
                if !viewModel.apps.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.generateSuggestions() }
                        } label: {
                            if viewModel.isLoadingSuggestions {
                                ProgressView()
                            } else {
                                Label("Get AI Tips", systemImage: "sparkles")
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadApps()
            }
        }
    }
}

private struct AppRow: View {
    let app: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.purple)
                    }

                VStack(alignment: .leading) {
                    Text(app.name)
                        .font(.headline)
                    HStack {
                        Text(app.sizeFormatted)
                        if let days = app.daysSinceLastUsed {
                            Text("Last used \(days)d ago")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let suggestion = app.aiSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .padding(8)
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Step 3: Build**

Run: Cmd+B
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add App Cleanup view with Mirai AI suggestions"
```

---

### Task 11: Settings View

**Files:**
- Create: `iPhoneCleaner/Views/Settings/SettingsView.swift`

**Step 1: Implement SettingsView**

Create `iPhoneCleaner/Views/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("blurThreshold") private var blurThreshold: Double = 0.3
    @AppStorage("similarityThreshold") private var similarityThreshold: Double = 0.80

    var body: some View {
        NavigationStack {
            Form {
                Section("Detection Sensitivity") {
                    VStack(alignment: .leading) {
                        Text("Blur Threshold: \(Int(blurThreshold * 100))%")
                        Slider(value: $blurThreshold, in: 0.1...0.8, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as blurry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Similarity Threshold: \(Int(similarityThreshold * 100))%")
                        Slider(value: $similarityThreshold, in: 0.5...0.99, step: 0.05)
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

**Step 2: Build**

Run: Cmd+B
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add Settings view with sensitivity sliders and privacy info"
```

---

### Task 12: Tab Navigation & App Entry Point

**Files:**
- Modify: `iPhoneCleaner/App/iPhoneCleanerApp.swift`
- Modify: `iPhoneCleaner/ContentView.swift`

**Step 1: Update ContentView with tab bar**

Replace `iPhoneCleaner/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
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

**Step 2: Build and run**

Run: Cmd+R
Expected: App launches with 3 tabs: Photos, Apps, Settings. Home screen shows storage ring and scan button.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add tab navigation connecting Home, Apps, and Settings screens"
```

---

### Task 13: Dark Mode Theme & Visual Polish

**Files:**
- Create: `iPhoneCleaner/Utilities/Theme.swift`
- Modify: `iPhoneCleaner/App/iPhoneCleanerApp.swift`

**Step 1: Create Theme utility**

Create `iPhoneCleaner/Utilities/Theme.swift`:
```swift
import SwiftUI

enum Theme {
    static let accentGradient = LinearGradient(
        colors: [.purple, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color(.systemGray6)

    static let glassMaterial: Material = .ultraThinMaterial
}
```

**Step 2: Force dark mode in App**

Update `iPhoneCleanerApp.swift` — add `.preferredColorScheme(.dark)` to the WindowGroup:
```swift
import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }
}
```

**Step 3: Build and run**

Run: Cmd+R
Expected: App renders in dark mode with purple/blue accent colors.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add dark mode theme with purple/blue gradient accents"
```

---

### Task 14: Deletion Confirmation & Success Animation

**Files:**
- Create: `iPhoneCleaner/Views/Review/DeletionSuccessView.swift`

**Step 1: Implement DeletionSuccessView**

Create `iPhoneCleaner/Views/Review/DeletionSuccessView.swift`:
```swift
import SwiftUI

struct DeletionSuccessView: View {
    let photosDeleted: Int
    let bytesFreed: Int64
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showText = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

            VStack(spacing: 8) {
                Text("\(photosDeleted) photos deleted")
                    .font(.title2.bold())

                Text("\(ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)) freed")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            .opacity(showText ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.4), value: showText)

            Text("Photos moved to Recently Deleted.\nRecoverable for 30 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showText ? 1 : 0)

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .onAppear {
            showCheckmark = true
            showText = true
        }
    }
}
```

**Step 2: Build**

Run: Cmd+B
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add deletion success view with animated checkmark and stats"
```

---

### Task 15: Error Handling & Permission Flows

**Files:**
- Create: `iPhoneCleaner/Views/Home/PhotoPermissionView.swift`
- Modify: `iPhoneCleaner/Views/Home/HomeView.swift`

**Step 1: Implement PhotoPermissionView**

Create `iPhoneCleaner/Views/Home/PhotoPermissionView.swift`:
```swift
import SwiftUI
import Photos

struct PhotoPermissionView: View {
    let onGranted: () -> Void

    @State private var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            Text("Photo Access Required")
                .font(.title2.bold())

            Text("iPhone Cleaner needs access to your photo library to find duplicates, blurry photos, and screenshots.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            if status == .denied || status == .restricted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            } else {
                Button("Allow Access") {
                    Task {
                        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                        status = newStatus
                        if newStatus == .authorized || newStatus == .limited {
                            onGranted()
                        }
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
        }
    }
}
```

**Step 2: Update HomeView to check permissions before scanning**

In `HomeView.swift`, wrap the scan button action to check photo permission first. Add a `@State private var showPermissionView = false` and add a `.sheet` for `PhotoPermissionView`. Before starting scan, check `PHPhotoLibrary.authorizationStatus(for: .readWrite)` — if not authorized, show permission view instead.

**Step 3: Build and run**

Run: Cmd+R
Expected: If photo access not granted, permission view appears. After granting, scan proceeds.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add photo permission flow with Settings deep link for denied state"
```

---

### Task 16: Integration Testing & Final Polish

**Files:**
- Create: `iPhoneCleanerTests/Integration/ScanFlowTests.swift`

**Step 1: Write integration-level tests**

Create `iPhoneCleanerTests/Integration/ScanFlowTests.swift`:
```swift
import Testing
@testable import iPhoneCleaner

@Test func scanSettingsIntegration() {
    var settings = ScanSettings()
    settings.blurThreshold = 0.5
    settings.duplicateThreshold = 0.9
    settings.batchSize = 10

    #expect(settings.blurThreshold == 0.5)
    #expect(settings.duplicateThreshold == 0.9)
    #expect(settings.batchSize == 10)
}

@Test func scanResultTotalIssues() {
    let result = ScanResult(
        totalPhotosScanned: 1000,
        duplicatesFound: 50,
        similarFound: 30,
        blurryFound: 20,
        screenshotsFound: 100
    )
    #expect(result.totalIssuesFound == 200)
}

@Test func photoIssueUserDecisionWorkflow() {
    var issue = PhotoIssue(
        assetId: "test1",
        category: .blurry,
        confidence: 0.85,
        fileSize: 1_000_000
    )
    #expect(issue.userDecision == .pending)

    issue.userDecision = .delete
    #expect(issue.userDecision == .delete)

    issue.userDecision = .keep
    #expect(issue.userDecision == .keep)
}

@Test func appInfoCleanupScoreOrdering() {
    let oldLargeApp = AppInfo(
        id: "1", name: "Big Old Game", bundleId: "com.test.game",
        sizeBytes: 3_000_000_000,
        lastUsedDate: Calendar.current.date(byAdding: .day, value: -90, to: Date())
    )
    let newSmallApp = AppInfo(
        id: "2", name: "Daily App", bundleId: "com.test.daily",
        sizeBytes: 10_000_000,
        lastUsedDate: Date()
    )

    #expect(oldLargeApp.cleanupScore > newSmallApp.cleanupScore)
}
```

**Step 2: Run all tests**

Run: Cmd+U or `xcodebuild test -scheme iPhoneCleaner -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add -A
git commit -m "test: add integration tests for scan flow, models, and app cleanup scoring"
```

---

## Summary

| Task | Description | Key Files |
|------|------------|-----------|
| 1 | Xcode project setup | Project, Info.plist, folder structure |
| 2 | Data models | PhotoIssue, ScanResult, AppInfo |
| 3 | Photo library service | PhotoLibraryService (access, load, delete) |
| 4 | Image analysis service | Blur detection, screenshots, similarity |
| 5 | Photo scan engine | Orchestrator with batching + progress |
| 6 | Mirai LLM service | App cleanup AI suggestions |
| 7 | Home dashboard | Storage ring, scan button, category cards |
| 8 | Scanning view | Progress animation, live counts |
| 9 | Swipe card review | Tinder-style swipe, undo, batch delete |
| 10 | App cleanup view | App list with AI suggestions |
| 11 | Settings view | Sensitivity sliders, privacy info |
| 12 | Tab navigation | Wire up all screens |
| 13 | Dark mode theme | Purple/blue gradients, glassmorphism |
| 14 | Deletion success | Animated confirmation screen |
| 15 | Permission flows | Photo access request + Settings link |
| 16 | Integration tests | End-to-end model and flow tests |
