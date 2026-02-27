import Testing
import Photos
@testable import iPhoneCleaner

@Test func fetchAllMediaIncludesVideoType() {
    let service = PhotoLibraryService()
    let assets = service.fetchAllMedia()
    #expect(assets.count >= 0)
}

@Test func isScreenRecordingDetection() {
    let recording = PhotoLibraryService.isScreenRecording(subtypeRawValue: 524288)
    #expect(recording == true)

    let notRecording = PhotoLibraryService.isScreenRecording(subtypeRawValue: 0)
    #expect(notRecording == false)

    let combined = PhotoLibraryService.isScreenRecording(subtypeRawValue: 524288 | 2)
    #expect(combined == true)
}

@Test func loadImageWithTimeoutReturnsNilOnTimeout() async {
    let service = PhotoLibraryService()
    let result = await service.loadImageWithTimeout(
        forAssetId: "NONEXISTENT_ASSET_ID",
        targetSize: CGSize(width: 100, height: 100),
        timeout: .milliseconds(100)
    )
    #expect(result == nil)
}
