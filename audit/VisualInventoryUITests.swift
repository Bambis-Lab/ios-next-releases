import Foundation
import XCTest
import UIKit

final class VisualInventoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String, app: XCUIApplication) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "VISUAL-INVENTORY--\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func launchProduct(_ screen: String, dark: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["--product-ui-test-screen=\(screen)"]
        if dark { args.append("--product-ui-test-dark") }
        app.launchArguments = args
        app.launch()

        let root = app.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)")
            .firstMatch
        _ = root.waitForExistence(timeout: 4)
        return app
    }

    @discardableResult
    private func launchRaw() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        return app
    }

    private func element(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let exact = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
        if exact.waitForExistence(timeout: 0.6) { return exact }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
    }

    @discardableResult
    private func tap(_ label: String, in app: XCUIApplication, maxSwipes: Int = 3) -> Bool {
        let target = element(label, in: app)
        guard target.waitForExistence(timeout: 1.5) else { return false }
        for _ in 0..<maxSwipes where !target.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        }
        guard target.isHittable else { return false }
        target.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.18))
        return true
    }

    private func route(screen: String, label: String, name: String) {
        let app = launchProduct(screen)
        if tap(label, in: app) { capture("nav-dark-\(name)", app: app) }
        app.terminate()
    }

    func test01SetupAndRoomNavigation() {
        let landing = launchRaw()
        capture("landing", app: landing)
        if tap("Home Assistant verbinden", in: landing) {
            capture("setup-home-assistant", app: landing)
        }
        landing.terminate()

        route(screen: "rooms", label: "Timo Zimmer", name: "room-timo")
        route(screen: "rooms", label: "Alle Entitäten", name: "all-entities")

        let home = launchProduct("home")
        if tap("Außenbereich", in: home) { capture("nav-dark-home-outdoors", app: home) }
        home.terminate()
    }

    func test02MediaAndSystemNavigationA() {
        route(screen: "media", label: "Companion Testfilm", name: "media-fire-tv-detail")
        route(screen: "system", label: "Szenen", name: "system-scenes")
        route(screen: "system", label: "Suche", name: "system-search")
        route(screen: "system", label: "Jarvis", name: "system-jarvis")
    }

    func test03SystemNavigationB() {
        route(screen: "system", label: "Master Runtime Live", name: "system-live-operations")
        route(screen: "system", label: "Master Zugriff", name: "system-master-capabilities")
        route(screen: "system", label: "Control Center", name: "system-control-center")
    }

    func test04SystemNavigationC() {
        route(screen: "system", label: "Berechtigungen", name: "system-permissions")
        route(screen: "system", label: "Diagnose", name: "system-diagnostics")
    }

    func test05SliderStates() {
        for screen in ["light", "media-detail"] {
            let app = launchProduct(screen)
            capture("slider-\(screen)-before", app: app)
            for (index, slider) in app.sliders.allElementsBoundByIndex.enumerated() {
                guard slider.exists else { continue }
                if !slider.isHittable {
                    app.swipeUp()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.08))
                }
                guard slider.isHittable else { continue }
                slider.adjust(toNormalizedSliderPosition: index.isMultiple(of: 2) ? 0.28 : 0.72)
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                capture("slider-\(screen)-\(index)-after", app: app)
            }
            app.terminate()
        }
    }
}
