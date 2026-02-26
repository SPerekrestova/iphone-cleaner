import Testing
import UIKit
@testable import iPhoneCleaner

// Test image helpers
private func makeSolidImage(color: UIColor, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

private func makeTextImage(text: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let lines = Array(repeating: text, count: 10).joined(separator: "\n")
        (lines as NSString).draw(in: CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20), withAttributes: attrs)
    }
}

@Test func textCoverageDetectsTextHeavyImage() throws {
    let service = ImageAnalysisService()
    let textImage = makeTextImage(text: "Receipt: $42.99 tax included")
    let coverage = try service.textCoverage(for: textImage)
    #expect(coverage > 0.05)
}

@Test func textCoverageMinimalForSolidImage() throws {
    let service = ImageAnalysisService()
    let solid = makeSolidImage(color: .blue)
    let coverage = try service.textCoverage(for: solid)
    #expect(coverage < 0.01)
}

@Test func classifySceneReturnsLabels() throws {
    let service = ImageAnalysisService()
    let image = makeSolidImage(color: .green, size: CGSize(width: 300, height: 300))
    let tags = try service.classifyScene(for: image, topK: 5)
    #expect(tags.count <= 5)
}

@Test func faceCaptureQualityReturnsNilForNoFaces() throws {
    let service = ImageAnalysisService()
    let solid = makeSolidImage(color: .red)
    let quality = try service.faceCaptureQuality(for: solid)
    #expect(quality == nil)
}
