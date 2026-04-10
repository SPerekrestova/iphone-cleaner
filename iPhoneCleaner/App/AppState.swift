import Foundation
import SwiftData
import SwiftUI

@Observable
final class AppState {
    let scanEngine = PhotoScanEngine()
    let photoService = PhotoLibraryService()
    let imageCache = ImageCacheService.shared


    var scanSettings = ScanSettings()
    var lastScanResult: ScanResult?
    var lastScanIssues: [PhotoIssue] = []
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

    func saveScanResult(_ result: ScanResult, issues: [PhotoIssue], context: ModelContext) {
        result.issues = issues
        context.insert(result)
        try? context.save()
        lastScanResult = result
        lastScanIssues = issues
    }

    func loadLastScanResult(context: ModelContext) {
        let descriptor = FetchDescriptor<ScanResult>(
            sortBy: [SortDescriptor(\.scanDate, order: .reverse)]
        )
        if let result = try? context.fetch(descriptor).first {
            lastScanResult = result
            lastScanIssues = result.issues
        }
    }

    func removeDeletedIssues(_ deletedAssetIds: Set<String>) {
        lastScanIssues.removeAll { deletedAssetIds.contains($0.assetId) }
        guard let result = lastScanResult else { return }
        result.duplicatesFound = lastScanIssues.filter { $0.category == .duplicate }.count
        result.similarFound = lastScanIssues.filter { $0.category == .similar }.count
        result.blurryFound = lastScanIssues.filter { $0.category == .blurry }.count
        result.screenshotsFound = lastScanIssues.filter { $0.category == .screenshot }.count
        result.screenRecordingsFound = lastScanIssues.filter { $0.category == .screenRecording }.count
        result.lensSmudgeFound = lastScanIssues.filter { $0.category == .lensSmudge }.count
        result.textHeavyFound = lastScanIssues.filter { $0.category == .textHeavy }.count
        result.lowQualityFound = lastScanIssues.filter { $0.category == .lowQuality }.count
        result.totalSizeReclaimable = lastScanIssues.reduce(0) { $0 + $1.fileSize }
    }

    func loadStorageInfo() {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        ) else { return }
        storageTotal = Int64(values.volumeTotalCapacity ?? 0)
        let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        storageUsed = storageTotal - available
    }
}
