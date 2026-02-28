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

// Note: salientRegionBlurScore end-to-end only fully runs on-device (Neural Engine required)
@Test func salientRegionBlurScoreForSharpImage() throws {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
    let image = renderer.image { ctx in
        for row in 0..<20 {
            for col in 0..<20 {
                let color: UIColor = (row + col) % 2 == 0 ? .white : .black
                color.setFill()
                ctx.fill(CGRect(x: col * 10, y: row * 10, width: 10, height: 10))
            }
        }
    }
    let service = ImageAnalysisService()
    do {
        let score = try service.salientRegionBlurScore(for: image)
        #expect(score > 0.3, "Sharp checkerboard image should have saliency blur score > 0.3, got \(score)")
    } catch {
        // Saliency request needs Neural Engine — skip on simulator
    }
}

// MARK: - croppedToSalientRegion (pure logic, runs on simulator)

@Test func croppedToSalientRegionYFlipAndDimensions() {
    // Use scale:1 to get predictable pixel dimensions
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format)
    let image = renderer.image { ctx in
        UIColor.blue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
    }
    let cgImage = image.cgImage!
    let service = ImageAnalysisService()

    // bbox: origin (0.0, 0.0), size (0.5, 0.5) in Vision coords (origin bottom-left)
    // After Y-flip: y = (1.0 - 0.0 - 0.5) * 200 = 100
    // Pixel rect = (0, 100, 50, 100)
    let bbox = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)
    let cropped = service.croppedToSalientRegion(cgImage, boundingBox: bbox)

    #expect(cropped != nil, "Should produce a cropped image")
    #expect(cropped!.width == 50, "Cropped width should be 50, got \(cropped!.width)")
    #expect(cropped!.height == 100, "Cropped height should be 100, got \(cropped!.height)")
}

@Test func croppedToSalientRegionFullImage() {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80), format: format)
    let image = renderer.image { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
    }
    let cgImage = image.cgImage!
    let service = ImageAnalysisService()

    let bbox = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
    let cropped = service.croppedToSalientRegion(cgImage, boundingBox: bbox)

    #expect(cropped != nil)
    #expect(cropped!.width == 80)
    #expect(cropped!.height == 80)
}

@Test func croppedToSalientRegionCenterQuadrant() {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format)
    let image = renderer.image { ctx in
        UIColor.green.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
    }
    let cgImage = image.cgImage!
    let service = ImageAnalysisService()

    // Vision bbox: origin (0.25, 0.25), size (0.5, 0.5)
    // After Y-flip: y = (1.0 - 0.25 - 0.5) * 200 = 50
    // Pixel rect = (50, 50, 100, 100)
    let bbox = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let cropped = service.croppedToSalientRegion(cgImage, boundingBox: bbox)

    #expect(cropped != nil)
    #expect(cropped!.width == 100, "Center crop width should be 100, got \(cropped!.width)")
    #expect(cropped!.height == 100, "Center crop height should be 100, got \(cropped!.height)")
}

@Test func salientRegionBlurScoreFallbackForNilCGImage() throws {
    // UIImage with no cgImage should return 0.0 (the guard fallback)
    let service = ImageAnalysisService()
    let emptyImage = UIImage()
    let score = try service.salientRegionBlurScore(for: emptyImage)
    #expect(score == 0.0, "Should return 0.0 for image with no CGImage backing")
}
