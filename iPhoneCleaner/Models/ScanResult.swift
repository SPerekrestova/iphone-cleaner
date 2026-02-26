import Foundation
import SwiftData

@Model
final class ScanResult {
    var scanDate: Date
    var totalPhotosScanned: Int
    var totalVideosScanned: Int
    var duplicatesFound: Int
    var similarFound: Int
    var blurryFound: Int
    var screenshotsFound: Int
    var screenRecordingsFound: Int
    var lensSmudgeFound: Int
    var textHeavyFound: Int
    var lowQualityFound: Int
    var totalSizeReclaimable: Int64

    init(
        totalPhotosScanned: Int = 0,
        totalVideosScanned: Int = 0,
        duplicatesFound: Int = 0,
        similarFound: Int = 0,
        blurryFound: Int = 0,
        screenshotsFound: Int = 0,
        screenRecordingsFound: Int = 0,
        lensSmudgeFound: Int = 0,
        textHeavyFound: Int = 0,
        lowQualityFound: Int = 0,
        totalSizeReclaimable: Int64 = 0
    ) {
        self.scanDate = Date()
        self.totalPhotosScanned = totalPhotosScanned
        self.totalVideosScanned = totalVideosScanned
        self.duplicatesFound = duplicatesFound
        self.similarFound = similarFound
        self.blurryFound = blurryFound
        self.screenshotsFound = screenshotsFound
        self.screenRecordingsFound = screenRecordingsFound
        self.lensSmudgeFound = lensSmudgeFound
        self.textHeavyFound = textHeavyFound
        self.lowQualityFound = lowQualityFound
        self.totalSizeReclaimable = totalSizeReclaimable
    }

    var totalIssuesFound: Int {
        duplicatesFound + similarFound + blurryFound + screenshotsFound +
        screenRecordingsFound + lensSmudgeFound + textHeavyFound + lowQualityFound
    }

    var totalMediaScanned: Int {
        totalPhotosScanned + totalVideosScanned
    }
}
