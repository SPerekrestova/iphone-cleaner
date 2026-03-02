import Testing
@testable import iPhoneCleaner

@Test func accumulatorStartsEmpty() async {
    let acc = ScanAccumulator()
    let (processed, counts) = await acc.snapshot()
    #expect(processed == 0)
    #expect(counts.isEmpty)
}

@Test func accumulatorAccumulatesResults() async {
    let acc = ScanAccumulator()
    let issueData = AssetScanResult.IssueData(
        assetId: "test-1", category: .blurry,
        confidence: 0.9, fileSize: 1024,
        userDecision: .pending, groupId: nil,
        sceneTags: nil, aestheticsScore: nil, isVideo: false
    )
    let result = AssetScanResult(issues: [issueData], featurePrint: nil)
    await acc.addResult(result)

    let (processed, counts) = await acc.snapshot()
    #expect(processed == 1)
    #expect(counts[.blurry] == 1)
}

@Test func accumulatorThreadSafetyWith100ConcurrentAdds() async {
    let acc = ScanAccumulator()
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                let issueData = AssetScanResult.IssueData(
                    assetId: "asset-\(i)", category: .screenshot,
                    confidence: 1.0, fileSize: 500,
                    userDecision: .pending, groupId: nil,
                    sceneTags: nil, aestheticsScore: nil, isVideo: false
                )
                let result = AssetScanResult(issues: [issueData], featurePrint: nil)
                await acc.addResult(result)
            }
        }
    }
    let (processed, counts) = await acc.snapshot()
    #expect(processed == 100)
    #expect(counts[.screenshot] == 100)
}

@Test func accumulatorFinalizeReturnsAllData() async {
    let acc = ScanAccumulator()
    let issue1 = AssetScanResult.IssueData(
        assetId: "a", category: .blurry, confidence: 0.8, fileSize: 100,
        userDecision: .pending, groupId: nil,
        sceneTags: nil, aestheticsScore: nil, isVideo: false
    )
    let issue2 = AssetScanResult.IssueData(
        assetId: "b", category: .screenshot, confidence: 1.0, fileSize: 200,
        userDecision: .pending, groupId: nil,
        sceneTags: nil, aestheticsScore: nil, isVideo: false
    )
    await acc.addResult(AssetScanResult(issues: [issue1], featurePrint: nil))
    await acc.addResult(AssetScanResult(issues: [issue2], featurePrint: nil))

    let (issues, featurePrints) = await acc.finalize()
    #expect(issues.count == 2)
    #expect(featurePrints.isEmpty)
}
