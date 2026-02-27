import Testing
@testable import iPhoneCleaner

@Test func scanProgressCalculation() {
    let progress = ScanProgress(processed: 50, total: 200)
    #expect(progress.fraction == 0.25)
    #expect(progress.percentFormatted == "25%")
}

@Test func scanProgressZeroTotal() {
    let progress = ScanProgress(processed: 0, total: 0)
    #expect(progress.fraction == 0.0)
}

@Test func scanSettingsDefaults() {
    let settings = ScanSettings()
    #expect(settings.blurThreshold == 0.3)
    #expect(settings.duplicateThreshold == 0.95)
    #expect(settings.similarThreshold == 0.80)
    #expect(settings.batchSize == 30)
}

@Test func scanSettingsNewDefaults() {
    let settings = ScanSettings()
    #expect(settings.textCoverageThreshold == 0.15)
    #expect(settings.lowQualityThreshold == -0.3)
    #expect(settings.lensSmudgeThreshold == 0.7)
}

@Test func scanProgressTracksNewCategories() {
    var progress = ScanProgress(processed: 10, total: 100)
    progress.categoryCounts[.screenRecording] = 3
    progress.categoryCounts[.textHeavy] = 5
    progress.categoryCounts[.lowQuality] = 2
    progress.categoryCounts[.lensSmudge] = 1
    #expect(progress.categoryCounts[.screenRecording] == 3)
    #expect(progress.categoryCounts[.textHeavy] == 5)
}
