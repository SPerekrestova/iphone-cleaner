# iPhone Cleaner

A free iOS app that finds junk in your photo library — duplicates, blurry shots, screenshots, and more — and lets you swipe through them like cards to quickly clean up.

All analysis runs on-device using Apple's Vision framework. Nothing leaves your phone.

## What it detects

| Category | How |
|---|---|
| Duplicates | Perceptual hashing + LSH bucketing |
| Similar photos | Feature-print distance via `VNGenerateImageFeaturePrintRequest` |
| Blurry | Laplacian variance scoring |
| Screenshots | `PHAsset.mediaSubtypes` + heuristic fallback |
| Screen recordings | Media subtype bit detection |
| Text-heavy | `VNRecognizeTextRequest` coverage ratio |
| Low quality | `VNCalculateImageAestheticsScoresRequest` (iOS 18+) |
| Lens smudge | `VNDetectLensSmudgeRequest` (iOS 26+) |

## Requirements

- iOS 26+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## License

[MIT](LICENSE)
