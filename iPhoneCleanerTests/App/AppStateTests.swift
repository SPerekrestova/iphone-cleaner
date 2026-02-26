import Testing
import Foundation
@testable import iPhoneCleaner

@Test func appStateInitialValues() {
    let state = AppState()
    #expect(state.scanSettings.blurThreshold == 0.3)
    #expect(state.scanSettings.batchSize == 30)
    #expect(state.storageUsed == 0)
    #expect(state.storageTotal == 0)
    #expect(state.lastScanResult == nil)
}

@Test func appStateStorageFraction() {
    let state = AppState()
    state.storageUsed = 50_000_000_000
    state.storageTotal = 100_000_000_000
    #expect(state.storageFraction == 0.5)
}

@Test func appStateStorageFractionZeroTotal() {
    let state = AppState()
    #expect(state.storageFraction == 0.0)
}

@Test func appStateLoadStorageInfo() {
    let state = AppState()
    state.loadStorageInfo()
    #expect(state.storageTotal > 0)
    #expect(state.storageUsed > 0)
}
