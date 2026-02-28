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

    /// Opens a category review sheet using accessibility identifier.
    /// Returns the nav bar element for the opened category.
    private func openCategory(_ category: String, identifier: String) -> XCUIElement {
        let card = app.buttons[identifier]
        XCTAssertTrue(card.waitForExistence(timeout: 3), "\(category) card should exist")
        card.tap()
        let navBar = app.navigationBars[category]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3), "\(category) review should open")
        return navBar
    }

    // MARK: - Basic Launch Tests

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
        let scanButton = app.buttons["scanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 2))
    }

    func testStorageRingDisplayed() {
        let ring = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Storage:'")
        ).firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 3),
                       "Storage ring should be displayed with accessibility label")
    }

    func testSettingsSlidersExist() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.sliders["blurThresholdSlider"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.sliders["similarThresholdSlider"].exists)
        XCTAssertTrue(app.sliders["textCoverageSlider"].exists)
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

        XCTAssertTrue(app.buttons["categoryCard_duplicate"].waitForExistence(timeout: 3),
                       "Duplicates category card should appear")
        XCTAssertTrue(app.buttons["categoryCard_blurry"].waitForExistence(timeout: 2),
                       "Blurry category card should appear")
        XCTAssertTrue(app.buttons["categoryCard_screenshot"].waitForExistence(timeout: 2),
                       "Screenshots category card should appear")
    }

    func testTapCategoryCardOpensReviewSheet() {
        launchWithSeedData()

        _ = openCategory("Duplicates", identifier: "categoryCard_duplicate")

        // Should show progress text via identifier
        let progress = app.staticTexts["reviewProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2),
                       "Review progress text should be visible")
        XCTAssertEqual(progress.label, "1 of 3",
                        "Should show '1 of 3' for duplicates")

        // Done button should be available
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testTapDifferentCategoryOpensCorrectReview() {
        launchWithSeedData()

        _ = openCategory("Screenshots", identifier: "categoryCard_screenshot")

        let progress = app.staticTexts["reviewProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertEqual(progress.label, "1 of 5",
                        "Screenshots review should show '1 of 5'")
    }

    func testDismissReviewSheetReturnsToCategoryList() {
        launchWithSeedData()

        _ = openCategory("Duplicates", identifier: "categoryCard_duplicate")

        app.buttons["Done"].tap()

        XCTAssertTrue(app.navigationBars["iPhone Cleaner"].waitForExistence(timeout: 3),
                       "Dismissing review should return to main screen")
        XCTAssertTrue(app.buttons["categoryCard_duplicate"].waitForExistence(timeout: 2),
                       "Category cards should still be visible")
    }

    // MARK: - Review Flow Tests

    func testSkipThroughAllItemsShowsAllReviewed() {
        launchWithSeedData()

        _ = openCategory("Blurry", identifier: "categoryCard_blurry")

        let skipButton = app.buttons["skipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 2))

        skipButton.tap()
        sleep(1)
        skipButton.tap()
        sleep(1)

        let allReviewed = app.staticTexts["allReviewedText"]
        XCTAssertTrue(allReviewed.waitForExistence(timeout: 3),
                       "After skipping all items, 'All reviewed!' should appear")
    }

    func testProgressTextNotBogusAfterAllReviewed() {
        launchWithSeedData()

        _ = openCategory("Blurry", identifier: "categoryCard_blurry")

        let progress = app.staticTexts["reviewProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertEqual(progress.label, "1 of 2")

        let skipButton = app.buttons["skipButton"]
        skipButton.tap()
        sleep(1)

        XCTAssertEqual(progress.label, "2 of 2",
                        "After first skip, progress should show '2 of 2'")

        skipButton.tap()
        sleep(1)

        // After all reviewed, should still show "2 of 2" (clamped), not "3 of 2"
        XCTAssertEqual(progress.label, "2 of 2",
                        "Progress text should be clamped to '2 of 2' after all items reviewed")
    }

    func testOpenCategoryDismissThenOpenDifferentCategory() {
        launchWithSeedData()

        _ = openCategory("Duplicates", identifier: "categoryCard_duplicate")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["iPhone Cleaner"].waitForExistence(timeout: 3))

        _ = openCategory("Screenshots", identifier: "categoryCard_screenshot")

        let progress = app.staticTexts["reviewProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertEqual(progress.label, "1 of 5",
                        "Second category should show its own issue count")
    }

    func testDeleteAllButtonShowsConfirmationAlert() {
        launchWithSeedData()

        _ = openCategory("Duplicates", identifier: "categoryCard_duplicate")

        let deleteAllButton = app.buttons["deleteAllButton"]
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 2))
        deleteAllButton.tap()

        let alert = app.alerts["Delete Photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                       "Tapping Delete All should show confirmation alert")

        alert.buttons["Cancel"].tap()
        XCTAssertFalse(alert.exists, "Cancel should dismiss the alert")
    }

    // MARK: - Undo Flow Tests

    func testUndoButtonDisabledInitially() {
        launchWithSeedData()

        _ = openCategory("Blurry", identifier: "categoryCard_blurry")

        let undoButton = app.buttons["undoButton"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 2))
        XCTAssertFalse(undoButton.isEnabled,
                        "Undo button should be disabled when no actions taken")
    }

    func testUndoAfterSkipRestoresPreviousCard() {
        launchWithSeedData()

        _ = openCategory("Blurry", identifier: "categoryCard_blurry")

        let progress = app.staticTexts["reviewProgress"]
        XCTAssertEqual(progress.label, "1 of 2")

        // Skip first item
        let skipButton = app.buttons["skipButton"]
        skipButton.tap()
        sleep(1)
        XCTAssertEqual(progress.label, "2 of 2")

        // Undo — should go back to first item
        let undoButton = app.buttons["undoButton"]
        XCTAssertTrue(undoButton.isEnabled, "Undo should be enabled after skip")
        undoButton.tap()
        sleep(1)

        XCTAssertEqual(progress.label, "1 of 2",
                        "Undo should restore progress to previous card")
    }

    func testSkipButtonDisabledAfterAllReviewed() {
        launchWithSeedData()

        _ = openCategory("Blurry", identifier: "categoryCard_blurry")

        let skipButton = app.buttons["skipButton"]
        skipButton.tap()
        sleep(1)
        skipButton.tap()
        sleep(1)

        // Skip should now be disabled
        XCTAssertFalse(skipButton.isEnabled,
                        "Skip button should be disabled after all items reviewed")
    }

    // MARK: - Settings Slider Tests

    func testSettingsSlidersHaveLabels() {
        app.tabBars.buttons["Settings"].tap()

        let blurLabel = app.staticTexts["blurThresholdLabel"]
        XCTAssertTrue(blurLabel.waitForExistence(timeout: 2))
        XCTAssertTrue(blurLabel.label.contains("Blur Threshold:"),
                       "Blur label should show threshold text")

        let similarLabel = app.staticTexts["similarThresholdLabel"]
        XCTAssertTrue(similarLabel.exists)
        XCTAssertTrue(similarLabel.label.contains("Similarity Threshold:"))

        let textLabel = app.staticTexts["textCoverageLabel"]
        XCTAssertTrue(textLabel.exists)
        XCTAssertTrue(textLabel.label.contains("Text Coverage:"))
    }

    func testSettingsSliderInteraction() {
        app.tabBars.buttons["Settings"].tap()

        let blurSlider = app.sliders["blurThresholdSlider"]
        XCTAssertTrue(blurSlider.waitForExistence(timeout: 2))

        let blurLabel = app.staticTexts["blurThresholdLabel"]
        let initialLabel = blurLabel.label

        // Adjust slider to a new position
        blurSlider.adjust(toNormalizedSliderPosition: 0.8)
        sleep(1)

        XCTAssertNotEqual(blurLabel.label, initialLabel,
                           "Blur threshold label should update when slider moves")
    }

    // MARK: - Swipe Card Tests

    func testSwipeCardShowsCategoryAndConfidence() {
        launchWithSeedData()

        _ = openCategory("Duplicates", identifier: "categoryCard_duplicate")

        // Category label on the swipe card
        let categoryLabel = app.staticTexts["swipeCardCategory"]
        XCTAssertTrue(categoryLabel.waitForExistence(timeout: 3),
                       "Swipe card should show category label")

        // Confidence text
        let confidence = app.staticTexts["confidenceText"]
        XCTAssertTrue(confidence.waitForExistence(timeout: 3),
                       "Swipe card should show confidence percentage")
        XCTAssertTrue(confidence.label.contains("% match"),
                       "Confidence should show percentage match")
    }
}
