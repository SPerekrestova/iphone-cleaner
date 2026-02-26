# iPhone Cleaner v3 — Vision-Native Media Cleanup

**Goal:** Remove Mirai/App Cleanup, go all-in on Apple Vision framework for photo+video analysis, fix known bugs, add comprehensive tests.

**Prerequisite:** v2 complete (merged to main, 22 tests passing).

---

## 1. Remove Mirai SDK & App Cleanup

Strip all Mirai/Uzu code and the App Cleanup feature:

- Delete: `MiraiService.swift`, `AppCleanupViewModel.swift`, `AppCleanupView.swift`, `AppInfo.swift`, `MiraiServiceTests.swift`
- Remove "Apps" tab from `ContentView.swift` — two-tab layout: **Photos** | **Settings**
- Remove all `#if canImport(Uzu)` guards
- Remove Uzu references and comments from `project.yml`
- Clean up any dead imports

## 2. Vision-Powered Analysis Pipeline

### Existing (keep)

| Capability | Implementation | Notes |
|------------|---------------|-------|
| Blur detection | Laplacian variance (`ImageAnalysisService.blurScore`) | Best general blur detector, works on simulator |
| Duplicate/similar | `VNFeaturePrintObservation` + `computeDistance` | Update thresholds for iOS 17+ (768-dim normalized vectors) |
| Screenshot detection | `PHAsset.mediaSubtypes.contains(.photoScreenshot)` | Primary signal, heuristic fallback stays |

### New Vision capabilities

| Capability | API | iOS Min | Purpose |
|------------|-----|---------|---------|
| Image aesthetics | `CalculateImageAestheticsScoresRequest` | 18.0 | Overall quality score (-1 to 1), `isUtility` flag for docs/receipts |
| Lens smudge | `DetectLensSmudgeRequest` | 26.0 | Detect dirty-lens photos (confidence 0-1) |
| Text-heavy images | `VNRecognizeTextRequest` (.fast) | 13.0 | Detect receipts, notes, documents via text coverage ratio |
| Scene classification | `VNClassifyImageRequest` | 13.0 | 1,303-label taxonomy — auto-tag food, nature, people, etc. |
| Face quality | `VNDetectFaceCaptureQualityRequest` | 12.0 | Pick "best" photo in duplicate/similar groups containing faces |
| Screen recordings | `PHAsset.mediaSubtypes.rawValue & 524288` | 8.0 | Detect video screen recordings |

### Architecture

Expand `ImageAnalysisService` with new methods:

```
ImageAnalysisService
├── blurScore(for:)                    // existing — Laplacian
├── isScreenshotByHeuristic(...)       // existing
├── generateFeaturePrint(for:)         // existing — VNFeaturePrint
├── groupByFeaturePrint(...)           // existing — needs O(n^2) fix
├── aestheticsScore(for:)              // NEW — CalculateImageAestheticsScoresRequest
├── lensSmudgeConfidence(for:)         // NEW — DetectLensSmudgeRequest
├── textCoverage(for:)                 // NEW — VNRecognizeTextRequest
├── classifyScene(for:)               // NEW — VNClassifyImageRequest
├── faceCaptureQuality(for:)           // NEW — VNDetectFaceCaptureQualityRequest
└── cosineSimilarity(...)              // existing — Accelerate
```

### New issue categories

Extend `IssueCategory`:

```swift
enum IssueCategory: String, Codable, CaseIterable {
    case duplicate
    case similar
    case blurry
    case screenshot
    case screenRecording  // NEW
    case lensSmudge       // NEW
    case textHeavy        // NEW — receipts, notes, documents
    case lowQuality       // NEW — low aesthetics score
}
```

`VNClassifyImageRequest` results stored as metadata on `PhotoIssue` (tags), not as a separate issue category. Scene tags enable smart grouping in the review UI but don't flag photos for deletion on their own.

### Scan pipeline changes

`PhotoScanEngine.scan()` updated flow per asset:

1. Load image (with timeout — see bug fixes)
2. Blur score (Laplacian)
3. Screenshot check (PHAsset subtype + heuristic)
4. Aesthetics score + isUtility (`CalculateImageAestheticsScoresRequest`)
5. Lens smudge check (`DetectLensSmudgeRequest`)
6. Text coverage (`VNRecognizeTextRequest` .fast)
7. Scene classification (`VNClassifyImageRequest`)
8. Feature print generation (for similarity grouping)
9. Face quality (if faces detected — for "best pick" in groups)

After all assets processed:
10. Group by feature print (duplicates + similar) — using optimized grouping
11. Rank within groups using face quality + aesthetics score

## 3. Full Video Support

### Fetch

Expand `PhotoLibraryService.fetchAllPhotos()` → `fetchAllMedia()`:
- Include `PHAssetMediaType.video` in predicate
- Return `[PHAsset]` covering both images and videos

### Video analysis pipeline

For each video asset:
1. Check screen recording subtype (`rawValue & 524288`)
2. Extract 5-10 keyframes via `AVAssetImageGenerator`
3. Run blur detection on keyframes (flag if majority are blurry)
4. Generate feature prints from keyframes for duplicate detection
5. Run scene classification on representative keyframe
6. Compute video file size from `PHAssetResource`

