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
    var duplicateThreshold: Float = 0.98
    var similarThreshold: Float = 0.80
    var batchSize: Int = 30
    var excludedAlbumIds: Set<String> = []
    var textCoverageThreshold: Double = 0.15
    var lowQualityThreshold: Float = -0.3
    var lensSmudgeThreshold: Float = 0.7
    var maxConcurrency: Int = 4
}

@Observable
final class PhotoScanEngine {
    private let photoService = PhotoLibraryService()

    var isScanning = false
    var progress = ScanProgress(processed: 0, total: 0)
    var issues: [PhotoIssue] = []

    func scan(settings: ScanSettings = ScanSettings()) async throws -> [PhotoIssue] {
        await MainActor.run {
            isScanning = true
            issues = []
        }
        defer {
            Task { @MainActor in
                isScanning = false
            }
        }

        let assets = photoService.fetchAllMedia()
        let total = assets.count
        await MainActor.run {
            progress = ScanProgress(processed: 0, total: total)
        }

        let accumulator = ScanAccumulator()

        // Progress polling task — 10fps instead of per-asset MainActor hops
        let progressTask = Task {
            while !Task.isCancelled {
                let (processed, counts) = await accumulator.snapshot()
                await MainActor.run {
                    progress = ScanProgress(processed: processed, total: total, categoryCounts: counts)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        // Parallel asset processing with concurrency limiter
        await withTaskGroup(of: Void.self) { group in
            for (i, asset) in assets.enumerated() {
                if i >= settings.maxConcurrency {
                    await group.next()
                }

                group.addTask {
                    let result = await Self.processAsset(
                        asset, settings: settings
                    )
                    await accumulator.addResult(result)
                }
            }
        }

        progressTask.cancel()

        // Finalize — convert IssueData to PhotoIssue
        let (issueDataList, featurePrints) = await accumulator.finalize()
        var allIssues = issueDataList.map { data in
            PhotoIssue(
                assetId: data.assetId,
                category: data.category,
                confidence: data.confidence,
                fileSize: data.fileSize,
                userDecision: data.userDecision,
                groupId: data.groupId,
                sceneTags: data.sceneTags,
                aestheticsScore: data.aestheticsScore,
                isVideo: data.isVideo
            )
        }

        // Single-pass grouping at looser threshold, then partition into dup vs similar
        let dupMaxDist = Float((1.0 - Double(settings.duplicateThreshold)) * 50.0)
        let simMaxDist = Float((1.0 - Double(settings.similarThreshold)) * 50.0)

        let groupingService = ImageAnalysisService()
        let allGroups = groupingService.groupByFeaturePrintBucketed(featurePrints, maxDistance: simMaxDist)

        var categoryCounts = await accumulator.snapshot().1
        var duplicateAssetIds = Set<String>()

        // First pass: extract duplicates (tight distance)
        for group in allGroups {
            var dupGroup: [String] = []
            let anchor = featurePrints.first { $0.id == group[0] }
            for memberId in group {
                if memberId == group[0] { dupGroup.append(memberId); continue }
                guard let memberFP = featurePrints.first(where: { $0.id == memberId }),
                      let anchorFP = anchor else { continue }
                let dist = (try? groupingService.featurePrintDistance(anchorFP.print, memberFP.print)) ?? Float.infinity
                if dist <= dupMaxDist {
                    dupGroup.append(memberId)
                }
            }

            if dupGroup.count > 1 {
                let groupId = UUID().uuidString
                for assetId in dupGroup.dropFirst() {
                    allIssues.append(PhotoIssue(
                        assetId: assetId, category: .duplicate,
                        confidence: 0.95, fileSize: 0, groupId: groupId
                    ))
                    categoryCounts[.duplicate, default: 0] += 1
                    duplicateAssetIds.insert(assetId)
                }
                duplicateAssetIds.insert(dupGroup[0])
            }
        }

        // Second pass: remaining similar groups (exclude duplicates)
        for group in allGroups {
            let nonDupMembers = group.filter { !duplicateAssetIds.contains($0) }
            if nonDupMembers.count < 2 { continue }
            let groupId = UUID().uuidString
            for assetId in nonDupMembers.dropFirst() {
                allIssues.append(PhotoIssue(
                    assetId: assetId, category: .similar,
                    confidence: 0.85, fileSize: 0, groupId: groupId
                ))
                categoryCounts[.similar, default: 0] += 1
            }
        }

        let finalCounts = categoryCounts
        let finalIssues = allIssues
        await MainActor.run {
            progress = ScanProgress(processed: total, total: total, categoryCounts: finalCounts)
            issues = finalIssues
            isScanning = false
        }

        return allIssues
    }

    private static func processAsset(
        _ asset: PHAsset,
        settings: ScanSettings
    ) async -> AssetScanResult {
        let photoService = PhotoLibraryService()
        let analysisService = ImageAnalysisService()

        let assetId = asset.localIdentifier
        let fileSize = photoService.getAssetFileSize(asset)
        let isVideo = asset.mediaType == .video
        var issues: [AssetScanResult.IssueData] = []
        var featurePrint: (id: String, print: VNFeaturePrintObservation)?

        // Screen recording check (videos only)
        if isVideo && PhotoLibraryService.isScreenRecording(subtypeRawValue: asset.mediaSubtypes.rawValue) {
            issues.append(AssetScanResult.IssueData(
                assetId: assetId, category: .screenRecording,
                confidence: 1.0, fileSize: fileSize,
                userDecision: .pending, groupId: nil,
                sceneTags: nil, aestheticsScore: nil, isVideo: true
            ))
        }

        // Load image (or single keyframe for video)
        let image: UIImage?
        if isVideo {
            if let cgImage = await photoService.extractKeyframe(from: asset) {
                image = UIImage(cgImage: cgImage)
                // Feature print from keyframe
                if let fp = try? analysisService.generateFeaturePrint(for: UIImage(cgImage: cgImage)) {
                    featurePrint = (id: assetId, print: fp)
                }
            } else {
                image = nil
            }
        } else {
            image = await photoService.loadImageWithTimeout(
                for: asset, targetSize: CGSize(width: 512, height: 512)
            )
        }

        guard let image else {
            return AssetScanResult(issues: issues, featurePrint: featurePrint)
        }

        // Batched Vision analysis (single image decode for saliency + face + text + featurePrint)
        if let batch = try? analysisService.batchedAnalysis(for: image) {
            // Blur detection (skip Portrait mode)
            let isPortrait = asset.mediaSubtypes.contains(.photoDepthEffect)
            if !isPortrait && batch.blurScore < settings.blurThreshold {
                issues.append(AssetScanResult.IssueData(
                    assetId: assetId, category: .blurry,
                    confidence: 1.0 - batch.blurScore, fileSize: fileSize,
                    userDecision: .pending, groupId: nil,
                    sceneTags: nil, aestheticsScore: nil, isVideo: isVideo
                ))
            }

            // Screenshot detection (photos only)
            if !isVideo {
                let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                if isScreenshot || analysisService.isScreenshotByHeuristic(
                    pixelWidth: asset.pixelWidth, pixelHeight: asset.pixelHeight,
                    hasCameraMetadata: false
                ) {
                    issues.append(AssetScanResult.IssueData(
                        assetId: assetId, category: .screenshot,
                        confidence: isScreenshot ? 1.0 : 0.9, fileSize: fileSize,
                        userDecision: .pending, groupId: nil,
                        sceneTags: nil, aestheticsScore: nil, isVideo: false
                    ))
                }
            }

            // Text coverage (skip if significant face area)
            if batch.faceArea <= 0.10 && batch.textCoverage >= settings.textCoverageThreshold {
                issues.append(AssetScanResult.IssueData(
                    assetId: assetId, category: .textHeavy,
                    confidence: min(batch.textCoverage * 2, 1.0), fileSize: fileSize,
                    userDecision: .pending, groupId: nil,
                    sceneTags: nil, aestheticsScore: nil, isVideo: isVideo
                ))
            }

            // Feature print for photos (videos handled above)
            if !isVideo, let fp = batch.featurePrint {
                featurePrint = (id: assetId, print: fp)
            }

            // Aesthetics + lens smudge (async, run concurrently)
            async let aestheticsResult = analysisService.aestheticsScore(for: image)
            async let smudgeResult = analysisService.lensSmudgeConfidence(for: image)
            let aesthetics = await aestheticsResult
            let smudge = await smudgeResult

            // Lazy classifyScene — only if lowQuality or lensSmudge triggered
            let needsSceneTags = (aesthetics != nil && aesthetics!.score < settings.lowQualityThreshold)
                || (smudge != nil && smudge! >= settings.lensSmudgeThreshold)
            let sceneTags: [String]? = needsSceneTags
                ? ((try? analysisService.classifyScene(for: image, topK: 3))?.map { $0.label } ?? [])
                : nil

            if let aesthetics, aesthetics.score < settings.lowQualityThreshold {
                issues.append(AssetScanResult.IssueData(
                    assetId: assetId, category: .lowQuality,
                    confidence: Double(1.0 - (aesthetics.score + 1.0) / 2.0),
                    fileSize: fileSize,
                    userDecision: .pending, groupId: nil,
                    sceneTags: sceneTags, aestheticsScore: aesthetics.score, isVideo: isVideo
                ))
            }

            if let smudge, smudge >= settings.lensSmudgeThreshold {
                issues.append(AssetScanResult.IssueData(
                    assetId: assetId, category: .lensSmudge,
                    confidence: Double(smudge), fileSize: fileSize,
                    userDecision: .pending, groupId: nil,
                    sceneTags: sceneTags, aestheticsScore: nil, isVideo: isVideo
                ))
            }
        }

        return AssetScanResult(issues: issues, featurePrint: featurePrint)
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
