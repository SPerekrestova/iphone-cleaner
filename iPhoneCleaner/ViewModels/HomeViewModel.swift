import Foundation
import SwiftData

@Observable
final class HomeViewModel {
    let scanEngine = PhotoScanEngine()
    var lastScanResult: ScanResult?
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

    func loadStorageInfo() {
        let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        storageTotal = (attrs?[.systemSize] as? Int64) ?? 0
        let freeSpace = (attrs?[.systemFreeSize] as? Int64) ?? 0
        storageUsed = storageTotal - freeSpace
    }
}
