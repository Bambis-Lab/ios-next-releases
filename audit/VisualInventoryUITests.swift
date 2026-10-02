import Foundation
import XCTest
import UIKit

/// Branch-only visual inventory crawler.
/// It never performs production/network mutations; it drives deterministic acceptance/test surfaces
/// and writes screenshots directly to IOSNEXT_VISUAL_INVENTORY_DIR.
final class VisualInventoryUITests: XCTestCase {
    private let productScreens = [
        "home", "rooms", "chat", "media", "system",
        "light", "media-detail", "owner"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String, app: XCUIApplication, note: String = "") {
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "VISUAL-INVENTORY--\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func launchProduct(_ screen: String, dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["--product-ui-test-screen=\(screen)"]
        if dark { args.append("--product-ui-test-dark") }
        app.launchArguments = args
        app.launch()

        let root = app.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)")
            .firstMatch
        if !root.waitForExistence(timeout: 8) {
            XCTFail("VISUAL_INVENTORY_ROOT_MISSING \(screen)")
        }
        return app
    }

    @discardableResult
    private func launchRaw(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        return app
    }

    private func element(label: String, in app: XCUIApplication) -> XCUIElement {
        let exact = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
        if exact.waitForExistence(timeout: 1.2) { return exact }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
    }

    @discardableResult
    private func tap(_ label: String, in app: XCUIApplication, maxSwipes: Int = 5) -> Bool {
        let target = element(label: label, in: app)
        guard target.waitForExistence(timeout: 3) else {
            XCTFail("VISUAL_INVENTORY_ELEMENT_MISSING \(label)")
            return false
        }
        for _ in 0..<maxSwipes where !target.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        guard target.isHittable else {
            XCTFail("VISUAL_INVENTORY_ELEMENT_UNHITTABLE \(label)")
            return false
        }
        target.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        return true
    }


    private func captureSetupAndLanding() {
        let landing = launchRaw()
        capture("landing", app: landing, note: "normal cold entry surface")
        if tap("Home Assistant verbinden", in: landing) {
            capture("setup-home-assistant", app: landing, note: "connection setup sheet/menu")
        }
        landing.terminate()
    }

    private func captureNavigationTerminals() {
        let routes: [(screen: String, tap: String, name: String)] = [
            ("rooms", "Timo Zimmer", "room-timo"),
            ("rooms", "Alle Entitäten", "all-entities"),
            ("media", "Companion Testfilm", "media-fire-tv-detail"),
            ("system", "Szenen", "system-scenes"),
            ("system", "Suche", "system-search"),
            ("system", "Jarvis", "system-jarvis"),
            ("system", "Master Runtime Live", "system-live-operations"),
            ("system", "Master Zugriff", "system-master-capabilities"),
            ("system", "Control Center", "system-control-center"),
            ("system", "Berechtigungen", "system-permissions"),
            ("system", "Diagnose", "system-diagnostics")
        ]

        for route in routes {
            let app = launchProduct(route.screen, dark: true)
            if tap(route.tap, in: app) {
                capture("nav-dark-\(route.name)", app: app, note: "\(route.screen) -> \(route.tap)")
            }
            app.terminate()
        }

        let home = launchProduct("home", dark: true)
        if tap("Außenbereich", in: home) {
            capture("nav-dark-home-outdoors", app: home, note: "home -> Außenbereich")
        }
        home.terminate()
    }

    private func captureSliderStates() {
        for screen in ["light", "media-detail"] {
            let app = launchProduct(screen, dark: true)
            capture("slider-\(screen)-before", app: app, note: "all visible sliders before interaction")

            let sliders = app.sliders.allElementsBoundByIndex
            for (index, slider) in sliders.enumerated() {
                if !slider.isHittable {
                    app.swipeUp()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                }
                guard slider.exists, slider.isHittable else { continue }
                slider.adjust(toNormalizedSliderPosition: index.isMultiple(of: 2) ? 0.28 : 0.72)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                capture(
                    "slider-\(screen)-\(index)-after",
                    app: app,
                    note: "normalized slider adjustment in deterministic preview state"
                )
            }
            app.terminate()
        }
    }

    func testCompleteVisualInventory() {
        captureSetupAndLanding()
        captureNavigationTerminals()
        captureSliderStates()
    }
}
