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

    private func safeTapRegion(in app: XCUIApplication) -> CGRect {
        let bounds = app.frame
        // Exclude the status bar / navigation-bar overlay and iOS 27's
        // floating tab bar. The complete row CENTER must be inside this zone.
        return CGRect(x: bounds.minX + 14,
                      y: bounds.minY + 140,
                      width: bounds.width - 28,
                      height: max(100, bounds.height - 330))
    }

    private func screenVisible(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let rect = element.frame
        let zone = safeTapRegion(in: app)
        return rect.width > 20 && rect.height > 15 &&
            rect.midY >= zone.minY && rect.midY <= zone.maxY &&
            rect.midX >= zone.minX && rect.midX <= zone.maxX
    }

    private func locate(_ label: String, in app: XCUIApplication,
                        identifier: String? = nil) -> XCUIElement? {
        let scroll = scrollSurface(in: app)
        let zone = safeTapRegion(in: app)
        for attempt in 0..<12 {
            let item = target(label, in: app, identifier: identifier)
            if screenVisible(item, app: app) {
                print("ACCEPTANCE_TARGET_SAFE \(label) frame=\(item.frame) zone=\(zone)")
                return item
            }
            if attempt == 11 { break }
            // Never continue swiping up after a row moves into or ABOVE
            // the tappable area. That caused July's row to end at y=61.
            let direction: String
            if item.exists && item.frame.midY < zone.minY {
                scroll.swipeDown()
                direction = "down"
            } else {
                scroll.swipeUp()
                direction = "up"
            }
            print("ACCEPTANCE_SCROLL \(label) direction=\(direction) attempt=\(attempt + 1) frame=\(item.exists ? "\(item.frame)" : "missing")")
            RunLoop.current.run(until: Date().addingTimeInterval(0.22))
        }
        print("ACCEPTANCE_TARGET_UNAVAILABLE \(label): \(app.debugDescription)")
        return nil
    }

    private func tap(_ label: String, in app: XCUIApplication,
                     identifier: String? = nil, leftLabel: Bool = false) -> Bool {
        guard let item = locate(label, in: app, identifier: identifier) else { return false }
        let x = leftLabel ? 0.14 : 0.5
        // Prefer coordinates once the center is in the safe region: Xcode 27
        // reported every list row as isHittable=false, even successful links.
        // Plain buttons (Control Center) need a hit on the left label, not
        // the empty Spacer occupying the center of the button.
        let point = item.coordinate(
            withNormalizedOffset: CGVector(dx: x, dy: 0.5)
        )
        print("ACCEPTANCE_TAP_SAFE \(label) frame=\(item.frame) xFraction=\(x)")
        point.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
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
        // The connection button is at y≈784 on the iPhone 18 Pro Max.
        // This standalone onboarding view is intentionally NOT in the
        // scrollable tab shell. Do not use the shell's y<766 safe zone:
        // scrolling the onboarding root cannot move this button.
        let connect = landing.buttons["Home Assistant verbinden"].firstMatch
        let actionable = connect.waitForExistence(timeout: 10) && connect.isHittable
        XCTAssertTrue(actionable, "Home Assistant connection setup button is not hittable")
        if actionable {
            connect.tap()
            let setup = landing.navigationBars["Verbinden"]
            let presented = setup.waitForExistence(timeout: 8)
            XCTAssertTrue(presented, "Connection setup sheet did not appear")
            if presented { capture("setup-home-assistant", app: landing) }
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
        let pressed = tap("Control Center", in: app, leftLabel: true)
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
