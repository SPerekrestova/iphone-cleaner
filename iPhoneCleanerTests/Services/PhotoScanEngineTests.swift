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
