import XCTest

final class iPhoneCleanerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunchesWithPhotosTab() {
        let photosTab = app.tabBars.buttons["Photos"]
        XCTAssertTrue(photosTab.exists)
        XCTAssertTrue(photosTab.isSelected)
    }

    func testSettingsTabExists() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    func testAppsTabDoesNotExist() {
        let appsTab = app.tabBars.buttons["Apps"]
        XCTAssertFalse(appsTab.exists)
    }

    func testScanButtonExists() {
        let scanButton = app.buttons["Scan Photos"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 2))
    }

    func testStorageRingDisplayed() {
        let ofText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of'")).firstMatch
        XCTAssertTrue(ofText.waitForExistence(timeout: 3))
    }

    func testSettingsSlidersExist() {
        app.tabBars.buttons["Settings"].tap()
        let blurSlider = app.sliders.firstMatch
        XCTAssertTrue(blurSlider.waitForExistence(timeout: 2))
    }

    func testSettingsPrivacyInfo() {
        app.tabBars.buttons["Settings"].tap()
        let privacyText = app.staticTexts["All processing happens on your device"]
        XCTAssertTrue(privacyText.waitForExistence(timeout: 2))
    }

    func testNavigationTitle() {
        XCTAssertTrue(app.navigationBars["iPhone Cleaner"].waitForExistence(timeout: 2))
    }
}
