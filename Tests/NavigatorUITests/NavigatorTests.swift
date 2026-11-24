import SwiftUI
import Testing
import UIKit
@testable import NavigatorUI

@MainActor
struct StackTests {
    @Test func pushAndPopUpdateStackAndInspection() async {
        let harness = Harness.make()
        await harness.settle()
        let navigator = harness.navigator

        navigator.push(TestRoute.detail(1), animated: false)
        navigator.push(TestRoute.settings, animated: false)

        #expect(navigator.routes == [
            AnyRoute(TestRoute.home), AnyRoute(TestRoute.detail(1)), AnyRoute(TestRoute.settings)
        ])
        #expect(navigator.depth == 3)
        #expect(navigator.routes(of: TestRoute.self).count == 3)
        #expect(navigator.contains(TestRoute.detail(1)))

        navigator.pop(animated: false)
        #expect(navigator.routes.last == AnyRoute(TestRoute.detail(1)))
        #expect(harness.controller.viewControllers.count == 2)
    }

    @Test func popToRootAndPopToRoute() async {
        let harness = Harness.make()
        await harness.settle()
        let navigator = harness.navigator
        for id in 1...4 { navigator.push(TestRoute.detail(id), animated: false) }

        navigator.pop(to: TestRoute.detail(2), animated: false)
        #expect(navigator.routes.last == AnyRoute(TestRoute.detail(2)))

        navigator.popToRoot(animated: false)
        #expect(navigator.depth == 1)

        navigator.pop(5, animated: false)
        #expect(navigator.depth == 1, "popping past the root stops at the root")
    }

    @Test func popToMissingRouteFailsWithoutChangingStack() async {
        let harness = Harness.make()
        await harness.settle()
        harness.navigator.push(TestRoute.settings, animated: false)

        harness.navigator.pop(to: TestRoute.detail(9), animated: false)

        #expect(harness.navigator.depth == 2)
        #expect(harness.failures.count == 1)
    }

    @Test func setStackReusesMatchingScreens() async {
        let harness = Harness.make()
        await harness.settle()
        let navigator = harness.navigator
        navigator.push(TestRoute.detail(1), animated: false)
        let kept = harness.controller.viewControllers[1]

        navigator.setStack([TestRoute.detail(1), TestRoute.detail(2), TestRoute.settings], animated: false)

        #expect(navigator.routes == [.init(TestRoute.home), .init(TestRoute.detail(1)),
                                     .init(TestRoute.detail(2)), .init(TestRoute.settings)])
        #expect(harness.controller.viewControllers[1] === kept)

        navigator.setStack([AnyRoute](), animated: false)
        #expect(navigator.depth == 1)
    }

    @Test func unregisteredRouteIsRejectedAndReported() async {
        let harness = Harness.make()
        await harness.settle()

        struct Orphan: Route {}
        harness.navigator.push(Orphan(), animated: false)
        harness.navigator.present(Orphan(), animated: false)
        await harness.settle()

        #expect(harness.navigator.depth == 1)
        #expect(harness.controller.presentedViewController == nil)
        #expect(harness.failures.count == 2)
    }

    @Test func swipeBackIsReflectedInNavigatorState() async {
        let harness = Harness.make()
        await harness.settle()
        harness.navigator.push(TestRoute.settings, animated: false)

        // What UIKit does after a user-driven pop: the controller changes and the delegate reports it.
        harness.controller.popViewController(animated: false)
        let controller = harness.controller
        controller.navigationController(controller, didShow: controller.viewControllers[0], animated: false)

        #expect(harness.navigator.routes == [AnyRoute(TestRoute.home)])
        #expect(harness.navigator.depth == 1)
    }
}

@MainActor
struct PopGuardTests {
    /// Pushes a screen that installs its guard through SwiftUI's `.popGuard`, and waits for it to reach UIKit.
    private func guardedHarness(allows: Bool) async -> Harness {
        let harness = Harness.make()
        await harness.settle()
        harness.guardSwitch.allowsPop = allows
        harness.navigator.push(GuardedRoute.screen, animated: false)
        await harness.wait { harness.controller.hosts.last?.allowsPop() == allows }
        return harness
    }

    @Test func guardBlocksPopVariants() async {
        let harness = await guardedHarness(allows: false)

        harness.navigator.pop(animated: false)
        harness.navigator.popToRoot(animated: false)
        harness.navigator.dismiss(animated: false)

        #expect(harness.navigator.depth == 2)
        #expect(harness.blockedPops == 3)
    }

    @Test func forceBypassesGuard() async {
        let harness = await guardedHarness(allows: false)

        harness.navigator.pop(animated: false, force: true)

        #expect(harness.navigator.depth == 1)
    }

    @Test func guardIsLiveNotCapturedAtPushTime() async {
        let harness = await guardedHarness(allows: false)
        harness.guardSwitch.allowsPop = true

        harness.navigator.pop(animated: false)

        #expect(harness.navigator.depth == 1)
    }

    @Test func backButtonAndSwipeConsultGuard() async {
        let harness = await guardedHarness(allows: false)
        let controller = harness.controller
        let swipe = controller.interactivePopGestureRecognizer!
        let tapBack = { controller.hosts.last?.navigationItem.backAction?.performWithSender(nil, target: nil) }

        tapBack()
        #expect(controller.gestureRecognizerShouldBegin(swipe) == false)
        #expect(harness.navigator.depth == 2)
        #expect(harness.blockedPops == 2)

        harness.guardSwitch.allowsPop = true
        #expect(controller.gestureRecognizerShouldBegin(swipe) == true)
        tapBack()
        await harness.settle()
        #expect(harness.navigator.depth == 1)
    }
}

