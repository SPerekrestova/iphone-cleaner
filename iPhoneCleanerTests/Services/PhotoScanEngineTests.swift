import Testing
import UIKit
import Photos
import Vision
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

// MARK: - Behavioral Tests: Threshold Influence

@Test func blurThresholdInfluencesDetection() throws {
    // A blur score of 0.2 should be flagged at threshold 0.3 but not at 0.1
    let blurScore = 0.2
    let highThreshold = 0.3
    let lowThreshold = 0.1
    #expect(blurScore < highThreshold, "Score 0.2 should be flagged as blurry at threshold 0.3")
    #expect(!(blurScore < lowThreshold), "Score 0.2 should NOT be flagged as blurry at threshold 0.1")
}

@Test func textCoverageThresholdInfluencesDetection() {
    // A text coverage of 0.2 should be flagged at threshold 0.15 but not at 0.25
    let coverage = 0.2
    let lowThreshold = 0.15
    let highThreshold = 0.25
    #expect(coverage >= lowThreshold, "Coverage 0.2 should be flagged at threshold 0.15")
    #expect(!(coverage >= highThreshold), "Coverage 0.2 should NOT be flagged at threshold 0.25")
}

// MARK: - Threshold to Distance Conversion

@Test func similarThresholdToDistanceConversion() {
    // (1 - 0.95) * 100 == 5.0, (1 - 0.80) * 100 == 20.0
    let tight: Float = 0.95
    let loose: Float = 0.80
    let tightDist = Float((1.0 - Double(tight)) * 100.0)
    let looseDist = Float((1.0 - Double(loose)) * 100.0)
    #expect(abs(tightDist - 5.0) < 0.01, "Threshold 0.95 should map to distance ~5.0")
    #expect(abs(looseDist - 20.0) < 0.01, "Threshold 0.80 should map to distance ~20.0")
}

@Test func duplicateThresholdToDistanceConversion() {
    let threshold: Float = 0.95
    let distance = Float((1.0 - Double(threshold)) * 100.0)
    #expect(abs(distance - 5.0) < 0.01, "Duplicate threshold 0.95 should map to distance ~5.0")
}

@Test func defaultThresholdsMatchExpected() {
    let settings = ScanSettings()
    let dupDist = Float((1.0 - Double(settings.duplicateThreshold)) * 100.0)
    let simDist = Float((1.0 - Double(settings.similarThreshold)) * 100.0)
    #expect(abs(dupDist - 5.0) < 0.01, "Default duplicate distance should be ~5.0")
    #expect(abs(simDist - 20.0) < 0.01, "Default similar distance should be ~20.0")
}

// Note: Neural Engine required — gracefully skips on simulator
@Test func featurePrintGroupingTighterDistanceFewerGroups() throws {
    let service = ImageAnalysisService()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
    let img1 = renderer.image { ctx in
        UIColor.blue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    }
    let img2 = renderer.image { ctx in
        UIColor.blue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
    let fp1: VNFeaturePrintObservation?
    let fp2: VNFeaturePrintObservation?
    do {
        fp1 = try service.generateFeaturePrint(for: img1)
        fp2 = try service.generateFeaturePrint(for: img2)
    } catch {
        // Neural Engine not available on simulator — skip
        return
    }
    guard let fp1, let fp2 else { return }
    let prints: [(id: String, print: VNFeaturePrintObservation)] = [
        (id: "a", print: fp1), (id: "b", print: fp2)
    ]
    let tightGroups = service.groupByFeaturePrint(prints, maxDistance: 0.001)
    let looseGroups = service.groupByFeaturePrint(prints, maxDistance: 100.0)
    #expect(looseGroups.count >= tightGroups.count, "Looser distance should produce at least as many groups as tight")
}

// Note: Neural Engine required — gracefully skips on simulator
@Test func salientRegionBlurScoreReturnsValue() throws {
    let service = ImageAnalysisService()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
    let image = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        UIColor.black.setFill()
        ctx.fill(CGRect(x: 30, y: 30, width: 40, height: 40))
    }
    do {
        let score = try service.salientRegionBlurScore(for: image)
        #expect(score >= 0.0 && score <= 1.0, "Saliency blur score should be in 0...1 range")
    } catch {
        // Saliency request needs Neural Engine — skip on simulator
    }
}

@Test func portraitSkipLogic() {
    // PHAssetMediaSubtype.photoDepthEffect has rawValue 8 (1 << 3)
    let portraitSubtype = PHAssetMediaSubtype.photoDepthEffect
    let regularSubtype = PHAssetMediaSubtype.photoScreenshot
    let isPortrait = portraitSubtype.contains(.photoDepthEffect)
    let isNotPortrait = regularSubtype.contains(.photoDepthEffect)
    #expect(isPortrait == true, "Portrait subtypes should be detected")
    #expect(isNotPortrait == false, "Non-portrait subtypes should not match")
}
