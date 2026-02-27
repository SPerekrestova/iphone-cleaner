import Foundation
import SwiftData
import SwiftUI

@Observable
final class AppState {
    let scanEngine = PhotoScanEngine()
    let photoService = PhotoLibraryService()


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

    func loadStorageInfo() {
        let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        storageTotal = (attrs?[.systemSize] as? Int64) ?? 0
        let freeSpace = (attrs?[.systemFreeSize] as? Int64) ?? 0
        storageUsed = storageTotal - freeSpace
    }
}
