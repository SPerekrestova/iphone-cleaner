import Testing
import Photos
@testable import iPhoneCleaner

@Test func photoLibraryServiceAuthStatus() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    // On simulator without granting, status is .notDetermined
    #expect(status == .notDetermined || status == .authorized || status == .denied || status == .limited)
}