### Keyframe extraction

```swift
func extractKeyframes(from asset: PHAsset, count: Int = 8) async -> [CGImage]
```

- Use `PHAsset` → request `AVAsset` via `PHImageManager.requestAVAsset`
- Extract frames at evenly-spaced intervals
- Target 512x512 for Vision analysis (same as photos)

### Duplicate video detection

Compare feature prints of keyframes between videos:
- Average the feature prints across keyframes to get a single "video fingerprint"
- Use same grouping logic as photos with adjusted thresholds

## 4. Bug Fixes

### 4.1 O(n^2) similarity grouping

**Problem:** `groupByFeaturePrint` does pairwise comparison — 12.5M comparisons at 5K photos.

**Fix:** Implement VP-tree (Vantage Point tree) for nearest-neighbor search in feature print space. Expected complexity: O(n log n) for construction, O(log n) per query.

Fallback: If VP-tree is too complex for v3, use band-based bucketing — partition feature prints into coarse buckets by a few dimensions, only compare within + adjacent buckets. Reduces constant factor ~10x.

### 4.2 `loadImage` can hang forever

**Problem:** If `PHImageManager` never delivers a non-degraded image, `withCheckedContinuation` never resumes.

**Fix:** Add 5-second timeout using `withThrowingTaskGroup`:

```swift
func loadImage(for asset: PHAsset, targetSize: CGSize, timeout: Duration = .seconds(5)) async -> UIImage? {
    await withTaskGroup(of: UIImage?.self) { group in
        group.addTask { await self._loadImage(for: asset, targetSize: targetSize) }
        group.addTask { try? await Task.sleep(for: timeout); return nil }
        let result = await group.next()
        group.cancelAll()
        return result ?? nil
    }
}
```

### 4.3 PhotoIssue list not persisted

**Problem:** `ScanResult` saves counts to SwiftData, but `PhotoIssue` array lives in-memory on `PhotoScanEngine.issues`. Kill app = lose reviewable list.

**Fix:** `PhotoIssue` already has `@Model` — insert issues into `ModelContext` after scan completes. On launch, fetch issues alongside `ScanResult`. Add a relationship: `ScanResult` → `[PhotoIssue]`.

### 4.4 No group comparison UI

**Problem:** Duplicate/similar groups show one photo at a time — user can't compare.

**Fix:** When reviewing duplicates/similar, show a "group view" with thumbnails of all group members. Highlight the recommended "best" photo (highest aesthetics score + face quality). User taps to select keepers, rest are marked for deletion.

### 4.5 Feature print thresholds for iOS 17+

**Problem:** iOS 17 changed feature print vectors from 2048-dim unnormalized to 768-dim normalized. Distance thresholds tuned for old vectors won't work.

**Fix:** Detect feature print revision at runtime. Use appropriate thresholds:
- iOS 17+ (768-dim): duplicate < 5.0, similar 5.0-12.0
- iOS 16 (2048-dim): duplicate < 5.0, similar 5.0-15.0 (current values)

Calibrate with test photo sets.

## 5. Test Strategy

### Expanded unit tests

- `ImageAnalysisService` — test each new Vision wrapper with known-output images
- `PhotoScanEngine` — test scan with mock service layer (protocol extraction)
- Video keyframe extraction — test frame count and spacing
- `loadImage` timeout — test that it returns nil after timeout
- Feature print threshold branching — test iOS version detection
- VP-tree / optimized grouping — correctness and performance

### UI tests (XCUITest)

New `iPhoneCleanerUITests` target:

| Test | Flow |
|------|------|
| `testScanAndReviewFlow` | Tap "Scan Photos" → see progress → tap category → swipe cards |
| `testSwipeLeftToDelete` | Swipe left → verify marked count increases |
| `testSwipeRightToKeep` | Swipe right → verify advances to next card |
| `testUndoSwipe` | Swipe → tap undo → verify previous card returns |
| `testBatchDelete` | Mark several → tap "Delete N" → confirm → see success view |
| `testEmptyCategory` | Open category with 0 results → see empty state |
| `testPermissionFlow` | Deny photo access → see permission prompt |
| `testSettingsSliders` | Adjust blur/similarity thresholds → verify values update |

### Performance benchmarks

New `iPhoneCleanerPerformanceTests`:

| Benchmark | What it measures |
|-----------|-----------------|
| `testFeaturePrintGeneration` | Throughput: feature prints per second |
| `testSimilarityGrouping100` | Grouping time at 100 feature prints |
| `testSimilarityGrouping1000` | Grouping time at 1,000 feature prints |
| `testBlurScoreThroughput` | Laplacian blur scores per second |
| `testSceneClassificationThroughput` | VNClassifyImageRequest per second |
| `testKeyframeExtraction` | Frames extracted per second |

Use `measure {}` blocks with baselines.

---

## Out of Scope

- App Store submission
- Accessibility audit
- Onboarding flow
- iCloud photo handling (deferred downloads)
- iPad-specific layouts
- Localization