@MainActor
@Suite(.requiresScene)
struct ModalTests {
    @Test func presentCreatesIndependentStack() async {
        let harness = Harness.make()
        await harness.settle()

        harness.navigator.present(ModalRoute.editor, animated: false)
        await harness.settle()

        let modal = harness.controller.presentedViewController as? StackController
        #expect(modal != nil)
        #expect(modal?.navigator.isModal == true)

        modal?.navigator.push(TestRoute.settings, animated: false)
        #expect(modal?.navigator.routes == [AnyRoute(ModalRoute.editor), AnyRoute(TestRoute.settings)])
        #expect(harness.navigator.routes == [AnyRoute(TestRoute.home)], "root stack is untouched")
    }

    @Test func dismissPopsFirstThenClosesModal() async {
        let harness = Harness.make()
        await harness.settle()
        harness.navigator.present(ModalRoute.editor, animated: false)
        await harness.settle()
        let modal = harness.controller.presentedViewController as? StackController
        modal?.navigator.push(TestRoute.settings, animated: false)

        modal?.navigator.dismiss(animated: false)
        #expect(modal?.navigator.depth == 1)
        #expect(harness.controller.presentedViewController != nil)

        modal?.navigator.dismiss(animated: false)
        await harness.settle()
        #expect(harness.controller.presentedViewController == nil)
    }

    @Test func onDismissFiresOnceForEveryDismissalPath() async {
        let harness = Harness.make()
        await harness.settle()
        var fired = 0

        harness.navigator.present(ModalRoute.editor, animated: false) { fired += 1 }
        await harness.settle()
        harness.navigator.dismissAll(animated: false)
        await harness.settle()
        #expect(fired == 1)

        harness.navigator.present(ModalRoute.editor, animated: false) { fired += 1 }
        await harness.settle()
        let modal = harness.controller.presentedViewController as? StackController
        modal?.navigator.dismissModal(animated: false)
        await harness.settle()
        #expect(fired == 2)

        // Swipe-to-dismiss path: UIKit dismisses, then tells the presentation delegate.
        harness.navigator.present(ModalRoute.editor, animated: false) { fired += 1 }
        await harness.settle()
        let swiped = harness.controller.presentedViewController as? StackController
        harness.controller.dismiss(animated: false)
        swiped?.presentationControllerDidDismiss(swiped!.presentationController!)
        swiped?.presentationControllerDidDismiss(swiped!.presentationController!)
        #expect(fired == 3)
    }

    @Test func dismissAllClosesNestedModalsAndNotifiesEach() async {
        let harness = Harness.make()
        await harness.settle()
        var dismissed: [String] = []

        harness.navigator.present(ModalRoute.editor, animated: false) { dismissed.append("editor") }
        await harness.settle()
        let first = harness.controller.presentedViewController as? StackController
        first?.navigator.present(ModalRoute.inner, animated: false) { dismissed.append("inner") }
        await harness.settle()
        #expect(first?.presentedViewController != nil)

        harness.navigator.dismissAll(animated: false)
        await harness.settle()

        #expect(harness.controller.presentedViewController == nil)
        #expect(dismissed == ["inner", "editor"])
    }

    @Test func presentFromCoveredStackPresentsOnTop() async {
        let harness = Harness.make()
        await harness.settle()
        harness.navigator.present(ModalRoute.editor, animated: false)
        await harness.settle()

        harness.navigator.present(ModalRoute.inner, animated: false)
        await harness.settle()

        let first = harness.controller.presentedViewController as? StackController
        #expect((first?.presentedViewController as? StackController)?.navigator.routes == [AnyRoute(ModalRoute.inner)])
        #expect(harness.failures.isEmpty)
    }
}

@MainActor
struct QueueTests {
    @Test(.requiresScene) func animatedCallsRunInOrderWithoutOverlap() async {
        let harness = Harness.make()
        await harness.settle()

        harness.navigator.push(TestRoute.detail(1))
        harness.navigator.push(TestRoute.detail(2))
        harness.navigator.present(ModalRoute.editor)
        harness.navigator.push(TestRoute.settings) // lands on the covered root stack
        await harness.settle()

        #expect(harness.navigator.routes.count == 4)
        #expect(harness.controller.presentedViewController != nil)
        #expect(harness.failures.isEmpty)
    }

    @Test func callsBeforeAttachmentRunWhenRootAppears() async {
        let navigator = Navigator()
        let registry = RouteRegistry()
        registry.register(TestRoute.self) { Text(String(describing: $0)) }
        navigator.context.registry = registry
        navigator.push(TestRoute.settings, animated: false)
        let controller = navigator.makeRootController(.route(AnyRoute(TestRoute.home)))
        #expect(navigator.depth == 1, "held until the UI is on screen")

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        for _ in 0..<200 where navigator.depth < 2 { try? await Task.sleep(for: .milliseconds(10)) }

        #expect(navigator.routes == [AnyRoute(TestRoute.home), AnyRoute(TestRoute.settings)])
    }

    @Test func abandonedOperationDoesNotBlockLaterOnes() async {
        let queue = NavigationQueue()
        var ran: [Int] = []
        var timeouts = 0
        queue.onTimeout = { timeouts += 1 }

        queue.enqueue { _ in ran.append(1) } // never calls finish
        queue.enqueue { finish in ran.append(2); finish() }
        for _ in 0..<600 where !queue.isIdle {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(queue.isIdle, "the queue is used after the wait, which also keeps it alive")
        #expect(ran == [1, 2])
        #expect(timeouts == 1)
    }
}
