# iPhone Cleaner - Design Document

## Overview

A free iOS app that helps users reclaim iPhone storage by identifying and removing unwanted photos/videos, and suggesting apps to delete or reorganize. Inspired by [LuminaClean](https://luminaclean.app/). All ML processing runs on-device via [Mirai](https://trymirai.com/).

## Platform & Tech Stack

- **Platform**: iOS only (iPhone, iPad)
- **Language**: Swift
- **UI**: SwiftUI
- **ML Engine**: Mirai SDK (`uzu-swift`) for all on-device inference
- **Data**: SwiftData for caching scan results and embeddings
- **Photos**: PhotoKit (PHAsset, PHPhotoLibrary)
- **App Usage**: DeviceActivityFramework / ScreenTime API
- **Architecture**: MVVM
- **Monetization**: Completely free, no ads, no accounts

## Architecture

Four layers:

1. **UI Layer** (SwiftUI Views): Swipe card interface, category tabs, results screens, app cleanup screen
2. **ViewModel Layer**: Manages scan state, photo review queue, deletion batching
3. **Service Layer**: Photo scanning engine, app usage analyzer, Mirai ML coordinator
4. **Data Layer**: PhotoKit, device app usage APIs, SwiftData cache

## Core Features

### Photo/Video Cleanup

Detection categories:
- **Exact duplicates**: Identical or near-identical photos
- **Similar photos**: Burst-like sequences, multiple shots of the same scene
- **Blurry photos**: Low-quality, out-of-focus images
- **Screenshots**: Device screenshots vs camera photos

### App Cleanup

- Analyze installed apps by usage frequency and storage size
- Generate AI-powered cleanup suggestions via Mirai LLM
- Link to Settings for app deletion (iOS doesn't allow programmatic deletion)

## Data Flow

### Photo Scan Flow

```
User taps "Scan"
  -> PhotoScanService fetches all PHAssets
  -> Mirai runs vision model on each photo (batched, 20-50 at a time)
  -> Results categorized: duplicates, similar, blurry, screenshots
  -> ViewModel populates swipe card queue per category
  -> User swipes left (delete) / right (keep)
  -> Batch deletion via PHPhotoLibrary change request
  -> Photos go to Recently Deleted (recoverable for 30 days)
```

### App Cleanup Flow

```
User opens "Apps" tab
  -> AppAnalyzer reads installed apps + usage data
  -> Mirai LLM generates suggestions based on name, size, last used date
  -> User reviews suggestions
  -> Taps to open Settings for deletion
```

## ML Pipeline

All models converted from Hugging Face via Mirai's `lalamo` conversion tool, run through Mirai's Apple Silicon-optimized engine.

| Task | Model | Approach |
|------|-------|----------|
| Blur detection | Lightweight CNN (MobileNetV3-Small) | Binary classification, threshold ~0.7 |
| Screenshot detection | Image classifier | Binary classifier. Heuristic fallback: screen resolution + no EXIF camera data |
| Duplicate detection | Image embedding model (EfficientNet-Lite) | 128-dim feature vectors, cosine similarity > 0.95 |
| Similar photo detection | Same embedding model | Cosine similarity 0.80-0.95 |
| App suggestions | Small LLM (Phi-3-mini or Gemma-2B) | Structured app data in, natural language advice out |

### Performance

- Background scanning with progress indicator
- Batched processing (20-50 photos per batch)
- Embeddings cached in SwiftData for fast re-scans
- Target: ~2-5 minutes for 5,000 photos

## Screens

### 1. Home/Dashboard
- Storage summary with circular progress (used/free)
- Prominent "Scan" button
- Category cards showing last scan results
- Apps section shortcut

### 2. Scanning Screen
- Full-screen progress animation
- Live counter: "Analyzing photo 342 of 5,012..."
- Category counts updating in real-time

### 3. Category Review (Swipe Cards)
- One card per category (Duplicates / Similar / Blurry / Screenshots)
- Tinder-style swipe: left = delete, right = keep
- Large photo display with category badge and confidence score
- Duplicates/similar: side-by-side comparison showing "best" vs "duplicate"
- Bottom toolbar: undo, skip, "Delete All in Category"
- Progress bar showing position in queue

### 4. Deletion Confirmation
- Summary: "Delete 47 photos? This will free ~1.2 GB"
- Success animation with space freed counter

### 5. App Cleanup
- Apps sorted by cleanup score (usage frequency + size)
- Each row: icon, name, size, last used, AI suggestion
- Tap for detailed Mirai LLM suggestion
- "Open in Settings" button

### 6. Settings
- Sensitivity sliders (blur threshold, similarity threshold)
- Excluded albums
- About / privacy info

## Design Language

Dark mode with accent color gradients. Clean, minimal, glassmorphic cards. Inspired by Lumina's aesthetic.

## Error Handling

- **Photo access denied**: Clear prompt with deep link to Settings
- **Mirai model loading fails**: Graceful fallback, retry button. Screenshot detection falls back to heuristic
- **Insufficient storage for scan**: Alert suggesting to free ~50MB first
- **Large libraries (50K+)**: Paginated scanning with pause/resume

## Privacy

- All processing on-device via Mirai, no network calls for ML
- No analytics, no tracking, no accounts
- Photo library access (read + delete) and optional Screen Time access
- "Your photos never leave your device"

## Testing Strategy

- **Unit tests**: Similarity calculations, threshold logic, category classification
- **UI tests**: Swipe interactions, deletion flow, navigation
- **ML tests**: Model accuracy on test photo sets (known blurry, known duplicates)
- **Performance tests**: Scan time benchmarks for 1K, 5K, 10K photo libraries
