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
    var textCoverageThreshold: Double = 0.15
    var lowQualityThreshold: Float = -0.3
    var lensSmudgeThreshold: Float = 0.7
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
                    // Generate feature print from first keyframe for duplicate detection
                    for frame in keyframes {
                        if let fp = try? analysisService.generateFeaturePrint(for: UIImage(cgImage: frame)) {
                            featurePrints.append((id: assetId, print: fp))
                            break
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

                // Blur detection (photos and video keyframes, skip Portrait mode)
                let isPortrait = asset.mediaSubtypes.contains(.photoDepthEffect)
                if !isPortrait,
                   let blurScore = try? analysisService.salientRegionBlurScore(for: image),
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

                // Scene classification (store tags, not an issue category)
                let sceneTags = (try? analysisService.classifyScene(for: image, topK: 3))?.map { $0.label } ?? []

                // Aesthetics score (iOS 18+)
                if let aesthetics = await analysisService.aestheticsScore(for: image) {
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

        // Group duplicates + similar (same logic as before)
        let dupMaxDist = Float((1.0 - Double(settings.duplicateThreshold)) * 100.0)
        let duplicateGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: dupMaxDist)
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
        let simMaxDist = Float((1.0 - Double(settings.similarThreshold)) * 100.0)
        let similarGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: simMaxDist)
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

    func deleteMarkedPhotos() async throws -> Int64 {
        let toDelete = issues.filter { $0.userDecision == .delete }
        let assetIds = toDelete.map { $0.assetId }
        let freedBytes = toDelete.reduce(Int64(0)) { $0 + $1.fileSize }

        try await photoService.deleteAssets(assetIds)
        issues.removeAll { $0.userDecision == .delete }

        return freedBytes
    }
}
