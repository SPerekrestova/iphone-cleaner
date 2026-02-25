import Testing
import UIKit
import CoreGraphics
@testable import iPhoneCleaner

@Test func cosineSimilarityIdenticalVectors() {
    let a: [Float] = [1.0, 0.0, 0.0, 1.0]
    let b: [Float] = [1.0, 0.0, 0.0, 1.0]
    let similarity = ImageAnalysisService.cosineSimilarity(a, b)
    #expect(abs(similarity - 1.0) < 0.001)
}

@Test func cosineSimilarityOrthogonalVectors() {
    let a: [Float] = [1.0, 0.0]
    let b: [Float] = [0.0, 1.0]
    let similarity = ImageAnalysisService.cosineSimilarity(a, b)
    #expect(abs(similarity) < 0.001)
}

@Test func cosineSimilarityEmptyVectors() {
    let similarity = ImageAnalysisService.cosineSimilarity([], [])
    #expect(similarity == 0.0)
}

@Test func blurScoreReturnsValueInRange() async throws {
    // Create a simple solid color test image
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
    let image = renderer.image { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    let service = ImageAnalysisService()
    let score = try service.blurScore(for: image)
    #expect(score >= 0.0 && score <= 1.0)
}

@Test func screenshotDetectionByMetadata() {
    let service = ImageAnalysisService()
    // A screenshot typically has no camera make/model in EXIF
    let isScreenshot = service.isScreenshotByHeuristic(
        pixelWidth: 1170,
        pixelHeight: 2532,
        hasCameraMetadata: false
    )
    #expect(isScreenshot == true)

    let isNotScreenshot = service.isScreenshotByHeuristic(
        pixelWidth: 4032,
        pixelHeight: 3024,
        hasCameraMetadata: true
    )
    #expect(isNotScreenshot == false)
}

@Test func groupDuplicatesByThreshold() {
    let service = ImageAnalysisService()
    let embeddings: [(String, [Float])] = [
        ("photo1", [1.0, 0.0, 0.0]),
        ("photo2", [0.99, 0.01, 0.0]),  // very similar to photo1
        ("photo3", [0.0, 1.0, 0.0]),     // different
        ("photo4", [0.01, 0.99, 0.0]),   // very similar to photo3
    ]
    let groups = service.groupBySimilarity(embeddings, threshold: 0.95)
    #expect(groups.count == 2)
}
