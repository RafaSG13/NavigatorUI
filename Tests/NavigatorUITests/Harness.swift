import Testing
import SwiftUI
import UIKit
@testable import NavigatorUI

enum TestRoute: Route {
    case home
    case detail(Int)
    case settings
}

enum ModalRoute: Route {
    case editor
    case inner
}

enum LinkRoute: Route {
    case profile(String)
    case settings
}

enum GuardedRoute: Route {
    case screen
}

@MainActor
final class GuardSwitch {
    var allowsPop = true
}

/// A real navigation tree in a real window, so UIKit behaves as it does in an app.
@MainActor
final class Harness {
    let navigator: Navigator
    let window: UIWindow
    let controller: StackController
    let guardSwitch: GuardSwitch
    private(set) var events: [NavigationEvent] = []

    var queue: NavigationQueue { navigator.context.queue }

    /// Routes of the stack of the topmost modal, or of the root when nothing is presented.
    var visibleStack: [AnyRoute] {
        var top = controller
        while let next = top.presentedViewController as? StackController { top = next }
        return top.hosts.compactMap(\.route)
    }

    var failures: [String] {
        events.compactMap { if case .failure(let message) = $0 { message } else { nil } }
    }

    var blockedPops: Int {
        events.filter { if case .popBlocked = $0 { true } else { false } }.count
    }

    static func make(deepLinks: DeepLinkRouter? = nil) -> Harness {
        let guardSwitch = GuardSwitch()
        let registry = RouteRegistry()
        registry.register(TestRoute.self) { Text(String(describing: $0)) }
        registry.register(ModalRoute.self) { Text(String(describing: $0)) }
        registry.register(LinkRoute.self) { Text(String(describing: $0)) }
        registry.register(GuardedRoute.self) { _ in
            Text("guarded").popGuard { guardSwitch.allowsPop }
        }

        let navigator = Navigator()
        navigator.context.registry = registry
        navigator.deepLinks = deepLinks
        let harness = Harness(navigator: navigator, guardSwitch: guardSwitch)
        navigator.eventHandler = { [weak harness] event in harness?.events.append(event) }
        return harness
    }

    private init(navigator: Navigator, guardSwitch: GuardSwitch) {
        self.navigator = navigator
        self.guardSwitch = guardSwitch
        controller = navigator.makeRootController(.route(AnyRoute(TestRoute.home)))
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        // Inside the example app there is a real scene. SwiftUI and UIKit only drive
        // transitions and updates in windows attached to one.
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = frame
        } else {
            window = UIWindow(frame: frame)
        }
        window.rootViewController = controller
        window.makeKeyAndVisible()
    }

    isolated deinit {
        window.isHidden = true
    }

    /// Waits until the root controller has appeared and every queued operation has finished.
    func settle() async {
        await wait { !self.queue.isBlocked && self.queue.isIdle }
    }

    /// Polls `condition` for up to two seconds.
    func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Presenting, dismissing and animated transitions only complete inside a process that has a window scene.
/// A bare package test run has none (not even plain UIKit presents there), so those tests run through the
/// Example app scheme: `xcodebuild -project Example/NavigatorUIExample.xcodeproj -scheme NavigatorUIExample test`.
extension Trait where Self == ConditionTrait {
    static var requiresScene: Self {
        .enabled(if: Bundle.main.bundleIdentifier == "dev.navigatorui.example",
                 "needs a window scene; run through the Example app scheme")
    }
}
