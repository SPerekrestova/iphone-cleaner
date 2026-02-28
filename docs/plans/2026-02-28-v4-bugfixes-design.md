# v4 Bug Fixes Design — 7 Critical Issues from Device Testing

**Date:** 2026-02-28
**Branch:** `fix/v4-device-testing-bugs`

## Bug 1: Storage Calculation Incorrect

**Root cause:** `FileManager.attributesOfFileSystem` with `.systemFreeSize` reports raw filesystem free space, not accounting for iOS purgeable storage (caches, system-managed temp data).

**Fix:** In `AppState.loadStorageInfo()`, switch to `URL.resourceValues(forKeys:)` with `.volumeTotalCapacityKey` and `.volumeAvailableCapacityForImportantUsageKey`.

**File:** `AppState.swift`

## Bug 2: False Positive Duplicates

**Root cause:** The formula `(1.0 - threshold) * 100.0` produces `maxDistance=5.0` for the default 0.95 threshold. This is not calibrated to `VNFeaturePrintObservation.computeDistance()` — real-world distances for unrelated images can be as low as 5-15 on iOS 17+ 768-dim normalized vectors. User reported completely unrelated photos (screenshots, internet images) being grouped.

**Fix:**
- Tighten default `duplicateThreshold` from 0.95 to 0.98
- Change distance formula from `(1-t)*100` to `(1-t)*50` to halve the distance range
- Result: default maxDistance goes from 5.0 → 1.0
- Similar threshold stays at 0.80, maxDistance goes from 20.0 → 10.0

**File:** `PhotoScanEngine.swift` (ScanSettings + distance conversion)

## Bug 3: Counter Not Reset After Deletion

**Root cause:** `HomeView` displays static `ScanResult` counters set at scan time. After deletion in `ReviewView`, the `ScanResult` model is never updated. User returns to HomeView and sees stale counts (e.g., "5 duplicates" when 3 were deleted).

**Fix:** After successful deletion in `ReviewView`, update `AppState.lastScanIssues` by removing deleted items, and recompute `ScanResult` counters from the remaining issues.

**Files:** `ReviewView.swift`, `AppState.swift`, `ScanResult.swift`

## Bug 4: People Photos Treated as Text

**Root cause:** `VNRecognizeTextRequest` detects facial features, clothing patterns, and background textures as text. No face-exclusion logic. The 15% threshold is low enough for incidental false positives on portrait photos.

**Fix:** In `ImageAnalysisService`, add a `detectFaces()` method using `VNDetectFaceRectanglesRequest`. In `PhotoScanEngine.scan()`, before text coverage analysis, check if faces are detected with significant area (>10% of image). If so, skip text detection for that photo.

**Files:** `ImageAnalysisService.swift`, `PhotoScanEngine.swift`

## Bug 5: Freed Space Screen Showing Twice

**Root cause:** `deletionSuccessBinding` in `ReviewView` creates `DeletionInfo(id: UUID(), ...)` in the binding getter. Each SwiftUI evaluation produces a new UUID = new identity, causing `.fullScreenCover(item:)` to dismiss and re-present.

**Fix:** Replace the computed binding with a `@State private var deletionInfo: DeletionInfo?` property. Set it once in `applyDeletion()` flow. Use `.fullScreenCover(item: $deletionInfo)` directly.

**File:** `ReviewView.swift`

## Bug 6: Photos Lagging During Swiping

**Root cause:** `loadCurrentImage()` fetches from PhotoKit on every swipe with no prefetching or caching. Combined with `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` delay in SwipeCardView for the dismiss animation.

**Fix:**
- Add image cache dictionary `[String: UIImage]` to `ReviewView`
- Prefetch next 2 images when current image loads
- Evict images more than 2 positions behind current index
- Pre-set `currentImage` from cache before `.task()` triggers

**File:** `ReviewView.swift`

## Bug 7: Scan Progress Jumping Around

**Root cause:** `PhotoScanEngine.progress` is modified from a background cooperative thread inside `async scan()`. `@Observable` sends change notifications on the modifying thread, but SwiftUI reads from the main thread. This causes stale/intermediate values and visual jumping.

**Fix:** Wrap all `progress = ScanProgress(...)` assignments inside `await MainActor.run { ... }` to ensure UI-consistent updates.

**File:** `PhotoScanEngine.swift`

## Testing Strategy

Each fix gets tests written first (TDD):
1. **Storage:** Unit test that `loadStorageInfo()` returns positive values
2. **Duplicates:** Unit test verifying tighter threshold doesn't group unrelated feature prints
3. **Counter:** Unit test that `updateCountsAfterDeletion()` recalculates correctly
4. **Text/faces:** Unit test that face-heavy images skip text detection
5. **Double cover:** UI test or unit test verifying `DeletionInfo` identity stability
6. **Prefetch:** Unit test for cache eviction logic
7. **Progress:** Unit test verifying progress updates on MainActor
