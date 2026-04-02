import XCTest

class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--disable-animations")
        setupSnapshot(app)
        app.launch()
    }

    @MainActor
    func testDemoHomeScreenshots() {
        // Wait for app to load
        let dashboardsTab = app.buttons["Dashboards"].firstMatch
        XCTAssertTrue(dashboardsTab.waitForExistence(timeout: 10), "Expected Dashboards tab")

        // 1. Dashboards list
        dashboardsTab.tap()
        sleep(2) // Wait for demo data to load
        snapshot(ScreenshotIds.DASHBOARDS)

        // 2. Climate dashboard
        let climate = app.staticTexts["Climate"].firstMatch
        if climate.waitForExistence(timeout: 5) {
            climate.tap()
            sleep(3) // Wait for charts to render
            snapshot(ScreenshotIds.CLIMATE)

            // 3. Explorer — long press first panel to open context menu
            let exploreButton = app.buttons["Explore"].firstMatch
            if exploreButton.waitForExistence(timeout: 3) {
                exploreButton.tap()
                sleep(2)
                snapshot(ScreenshotIds.EXPLORER)

                // Close explorer
                let closeButton = app.buttons["Close"].firstMatch
                if closeButton.waitForExistence(timeout: 3) {
                    closeButton.tap()
                }
            }

            // Navigate back to dashboard list
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // 4. Energy dashboard
        let energy = app.staticTexts["Energy"].firstMatch
        if energy.waitForExistence(timeout: 5) {
            energy.tap()
            sleep(3)
            snapshot(ScreenshotIds.ENERGY)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // 5. Widgets tab
        let widgetsTab = app.buttons["Widgets"].firstMatch
        if widgetsTab.waitForExistence(timeout: 5) {
            widgetsTab.tap()
            sleep(2)
            snapshot(ScreenshotIds.WIDGETS)
        }

        // 6. Data Sources tab
        let dataSourcesTab = app.buttons["Data Sources"].firstMatch
        if dataSourcesTab.waitForExistence(timeout: 5) {
            dataSourcesTab.tap()
            sleep(1)
            snapshot(ScreenshotIds.DATA_SOURCES)
        }

        // 7. About tab
        let aboutTab = app.buttons["About"].firstMatch
        if aboutTab.waitForExistence(timeout: 5) {
            aboutTab.tap()
            sleep(1)
            snapshot(ScreenshotIds.ABOUT)
        }
    }
}
