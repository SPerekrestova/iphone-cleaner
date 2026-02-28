import XCTest

final class iPhoneCleanerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Helper for seeded tests

    private func launchWithSeedData() {
        app.terminate()
        app.launchArguments = ["UI_TESTING_SEED_DATA"]
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

    // MARK: - Category Navigation Tests

    func testCategoryCardsDisplayAfterScan() {
        launchWithSeedData()

        let duplicatesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Duplicates'")
        ).firstMatch
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 3),
                       "Duplicates category card should appear with seeded scan data")

        let blurryCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Blurry'")
        ).firstMatch
        XCTAssertTrue(blurryCard.waitForExistence(timeout: 2),
                       "Blurry category card should appear with seeded scan data")

        let screenshotsCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Screenshots'")
        ).firstMatch
        XCTAssertTrue(screenshotsCard.waitForExistence(timeout: 2),
                       "Screenshots category card should appear with seeded scan data")
    }

    func testTapCategoryCardOpensReviewSheet() {
        launchWithSeedData()

        let duplicatesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Duplicates'")
        ).firstMatch
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 3))

        duplicatesCard.tap()

        // ReviewView should appear with the category title in the navigation bar
        let reviewNavBar = app.navigationBars["Duplicates"]
        XCTAssertTrue(reviewNavBar.waitForExistence(timeout: 3),
                       "Tapping a category card should open the review sheet with category title")

        // Should show progress text
        let progressText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'of 3'")
        ).firstMatch
        XCTAssertTrue(progressText.waitForExistence(timeout: 2),
                       "Review sheet should show issue count")

        // Done button should be available
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button should be available to dismiss review sheet")
    }

    func testTapDifferentCategoryOpensCorrectReview() {
        launchWithSeedData()

        let screenshotsCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Screenshots'")
        ).firstMatch
        XCTAssertTrue(screenshotsCard.waitForExistence(timeout: 3))

        screenshotsCard.tap()

        let reviewNavBar = app.navigationBars["Screenshots"]
        XCTAssertTrue(reviewNavBar.waitForExistence(timeout: 3),
                       "Tapping Screenshots card should open review with Screenshots title")

        let progressText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'of 5'")
        ).firstMatch
        XCTAssertTrue(progressText.waitForExistence(timeout: 2),
                       "Screenshots review should show 5 issues")
    }

    func testDismissReviewSheetReturnsToCategoryList() {
        launchWithSeedData()

        let duplicatesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Duplicates'")
        ).firstMatch
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 3))

        duplicatesCard.tap()

        let reviewNavBar = app.navigationBars["Duplicates"]
        XCTAssertTrue(reviewNavBar.waitForExistence(timeout: 3))

        // Dismiss
        app.buttons["Done"].tap()

        // Should return to main view with category cards still visible
        let mainNavBar = app.navigationBars["iPhone Cleaner"]
        XCTAssertTrue(mainNavBar.waitForExistence(timeout: 3),
                       "Dismissing review should return to main screen")
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 2),
                       "Category cards should still be visible after dismissing review")
    }

    // MARK: - Review Flow Tests

    func testSkipThroughAllItemsShowsAllReviewed() {
        launchWithSeedData()

        // Open Blurry category (2 items — easiest to skip through)
        let blurryCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Blurry'")
        ).firstMatch
        XCTAssertTrue(blurryCard.waitForExistence(timeout: 3))
        blurryCard.tap()

        let reviewNavBar = app.navigationBars["Blurry"]
        XCTAssertTrue(reviewNavBar.waitForExistence(timeout: 3))

        // Skip through both items using the forward button
        let skipButton = app.buttons["Forward"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 2))

        skipButton.tap()
        sleep(1)
        skipButton.tap()
        sleep(1)

        // "All reviewed!" should appear
        let allReviewed = app.staticTexts["All reviewed!"]
        XCTAssertTrue(allReviewed.waitForExistence(timeout: 3),
                       "After skipping all items, 'All reviewed!' should appear")
    }

    func testProgressTextNotBogusAfterAllReviewed() {
        launchWithSeedData()

        // Open Blurry category (2 items)
        let blurryCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Blurry'")
        ).firstMatch
        XCTAssertTrue(blurryCard.waitForExistence(timeout: 3))
        blurryCard.tap()

        XCTAssertTrue(app.navigationBars["Blurry"].waitForExistence(timeout: 3))

        // Verify initial progress text is "1 of 2"
        let initialProgress = app.staticTexts["1 of 2"]
        XCTAssertTrue(initialProgress.waitForExistence(timeout: 2),
                       "Initial progress should show '1 of 2'")

        // Skip both items
        let skipButton = app.buttons["Forward"]
        skipButton.tap()
        sleep(1)

        // After first skip, should show "2 of 2"
        let secondProgress = app.staticTexts["2 of 2"]
        XCTAssertTrue(secondProgress.waitForExistence(timeout: 2),
                       "After first skip, progress should show '2 of 2'")

        skipButton.tap()
        sleep(1)

        // After all reviewed, progress should NOT show "3 of 2"
        let bogusProgress = app.staticTexts["3 of 2"]
        XCTAssertFalse(bogusProgress.exists,
                        "Progress text should NOT show '3 of 2' after all items reviewed")
    }

    func testOpenCategoryDismissThenOpenDifferentCategory() {
        launchWithSeedData()

        // Open Duplicates first
        let duplicatesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Duplicates'")
        ).firstMatch
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 3))
        duplicatesCard.tap()

        XCTAssertTrue(app.navigationBars["Duplicates"].waitForExistence(timeout: 3))

        // Dismiss
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["iPhone Cleaner"].waitForExistence(timeout: 3))

        // Now open Screenshots
        let screenshotsCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Screenshots'")
        ).firstMatch
        XCTAssertTrue(screenshotsCard.waitForExistence(timeout: 3))
        screenshotsCard.tap()

        // Should show Screenshots, not Duplicates
        let screenshotsNavBar = app.navigationBars["Screenshots"]
        XCTAssertTrue(screenshotsNavBar.waitForExistence(timeout: 3),
                       "Opening a different category after dismissing should show correct title")

        let progressText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'of 5'")
        ).firstMatch
        XCTAssertTrue(progressText.waitForExistence(timeout: 2),
                       "Second category should show its own issue count")
    }

    func testDeleteAllButtonShowsConfirmationAlert() {
        launchWithSeedData()

        let duplicatesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Duplicates'")
        ).firstMatch
        XCTAssertTrue(duplicatesCard.waitForExistence(timeout: 3))
        duplicatesCard.tap()

        XCTAssertTrue(app.navigationBars["Duplicates"].waitForExistence(timeout: 3))

        // Tap Delete All button
        let deleteAllButton = app.buttons["Delete All"]
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 2))
        deleteAllButton.tap()

        // Should show confirmation alert
        let alert = app.alerts["Delete Photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                       "Tapping Delete All should show confirmation alert")

        // Cancel should dismiss the alert
        alert.buttons["Cancel"].tap()
        XCTAssertFalse(alert.exists, "Cancel should dismiss the alert")
    }
}
