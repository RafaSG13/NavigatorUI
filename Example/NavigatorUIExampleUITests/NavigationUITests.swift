import XCTest

/// End-to-end checks of what unit tests cannot see: the real UIKit back button, swipe-back,
/// sheets, SwiftUI hosted inside UIKit, and URL handling through the app.
@MainActor
final class NavigationUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.navigationBars["NavigatorUI"].waitForExistence(timeout: 5))
    }

    private func tap(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "missing button \(label)", file: file, line: line)
        button.tap()
    }

    private func expectBar(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
                      "expected navigation bar \(title)", file: file, line: line)
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func swipeBack() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testPushAndBackButton() {
        tap("Profile 42")
        expectBar("Profile")
        XCTAssertTrue(app.staticTexts["Profile 42"].exists)

        goBack()
        expectBar("NavigatorUI")
    }

    func testSwipeBackWorksWithoutGuard() {
        tap("Profile 42")
        expectBar("Profile")

        swipeBack()
        expectBar("NavigatorUI")
    }

    func testFadeTransitionPushAndPop() {
        tap("Settings (fade transition)")
        expectBar("Settings")

        goBack()
        expectBar("NavigatorUI")
    }

    func testSetStackBuildsTwoScreensAtOnce() {
        tap("Details, then Settings in one stack change")
        expectBar("Settings")

        goBack()
        expectBar("Details")
    }

    func testDeepLinkFromInsideTheAppBuildsStack() {
        tap("Open navigatorui://profile/42/settings")
        expectBar("Settings")

        goBack()
        expectBar("Profile")
        goBack()
        expectBar("NavigatorUI")
    }

    func testDeepLinkPresentsSheetThenPushesInsideIt() {
        tap("Open navigatorui://editor/profile/9")
        expectBar("Profile")
        XCTAssertTrue(app.staticTexts["Profile 9"].exists)

        goBack()
        expectBar("Editor")
        tap("Close sheet")
        expectBar("NavigatorUI")
    }

    func testPopGuardBlocksBackButtonAndSwipeUntilChangesAreDiscarded() {
        tap("Editor (pushed, guarded back)")
        expectBar("Editor")
        // The element spans the whole row; its center is the label, not the switch.
        let toggle = app.switches["Unsaved changes"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1", "the test must have enabled unsaved changes")

        goBack()
        XCTAssertTrue(app.alerts["Discard changes?"].waitForExistence(timeout: 5), "back button must be guarded")
        app.alerts.buttons["Keep editing"].tap()
        expectBar("Editor")

        swipeBack()
        XCTAssertTrue(app.alerts["Discard changes?"].waitForExistence(timeout: 5), "swipe-back must be guarded")
        app.alerts.buttons["Discard"].tap()
        expectBar("NavigatorUI")
    }

    func testPopGuardAllowsBackWhenNothingIsUnsaved() {
        tap("Editor (pushed, guarded back)")
        expectBar("Editor")

        goBack()
        expectBar("NavigatorUI")
        XCTAssertFalse(app.alerts["Discard changes?"].exists)
    }

    func testFullScreenCoverWithItsOwnStack() {
        tap("Onboarding (full screen)")
        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))

        tap("Push Settings in this cover")
        expectBar("Settings")
        goBack()
        tap("Close")
        expectBar("NavigatorUI")
    }

    func testSheetFromPushedScreenDismissesBackToThatScreen() {
        tap("Profile 42")
        tap("Edit (sheet)")
        expectBar("Editor")

        tap("Close sheet")
        expectBar("Profile")
    }
}
