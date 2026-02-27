import Testing
import Vision
@testable import iPhoneCleaner

@Test func bucketedGroupingMatchesBruteForce() throws {
    let service = ImageAnalysisService()
    let items: [(id: String, embedding: [Float])] = [
        ("a", [1.0, 0.0, 0.0, 0.0]),
        ("b", [0.99, 0.01, 0.0, 0.0]),
        ("c", [0.0, 1.0, 0.0, 0.0]),
        ("d", [0.01, 0.99, 0.0, 0.0]),
        ("e", [0.0, 0.0, 1.0, 0.0]),
    ]

    let bruteForce = service.groupBySimilarity(items, threshold: 0.95)
    let bucketed = service.groupBySimilarityBucketed(items, threshold: 0.95)

    #expect(bruteForce.count == bucketed.count)
    #expect(bruteForce.count == 2)
}

@Test func bucketedGroupingPerformanceAt1000() throws {
    let service = ImageAnalysisService()
    var items: [(id: String, embedding: [Float])] = []
    for i in 0..<1000 {
        var embedding = (0..<128).map { _ in Float.random(in: -1...1) }
        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if norm > 0 { embedding = embedding.map { $0 / norm } }
        items.append(("photo_\(i)", embedding))
    }

    let start = ContinuousClock.now
    let _ = service.groupBySimilarityBucketed(items, threshold: 0.95)
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(2))
}
