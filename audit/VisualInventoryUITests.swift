import Foundation
import XCTest
import UIKit

final class VisualInventoryUITests: XCTestCase {
    private let darkProductScreens = [
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

    private func capture(_ name: String, app: XCUIApplication) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        let attachment = XCTAttachment(screenshot: app.screenshot())
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
        if !root.waitForExistence(timeout: 6) {
            XCTFail("VISUAL_INVENTORY_ROOT_MISSING \(screen)")
        }
        return app
    }

    @discardableResult
    private func launchRaw(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        return app
    }

    private func element(label: String, in app: XCUIApplication) -> XCUIElement {
        let exact = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
        if exact.waitForExistence(timeout: 0.8) { return exact }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
    }

    @discardableResult
    private func tap(_ label: String, in app: XCUIApplication, maxSwipes: Int = 4) -> Bool {
        let target = element(label: label, in: app)
        guard target.waitForExistence(timeout: 2) else { return false }

        for _ in 0..<maxSwipes where !target.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        guard target.isHittable else { return false }
        target.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        return true
    }

    func test01LandingAndSetup() {
        let app = launchRaw()
        capture("landing", app: app)
        if tap("Home Assistant verbinden", in: app) {
            capture("setup-home-assistant", app: app)
        }
        app.terminate()
    }

    func test02DarkProductCatalog() {
        for screen in darkProductScreens {
            let app = launchProduct(screen, dark: true)
            capture("catalog-dark-\(screen)", app: app)
            app.terminate()
        }
    }

    func test03LightCoreCatalog() {
        for screen in ["home", "rooms", "chat", "media", "system"] {
            let app = launchProduct(screen, dark: false)
            capture("catalog-light-\(screen)", app: app)
            app.terminate()
        }
    }

    func test04NavigationCatalog() {
        let routes: [(String, String, String)] = [
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

        for (screen, label, name) in routes {
            let app = launchProduct(screen, dark: true)
            if tap(label, in: app) {
                capture("nav-dark-\(name)", app: app)
            }
            app.terminate()
        }

        let home = launchProduct("home", dark: true)
        if tap("Außenbereich", in: home) {
            capture("nav-dark-home-outdoors", app: home)
        }
        home.terminate()
    }

    func test05CardsAndSliders() {
        for page in 0...2 {
            let app = launchRaw(["--live-card-test-mode", "--live-card-page=\(page)"])
            let ready = app.descendants(matching: .any)
                .matching(identifier: "visual-ready-live-card-page-\(page)")
                .firstMatch
            _ = ready.waitForExistence(timeout: 5)
            capture("cards-page-\(page + 1)", app: app)
            app.terminate()
        }

        for screen in ["light", "media-detail"] {
            let app = launchProduct(screen, dark: true)
            capture("slider-\(screen)-before", app: app)

            for (index, slider) in app.sliders.allElementsBoundByIndex.enumerated() {
                guard slider.exists else { continue }
                if !slider.isHittable {
                    app.swipeUp()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                }
                guard slider.isHittable else { continue }
                slider.adjust(toNormalizedSliderPosition: index.isMultiple(of: 2) ? 0.28 : 0.72)
                RunLoop.current.run(until: Date().addingTimeInterval(0.12))
                capture("slider-\(screen)-\(index)-after", app: app)
            }
            app.terminate()
        }
    }
}
