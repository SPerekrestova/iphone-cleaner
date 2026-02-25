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

            for (index, asset) in batch.enumerated() {
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

                // 2. Screenshot detection — use official API, fall back to heuristic
                let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                if isScreenshot || analysisService.isScreenshotByHeuristic(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    hasCameraMetadata: false
                ) {
                    let issue = PhotoIssue(
                        assetId: assetId,
                        category: .screenshot,
                        confidence: isScreenshot ? 1.0 : 0.9,
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
                    processed: batchStart + index + 1,
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
        let duplicateAssetIds = Set(duplicateGroups.flatMap { $0 })
        let similarGroups = analysisService.groupByFeaturePrint(featurePrints, maxDistance: 15.0)
        for group in similarGroups {
            // Filter out assets already covered by duplicate groups
            let nonDuplicateMembers = group.filter { !duplicateAssetIds.contains($0) }
            if nonDuplicateMembers.count < 2 { continue }

            let groupId = UUID().uuidString
            for assetId in nonDuplicateMembers.dropFirst() {
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
