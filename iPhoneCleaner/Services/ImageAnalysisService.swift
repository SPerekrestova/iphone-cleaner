import UIKit
import Vision
import Accelerate
import CoreImage

final class ImageAnalysisService {

    // MARK: - Blur Detection

    func blurScore(for image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }

        let ciImage = CIImage(cgImage: cgImage)
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // Use Laplacian variance as blur metric
        let laplacianKernel: [Float] = [
            0,  1, 0,
            1, -4, 1,
            0,  1, 0
        ]

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(grayscale, from: grayscale.extent) else {
            return 0.0
        }

        guard let pixelData = outputCGImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return 0.0
        }

        let width = outputCGImage.width
        let height = outputCGImage.height
        let bytesPerPixel = outputCGImage.bitsPerPixel / 8

        var pixels = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * outputCGImage.bytesPerRow) + (x * bytesPerPixel)
                pixels[y * width + x] = Float(data[offset])
            }
        }

        // Apply Laplacian convolution
        var variance: Float = 0
        var count = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var laplacian: Float = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let px = pixels[(y + ky) * width + (x + kx)]
                        let k = laplacianKernel[(ky + 1) * 3 + (kx + 1)]
                        laplacian += px * k
                    }
                }
                variance += laplacian * laplacian
                count += 1
            }
        }

        let meanVariance = count > 0 ? Double(variance) / Double(count) : 0
        // Normalize: high variance = sharp, low = blurry
        // Typical range: 0-5000+. Map to 0-1 where 1 = perfectly sharp
        let sharpnessScore = min(meanVariance / 2000.0, 1.0)
        return sharpnessScore
    }

    // Returns true if score < threshold (image is blurry)
    func isBlurry(_ image: UIImage, threshold: Double = 0.3) throws -> Bool {
        let score = try blurScore(for: image)
        return score < threshold
    }

    // MARK: - Screenshot Detection

    /// Known iPhone screen resolutions (width x height, portrait)
    private static let iPhoneResolutions: Set<String> = [
        "1170x2532", "1179x2556", "1290x2796", // iPhone 14/15/16 Pro etc.
        "1125x2436", "828x1792", "1242x2688",   // iPhone X/XR/XS Max
        "750x1334", "1080x1920", "640x1136",     // iPhone 6/7/8, SE
        "1284x2778",                              // iPhone 12/13 Pro Max
    ]

    func isScreenshotByHeuristic(pixelWidth: Int, pixelHeight: Int, hasCameraMetadata: Bool) -> Bool {
        if hasCameraMetadata { return false }
        let key = "\(min(pixelWidth, pixelHeight))x\(max(pixelWidth, pixelHeight))"
        return Self.iPhoneResolutions.contains(key)
    }

    // MARK: - Image Embeddings (Vision Feature Print)

    func generateFeaturePrint(for image: UIImage) throws -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return request.results?.first
    }

    func featurePrintDistance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try a.computeDistance(&distance, to: b)
        return distance
    }

    // MARK: - Cosine Similarity (for custom embeddings)

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0.0 }
        return dotProduct / denominator
    }

    // MARK: - Grouping

    func groupBySimilarity(_ items: [(id: String, embedding: [Float])], threshold: Float) -> [[String]] {
        var visited = Set<Int>()
        var groups: [[String]] = []

        for i in 0..<items.count {
            if visited.contains(i) { continue }
            var group = [items[i].id]
            visited.insert(i)

            for j in (i + 1)..<items.count {
                if visited.contains(j) { continue }
                let sim = Self.cosineSimilarity(items[i].embedding, items[j].embedding)
                if sim >= threshold {
                    group.append(items[j].id)
                    visited.insert(j)
                }
            }

            if group.count > 1 {
                groups.append(group)
            }
        }

        return groups
    }

    // MARK: - Bucketed Similarity Grouping

    func groupBySimilarityBucketed(
        _ items: [(id: String, embedding: [Float])],
        threshold: Float,
        numBuckets: Int = 32
    ) -> [[String]] {
        guard items.count > 1, let dim = items.first?.embedding.count, dim > 0 else { return [] }

        // For small sets, brute force is fine
        if items.count < 200 {
            return groupBySimilarity(items, threshold: threshold)
        }

        // Generate random projection vectors for bucketing
        let numProjections = min(8, dim)
        var projections: [[Float]] = []
        for _ in 0..<numProjections {
            let proj = (0..<dim).map { _ in Float.random(in: -1...1) }
            let norm = sqrt(proj.reduce(0) { $0 + $1 * $1 })
            projections.append(proj.map { $0 / norm })
        }

        // Assign each item a hash based on sign of dot products with projections
        func hashKey(_ embedding: [Float]) -> Int {
            var key = 0
            for (i, proj) in projections.enumerated() {
                var dot: Float = 0
                for j in 0..<dim {
                    dot += embedding[j] * proj[j]
                }
                if dot >= 0 { key |= (1 << i) }
            }
            return key
        }

        // Build buckets
        var buckets: [Int: [Int]] = [:]
        for (i, item) in items.enumerated() {
            let key = hashKey(item.embedding)
            buckets[key, default: []].append(i)
        }

        // Compare within each bucket
        var visited = Set<Int>()
        var groups: [[String]] = []

        for (_, indices) in buckets {
            for i in indices {
                if visited.contains(i) { continue }
                var group = [items[i].id]
                visited.insert(i)

                for j in indices {
                    if visited.contains(j) || i == j { continue }
                    let sim = Self.cosineSimilarity(items[i].embedding, items[j].embedding)
                    if sim >= threshold {
                        group.append(items[j].id)
                        visited.insert(j)
                    }
                }

                if group.count > 1 {
                    groups.append(group)
                }
            }
        }

        return groups
    }

    func groupByFeaturePrint(_ prints: [(id: String, print: VNFeaturePrintObservation)], maxDistance: Float) -> [[String]] {
        var visited = Set<Int>()
        var groups: [[String]] = []

        for i in 0..<prints.count {
            if visited.contains(i) { continue }
            var group = [prints[i].id]
            visited.insert(i)

            for j in (i + 1)..<prints.count {
                if visited.contains(j) { continue }
                do {
                    let dist = try featurePrintDistance(prints[i].print, prints[j].print)
                    if dist <= maxDistance {
                        group.append(prints[j].id)
                        visited.insert(j)
                    }
                } catch {
                    continue
                }
            }

            if group.count > 1 {
                groups.append(group)
            }
        }

        return groups
    }

    // MARK: - Saliency-Weighted Blur Detection

    /// Crops a CGImage to the given Vision normalized bounding box (origin bottom-left, 0-1).
    func croppedToSalientRegion(_ cgImage: CGImage, boundingBox: CGRect) -> CGImage? {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: boundingBox.origin.x * w,
            y: (1.0 - boundingBox.origin.y - boundingBox.height) * h,
            width: boundingBox.width * w,
            height: boundingBox.height * h
        )
        return cgImage.cropping(to: cropRect)
    }

    func salientRegionBlurScore(for image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }

        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([saliencyRequest])

        guard let observation = saliencyRequest.results?.first,
              let salientObject = observation.salientObjects?.first else {
            return try blurScore(for: image)
        }

        guard let cropped = croppedToSalientRegion(cgImage, boundingBox: salientObject.boundingBox) else {
            return try blurScore(for: image)
        }

        return try blurScore(for: UIImage(cgImage: cropped))
    }

    // MARK: - Text Coverage (VNRecognizeTextRequest)

    func textCoverage(for image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let totalArea = (request.results ?? []).reduce(0.0) { sum, obs in
            let box = obs.boundingBox
            return sum + Double(box.width * box.height)
        }
        return min(totalArea, 1.0)
    }

    // MARK: - Scene Classification (VNClassifyImageRequest)

    func classifyScene(for image: UIImage, topK: Int = 5) throws -> [(label: String, confidence: Float)] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // VNClassifyImageRequest requires Neural Engine; fails on simulator
            return []
        }

        return (request.results ?? [])
            .sorted { $0.confidence > $1.confidence }
            .prefix(topK)
            .map { ($0.identifier, $0.confidence) }
    }

    // MARK: - Face Capture Quality

    func faceCaptureQuality(for image: UIImage) throws -> Float? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // VNDetectFaceCaptureQualityRequest requires Neural Engine; fails on simulator
            return nil
        }
        return request.results?.first?.faceCaptureQuality
    }

    // MARK: - Image Aesthetics (iOS 18+)

    func aestheticsScore(for image: UIImage) async -> (score: Float, isUtility: Bool)? {
        guard let ciImage = CIImage(image: image) else { return nil }
        do {
            if #available(iOS 18.0, *) {
                let request = CalculateImageAestheticsScoresRequest()
                let observation = try await request.perform(on: ciImage)
                return (observation.overallScore, observation.isUtility)
            }
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Lens Smudge Detection (iOS 26+)

    func lensSmudgeConfidence(for image: UIImage) async -> Float? {
        guard let ciImage = CIImage(image: image) else { return nil }
        do {
            if #available(iOS 26.0, *) {
                let request = DetectLensSmudgeRequest()
                let observation = try await request.perform(on: ciImage)
                return observation.confidence
            }
            return nil
        } catch {
            return nil
        }
    }
}
