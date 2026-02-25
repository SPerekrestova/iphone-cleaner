import Foundation
import SwiftData

@Model
final class ScanResult {
    var scanDate: Date
    var totalPhotosScanned: Int
    var duplicatesFound: Int
    var similarFound: Int
    var blurryFound: Int
    var screenshotsFound: Int
    var totalSizeReclaimable: Int64

    init(
        totalPhotosScanned: Int = 0,
        duplicatesFound: Int = 0,
        similarFound: Int = 0,
        blurryFound: Int = 0,
        screenshotsFound: Int = 0,
        totalSizeReclaimable: Int64 = 0
    ) {
        self.scanDate = Date()
        self.totalPhotosScanned = totalPhotosScanned
        self.duplicatesFound = duplicatesFound
        self.similarFound = similarFound
        self.blurryFound = blurryFound
        self.screenshotsFound = screenshotsFound
        self.totalSizeReclaimable = totalSizeReclaimable
    }

    var totalIssuesFound: Int {
        duplicatesFound + similarFound + blurryFound + screenshotsFound
    }
}
