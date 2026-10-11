import Foundation
import XCTest
import UIKit

// Test the published 1.4.1 build's real accessibility hierarchy; no
// product-source edits, synthetic navigation, or swallowed assertions.
final class VisualInventoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String, app: XCUIApplication) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "VISUAL-INVENTORY--\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func launchProduct(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--product-ui-test-screen=\(screen)", "--product-ui-test-dark"]
        app.launch()
        let root = app.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 15), "Acceptance root \(screen) missing")
        return app
    }

    private func launchRaw() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    private func scrollSurface(in app: XCUIApplication) -> XCUIElement {
        let list = app.tables.firstMatch
        if list.exists { return list }
        let scroll = app.scrollViews.firstMatch
        return scroll.exists ? scroll : app
    }

    private func target(_ label: String, in app: XCUIApplication, identifier: String? = nil) -> XCUIElement {
        if let identifier {
            return app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch
        }
        let exact = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if exact.exists { return exact }
        let contained = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        if contained.exists { return contained }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    private func screenVisible(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let rect = element.frame
        let screen = app.frame
        guard rect.width > 4, rect.height > 4 else { return false }
        // Exclude the status bar and floating tab bar from actionable space.
        let viewport = CGRect(x: screen.minX + 5, y: screen.minY + 65,
                              width: screen.width - 10, height: screen.height - 160)
        let overlap = rect.intersection(viewport)
        return !overlap.isNull && overlap.width > 8 && overlap.height > 8
    }

    private func locate(_ label: String, in app: XCUIApplication, identifier: String? = nil) -> XCUIElement? {
        let scrolling = scrollSurface(in: app)
        for attempt in 0..<12 {
            let candidate = target(label, in: app, identifier: identifier)
            if screenVisible(candidate, app: app) {
                print("ACCEPTANCE_TARGET_FOUND \(label) label=\(candidate.label) type=\(candidate.elementType.rawValue) frame=\(candidate.frame) hittable=\(candidate.isHittable)")
                return candidate
            }
            if attempt < 11 {
                scrolling.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.18))
            }
        }
        print("ACCEPTANCE_TARGET_NOT_VISIBLE \(label): \(app.debugDescription)")
        return nil
    }

    private func tap(_ label: String, in app: XCUIApplication, identifier: String? = nil) -> Bool {
        guard locate(label, in: app, identifier: identifier) != nil else { return false }

        // A geometrically visible list row can still be underneath the
        // iOS 27 floating bottom tab bar. Bring it into the tappable center.
        let scrolling = scrollSurface(in: app)
        for _ in 0..<5 {
            let candidate = target(label, in: app, identifier: identifier)
            if candidate.exists && candidate.isHittable {
                print("ACCEPTANCE_TAP_HITTABLE \(label) frame=\(candidate.frame)")
                candidate.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
                return true
            }
            scrolling.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.18))
        }

        let candidate = target(label, in: app, identifier: identifier)
        guard screenVisible(candidate, app: app) else {
            print("ACCEPTANCE_TARGET_OBSCURED \(label)")
            return false
        }
        print("ACCEPTANCE_TAP_COORDINATE \(label) frame=\(candidate.frame)")
        candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        return true
    }

    private func route(screen: String, label: String, name: String,
                       destinationTitle: String, identifier: String? = nil) {
        let app = launchProduct(screen)
        let pressed = tap(label, in: app, identifier: identifier)
        XCTAssertTrue(pressed, "Navigation target \(label) in \(screen) absent or offscreen")
        if pressed {
            let nav = app.navigationBars[destinationTitle]
            let arrived = nav.waitForExistence(timeout: 8)
            XCTAssertTrue(arrived, "Tapping \(label) did not open \(destinationTitle)")
            if arrived { capture("nav-dark-\(name)", app: app) }
        }
        app.terminate()
    }

    func test01SetupAndRoomNavigation() {
        let landing = launchRaw()
        capture("landing", app: landing)
        let pressed = tap("Home Assistant verbinden", in: landing)
        XCTAssertTrue(pressed, "Home Assistant connection setup button missing")
        if pressed {
            let setup = landing.navigationBars["Verbinden"]
            XCTAssertTrue(setup.waitForExistence(timeout: 5),
                          "Connection setup sheet did not appear")
            capture("setup-home-assistant", app: landing)
        }
        landing.terminate()

        route(screen: "rooms", label: "Timo Zimmer", name: "room-timo",
              destinationTitle: "Timo Zimmer")
        route(screen: "rooms", label: "Juli Zimmer", name: "room-juli",
              destinationTitle: "Juli Zimmer")
        route(screen: "home", label: "Außenbereich", name: "home-outdoors",
              destinationTitle: "Außenbereich", identifier: "home-shortcut-outdoors")
    }

    func test02MediaAndSystemNavigationA() {
        route(screen: "system", label: "Szenen", name: "system-scenes",
              destinationTitle: "Szenen")
        route(screen: "system", label: "Suche", name: "system-search",
              destinationTitle: "Suche")
        route(screen: "system", label: "Jarvis", name: "system-jarvis",
              destinationTitle: "Jarvis")
    }

    func test03SystemNavigationB() {
        route(screen: "system", label: "Master Runtime Live",
              name: "system-live-operations", destinationTitle: "Master Runtime Live",
              identifier: "system-live-operations")
        route(screen: "system", label: "Master Zugriff",
              name: "system-master-capabilities", destinationTitle: "Master Zugriff",
              identifier: "system-master-capabilities")
        // Control Center is presented using .fullScreenCover, not a push
        // NavigationLink. Its modal close button proves the cover opened.
        let app = launchProduct("system")
        let pressed = tap("Control Center", in: app)
        XCTAssertTrue(pressed, "Control Center button was not tappable")
        if pressed {
            let close = app.buttons["Schließen"].firstMatch
            let presented = close.waitForExistence(timeout: 12)
            XCTAssertTrue(presented, "Control Center full-screen cover was not presented")
            if presented { capture("nav-dark-system-control-center", app: app) }
        }
        app.terminate()
    }

    func test04SystemNavigationC() {
        route(screen: "system", label: "Berechtigungen", name: "system-permissions",
              destinationTitle: "Berechtigungen")
        route(screen: "system", label: "Diagnose", name: "system-diagnostics",
              destinationTitle: "Diagnose")
    }

    func test05SliderStates() {
        for screen in ["light", "media-detail"] {
            let app = launchProduct(screen)
            capture("slider-\(screen)-before", app: app)
            let id = screen == "light" ? "light-brightness-slider" : nil
            let slider: XCUIElement
            if let id {
                slider = app.sliders.matching(identifier: id).firstMatch
            } else {
                slider = app.sliders.firstMatch
            }
            XCTAssertTrue(slider.waitForExistence(timeout: 10),
                          "Missing slider on \(screen)")
            if slider.exists {
                let before = slider.value as? String ?? ""
                print("ACCEPTANCE_SLIDER_BEFORE \(screen): \(before)")
                var after = before
                // Use the native XCUI accessibility adjustment rather than
                // beginning a drag away from the slider thumb. Require the
                // reported value to really change; never fake success.
                for position in [0.82, 0.18] {
                    slider.adjust(toNormalizedSliderPosition: position)
                    for _ in 0..<8 {
                        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                        after = slider.value as? String ?? ""
                        if after != before { break }
                    }
                    print("ACCEPTANCE_SLIDER_ATTEMPT \(screen) target=\(position) value=\(after)")
                    if after != before { break }
                }
                XCTAssertNotEqual(after, before, "Slider on \(screen) did not change value")
                if after != before { capture("slider-\(screen)-after", app: app) }
            } else {
                print("ACCEPTANCE_SLIDER_MISSING \(screen): \(app.debugDescription)")
            }
            app.terminate()
        }
    }
}
