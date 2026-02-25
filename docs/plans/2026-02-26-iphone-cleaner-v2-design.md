# iPhone Cleaner v2 — Design

**Goal:** Make the app work end-to-end with real photos, integrate Mirai LLM, minimal polish.

**Prerequisite:** v1 complete (all 16 tasks, 18 tests passing, merged to main).

---

## 1. Shared AppState

Single `@Observable AppState` class replacing scattered state management:

- Owns: `PhotoScanEngine`, `PhotoLibraryService`, `ScanSettings`, `MiraiService`
- Injected via `.environment()` at app root in `iPhoneCleanerApp`
- Settings sliders in `SettingsView` write to `AppState.scanSettings`
- Scan engine reads settings from `AppState` when scanning
- Scan results (`ScanResult`) saved to SwiftData after completion
- All views read from shared state instead of creating their own service instances

## 2. End-to-End Flow Wiring

Complete user flow:

1. Home → tap "Scan Photos" → permission check
2. Permission granted → `ScanningView` with progress
3. Scan complete → results populate on Home (category cards)
4. Tap category → `ReviewView` with swipe cards
5. Swipe left (delete) / right (keep) through photos
6. Tap "Delete N" → confirmation alert → deletion → `DeletionSuccessView`
7. Done → back to Home with updated storage info and counts

Fixes needed:
- `ReviewView` shows `DeletionSuccessView` after successful batch delete
- Home refreshes storage info on appear (already done) and after returning from review
- `ScanResult` persisted to SwiftData so it survives app restart

## 3. Mirai SDK Integration

- Add `uzu-swift` (v0.2.10+) as SPM dependency in `project.yml`
- Remove `#if canImport(Uzu)` conditionals from `MiraiService.swift`
- API key: environment variable `MIRAI_API_KEY` for development
- App Cleanup tab: load demo `AppInfo` data, call `generateAppSuggestions` with real Mirai LLM
- Demo apps: 5-6 realistic sample apps with varied sizes and last-used dates

## 4. Simulator Testing

- Run full scan on simulator's existing photo library
- Verify: blur detection flags appropriate photos
- Verify: screenshot detection identifies screenshots
- Verify: duplicate/similar grouping works (may need similar photos added)
- Fix any crashes or unexpected behavior

## 5. Minimal Polish

- Basic app icon (SF Symbol rendered as asset or simple design)
- Fix edge cases found during testing (empty results, all kept, etc.)
- No App Store prep, no launch screen, no accessibility audit

---

## Out of Scope

- Real installed app enumeration (iOS limitation)
- App Store submission
- Performance optimization for 10k+ photo libraries
- Keychain storage for API key (production concern)
- Accessibility audit
