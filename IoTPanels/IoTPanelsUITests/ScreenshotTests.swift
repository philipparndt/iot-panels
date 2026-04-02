import XCTest

extension XCUIElement {
    func scrollToElement(in app: XCUIApplication, maxSwipes: Int = 10) {
        var attempts = 0
        while !isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }
}

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

            // 3. Scroll down to Temperature Band
            let bandPanel = app.staticTexts["Temperature Band"].firstMatch
            if bandPanel.exists {
                bandPanel.scrollToElement(in: app)
                sleep(2)
                snapshot(ScreenshotIds.CLIMATE_BAND)
                // Scroll back to top for explorer
                app.swipeDown()
                app.swipeDown()
                sleep(1)
            }

            // Explorer — long press first panel to open context menu
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
            // Scroll to the bottom to show all panels
            let batteryPanel = app.staticTexts["Battery"].firstMatch
            if batteryPanel.exists {
                batteryPanel.scrollToElement(in: app)
                sleep(2)
            }
            snapshot(ScreenshotIds.ENERGY)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Widgets tab
        let widgetsTab = app.buttons["Widgets"].firstMatch
        if widgetsTab.waitForExistence(timeout: 5) {
            widgetsTab.tap()
            sleep(2)
            snapshot(ScreenshotIds.WIDGETS)

            // Open widget preview
            let homeOverview = app.staticTexts["Home Overview"].firstMatch
            if homeOverview.waitForExistence(timeout: 3) {
                homeOverview.tap()
                sleep(3) // Wait for preview data to load
                snapshot(ScreenshotIds.WIDGET_PREVIEW)
                app.navigationBars.buttons.element(boundBy: 0).tap()
                sleep(1)
            }
        }

        // 6. Data Sources tab — navigate to Add and show type picker
        let dataSourcesTab = app.buttons["Data Sources"].firstMatch
        if dataSourcesTab.waitForExistence(timeout: 5) {
            dataSourcesTab.tap()
            sleep(1)

            // Open the menu and tap "Add Data Source"
            let menuButton = app.buttons["Menu"].firstMatch
            if menuButton.waitForExistence(timeout: 3) {
                menuButton.tap()
                sleep(1)

                let addButton = app.buttons["Add Data Source"].firstMatch
                if addButton.waitForExistence(timeout: 3) {
                    addButton.tap()
                    sleep(1)

                    // Tap the Type picker to open the menu-style picker
                    let typePicker = app.buttons["backendTypePicker"].firstMatch
                    if typePicker.waitForExistence(timeout: 3) {
                        typePicker.tap()
                        sleep(1)
                    }

                    snapshot(ScreenshotIds.DATA_SOURCES)

                    // Dismiss picker menu by tapping outside, then dismiss sheet
                    app.tap()
                    sleep(1)
                    let cancelButton = app.buttons["Cancel"].firstMatch
                    if cancelButton.waitForExistence(timeout: 3) {
                        cancelButton.tap()
                        sleep(1)
                    }
                }
            }
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
