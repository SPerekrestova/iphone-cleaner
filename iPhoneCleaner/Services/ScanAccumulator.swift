import Foundation
@preconcurrency import Vision

struct AssetScanResult: Sendable {
    struct IssueData: Sendable {
        let assetId: String
        let category: IssueCategory
        let confidence: Double
        let fileSize: Int64
        let userDecision: UserDecision
        let groupId: String?
        let sceneTags: [String]?
        let aestheticsScore: Float?
        let isVideo: Bool
    }

    let issues: [IssueData]
    let featurePrint: (id: String, print: VNFeaturePrintObservation)?
}

actor ScanAccumulator {
    private var processed = 0
    private var categoryCounts: [IssueCategory: Int] = [:]
    private var issues: [AssetScanResult.IssueData] = []
    private var featurePrints: [(id: String, print: VNFeaturePrintObservation)] = []

    func addResult(_ result: AssetScanResult) {
        processed += 1
        for issue in result.issues {
            issues.append(issue)
            categoryCounts[issue.category, default: 0] += 1
        }
        if let fp = result.featurePrint {
            featurePrints.append(fp)
        }
    }

    func snapshot() -> (Int, [IssueCategory: Int]) {
        (processed, categoryCounts)
    }

    func finalize() -> ([AssetScanResult.IssueData], [(id: String, print: VNFeaturePrintObservation)]) {
        (issues, featurePrints)
    }
}
