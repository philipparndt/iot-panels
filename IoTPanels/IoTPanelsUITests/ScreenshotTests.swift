import XCTest

extension XCUIElement {
    func scrollToElement(in app: XCUIApplication, maxSwipes: Int = 10) {
        var attempts = 0
        while !isHittable && attempts < maxSwipes {
            #if os(macOS)
            app.windows.firstMatch.scroll(byDeltaX: 0, deltaY: -100)
            #else
            app.swipeUp()
            #endif
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

    // MARK: - Platform helpers

    /// Select a section by tapping the sidebar item (macOS) or tab button (iOS/iPadOS).
    @MainActor
    private func selectSection(_ name: String) {
        #if os(macOS)
        let item = app.outlines.staticTexts[name].firstMatch
        if item.waitForExistence(timeout: 5) {
            item.tap()
        }
        #else
        let tab = app.buttons[name].firstMatch
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        }
        #endif
    }

    /// Tap a NavigationLink list item by its accessibility identifier.
    /// On macOS, tapping a `staticText` inside a List row does not activate the
    /// `NavigationLink` — we must find the row element itself.  The views tag each
    /// NavigationLink with an `accessibilityIdentifier` (e.g. "dashboard-Climate").
    @MainActor
    @discardableResult
    private func tapDashboard(_ name: String, timeout: TimeInterval = 5) -> Bool {
        return tapByIdentifier("dashboard-\(name)", timeout: timeout)
    }

    @MainActor
    @discardableResult
    private func tapWidget(_ name: String, timeout: TimeInterval = 5) -> Bool {
        return tapByIdentifier("widget-\(name)", timeout: timeout)
    }

    @MainActor
    @discardableResult
    private func tapByIdentifier(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        #if os(macOS)
        // NavigationLink may register as different element types on macOS.
        // Try the most likely types first.
        let candidates: [XCUIElement] = [
            app.buttons[identifier].firstMatch,
            app.links[identifier].firstMatch,
            app.otherElements[identifier].firstMatch,
        ]
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 1) {
                candidate.tap()
                return true
            }
        }
        return false
        #else
        let item = app.buttons[identifier].firstMatch
        guard item.waitForExistence(timeout: timeout) else { return false }
        item.tap()
        return true
        #endif
    }

    /// Navigate back by tapping the back button.
    @MainActor
    private func navigateBack() {
        #if os(macOS)
        // On macOS, NavigationSplitView doesn't expose navigationBars.
        // The back button is a regular toolbar button labeled "Back".
        let back = app.buttons["Back"].firstMatch
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
        #else
        app.navigationBars.buttons.element(boundBy: 0).tap()
        #endif
        sleep(1)
    }

    @MainActor
    private func scrollUp() {
        #if os(macOS)
        app.windows.firstMatch.scroll(byDeltaX: 0, deltaY: 100)
        #else
        app.swipeDown()
        #endif
    }

    // MARK: - Screenshots

    @MainActor
    func testDemoHomeScreenshots() {
        // Wait for app to load
        #if os(macOS)
        let sidebarItem = app.outlines.staticTexts["Dashboards"].firstMatch
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 10), "Expected Dashboards sidebar item")
        #else
        let dashboardsTab = app.buttons["Dashboards"].firstMatch
        XCTAssertTrue(dashboardsTab.waitForExistence(timeout: 10), "Expected Dashboards tab")
        #endif

        // 1. Dashboards list
        selectSection("Dashboards")
        sleep(2) // Wait for demo data to load
        snapshot(ScreenshotIds.DASHBOARDS)

        // 2. Climate dashboard
        if tapDashboard("Climate") {
            sleep(3) // Wait for charts to render
            snapshot(ScreenshotIds.CLIMATE)

            // 3. Scroll down to Temperature Band
            let bandPanel = app.staticTexts["Temperature Band"].firstMatch
            if bandPanel.exists {
                let needsScroll = !bandPanel.isHittable
                if needsScroll {
                    bandPanel.scrollToElement(in: app)
                }
                sleep(2)
                snapshot(ScreenshotIds.CLIMATE_BAND)
                if needsScroll {
                    scrollUp()
                    scrollUp()
                    sleep(1)
                }
            }

            // Explorer
            let exploreButton = app.buttons["Explore"].firstMatch
            if exploreButton.waitForExistence(timeout: 3) {
                exploreButton.tap()
                sleep(2)

                #if os(macOS)
                // On macOS the explorer opens in a separate window
                let explorerWindow = app.windows["Chart Explorer"].firstMatch
                if explorerWindow.waitForExistence(timeout: 5) {
                    snapshot(ScreenshotIds.EXPLORER)
                    explorerWindow.buttons[XCUIIdentifierCloseWindow].tap()
                    sleep(1)
                }
                #else
                snapshot(ScreenshotIds.EXPLORER)
                let closeButton = app.buttons["Close"].firstMatch
                if closeButton.waitForExistence(timeout: 3) {
                    closeButton.tap()
                }
                #endif
            }

            navigateBack()
        }

        // 4. Energy dashboard
        if tapDashboard("Energy") {
            sleep(3)
            let batteryPanel = app.staticTexts["Battery"].firstMatch
            if batteryPanel.exists {
                batteryPanel.scrollToElement(in: app)
                sleep(2)
            }
            snapshot(ScreenshotIds.ENERGY)
            navigateBack()
        }

        // 5. Node Exporter dashboard
        if tapDashboard("Node Exporter") {
            sleep(3)
            snapshot(ScreenshotIds.NODE_EXPORTER)
            navigateBack()
        }

        // Widgets tab
        selectSection("Widgets")
        sleep(2)
        snapshot(ScreenshotIds.WIDGETS)

        if tapWidget("Home Overview", timeout: 3) {
            sleep(3)
            snapshot(ScreenshotIds.WIDGET_PREVIEW)
            navigateBack()
        }

        // 6. Data Sources tab
        selectSection("Data Sources")
        sleep(1)

        let menuButton = app.buttons["Menu"].firstMatch
        if menuButton.waitForExistence(timeout: 3) {
            menuButton.tap()
            sleep(1)

            let addButton = app.buttons["Add Data Source"].firstMatch
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
                sleep(1)

                let typePicker = app.buttons["backendTypePicker"].firstMatch
                if typePicker.waitForExistence(timeout: 3) {
                    typePicker.tap()
                    sleep(1)
                }

                snapshot(ScreenshotIds.DATA_SOURCES)

                // Dismiss picker menu, then dismiss sheet
                app.tap()
                sleep(1)
                let cancelButton = app.buttons["Cancel"].firstMatch
                if cancelButton.waitForExistence(timeout: 3) {
                    cancelButton.tap()
                    sleep(1)
                }
            }
        }

        // 7. About tab
        selectSection("About")
        sleep(1)
        snapshot(ScreenshotIds.ABOUT)
    }
}
