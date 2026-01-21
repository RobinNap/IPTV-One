//
//  IPTV_OneUITests.swift
//  IPTV OneUITests
//
//  Created by Robin Nap on 21/01/2026.
//

import XCTest

final class IPTV_OneUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that main tabs exist
        #if os(iOS)
        XCTAssertTrue(app.tabBars.buttons["Live TV"].exists)
        XCTAssertTrue(app.tabBars.buttons["Movies"].exists)
        XCTAssertTrue(app.tabBars.buttons["Series"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        
        // Navigate between tabs
        app.tabBars.buttons["Movies"].tap()
        app.tabBars.buttons["Series"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.tabBars.buttons["Live TV"].tap()
        #endif
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
