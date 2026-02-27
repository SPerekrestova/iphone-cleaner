import XCTest
import UIKit
@testable import iPhoneCleaner

final class PerformanceTests: XCTestCase {

    private let service = ImageAnalysisService()

    private func makeSolidImage(size: CGSize = CGSize(width: 512, height: 512)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testBlurScoreThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<10 {
                _ = try? service.blurScore(for: image)
            }
        }
    }

    func testFeaturePrintGenerationThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.generateFeaturePrint(for: image)
            }
        }
    }

    func testTextCoverageThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.textCoverage(for: image)
            }
        }
    }

    func testSceneClassificationThroughput() throws {
        let image = makeSolidImage()
        measure {
            for _ in 0..<5 {
                _ = try? service.classifyScene(for: image, topK: 5)
            }
        }
    }

    func testSimilarityGrouping100() {
        let items = makeRandomEmbeddings(count: 100, dim: 128)
        measure {
            _ = service.groupBySimilarity(items, threshold: 0.95)
        }
    }

    func testSimilarityGrouping500() {
        let items = makeRandomEmbeddings(count: 500, dim: 128)
        measure {
            _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
        }
    }

    func testSimilarityGrouping1000() {
        let items = makeRandomEmbeddings(count: 1000, dim: 128)
        measure {
            _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
        }
    }

    private func makeRandomEmbeddings(count: Int, dim: Int) -> [(id: String, embedding: [Float])] {
        (0..<count).map { i in
            var emb = (0..<dim).map { _ in Float.random(in: -1...1) }
            let norm = sqrt(emb.reduce(0) { $0 + $1 * $1 })
            if norm > 0 { emb = emb.map { $0 / norm } }
            return ("photo_\(i)", emb)
        }
    }
}
