import SwiftUI
import UIKit

/// The work behind the public API. Each `...Now` method acts immediately and reports completion; the public
/// methods wrap them in the serial queue.
extension Navigator {
    func enqueue(_ operation: @escaping NavigationQueue.Operation) {
        guard !isInert else {
            context.fail("Navigation call ignored: no navigator in the environment. Is the view in a NavigationRoot?")
            return
        }
        context.queue.enqueue(operation)
    }

    /// The navigator of the visible modal above this one, or `self` when nothing is presented.
    var topmost: Navigator {
        var navigator = self
        while let next = navigator.presented, next.controller != nil { navigator = next }
        return navigator
    }

    func appendNow(
        _ routes: [AnyRoute],
        animated: Bool,
        transition: NavigationTransition?,
        completion: @escaping @MainActor () -> Void
    ) {
        guard let controller else { return completion() }
        let hosts = routes.compactMap { makeHost(for: $0, transition: transition) }
        guard let last = hosts.last else { return completion() }
        let animate = controller.canAnimate(animated)
        if hosts.count == 1 {
            controller.pushViewController(last, animated: animate)
        } else {
            controller.setViewControllers(controller.viewControllers + hosts, animated: animate)
        }
        syncStack()
        let isApplied: @MainActor () -> Bool = { controller.viewControllers.contains { $0 === last } }
        controller.afterApplied(animated: animate, isApplied) {
            self.syncStack()
            completion()
        }
    }

    func popNow(
        keeping keep: Int,
        animated: Bool,
        force: Bool,
        completion: @escaping @MainActor () -> Void
    ) {
        guard let controller else { return completion() }
        let keep = max(keep, 1)
        guard keep < controller.viewControllers.count else { return completion() }
        let removed = controller.viewControllers[keep...].reversed()
        if !force, removed.contains(where: { ($0 as? RouteHostingController)?.allowsPop() == false }) {
            context.emit(.popBlocked)
            return completion()
        }
        let animate = controller.canAnimate(animated)
        controller.popToViewController(controller.viewControllers[keep - 1], animated: animate)
        syncStack()
        let isApplied: @MainActor () -> Bool = { controller.viewControllers.count <= keep }
        controller.afterApplied(animated: animate, isApplied) {
            self.syncStack()
            completion()
        }
    }

    func setStackNow(
        _ routes: [AnyRoute],
        animated: Bool,
        completion: @escaping @MainActor () -> Void
    ) {
        guard let controller, let rootScreen = controller.viewControllers.first else { return completion() }
        let existing = Array(controller.viewControllers.dropFirst())
        var result = [rootScreen]
        var reusing = true
        for (index, route) in routes.enumerated() {
            if reusing, index < existing.count, (existing[index] as? RouteHostingController)?.route == route {
                result.append(existing[index])
                continue
            }
            reusing = false
            if let host = makeHost(for: route, transition: nil) { result.append(host) }
        }
        let animate = controller.canAnimate(animated)
        controller.setViewControllers(result, animated: animate)
        syncStack()
        let isApplied: @MainActor () -> Bool = {
            controller.viewControllers.count == result.count
                && zip(controller.viewControllers, result).allSatisfy { $0 === $1 }
        }
        controller.afterApplied(animated: animate, isApplied) {
            self.syncStack()
            completion()
        }
    }

    func presentNow(
        _ route: AnyRoute,
        style: Presentation,
        animated: Bool,
        onDismiss: (@MainActor () -> Void)?,
        completion: @escaping @MainActor (Navigator?) -> Void
    ) {
        let presenter = topmost
        guard let presenterController = presenter.controller else {
            context.fail("present(\(route)): the navigator is not attached to a NavigationRoot.")
            return completion(nil)
        }
        guard presenterController.presentedViewController == nil else {
            context.fail("present(\(route)): something else is already presented over this stack.")
            return completion(nil)
        }
        guard let view = context.registry.view(for: route) else {
            context.fail("present(\(route)): no view registered for \(type(of: route.base)).")
            return completion(nil)
        }

        let child = Navigator(parent: presenter, presentedRoute: route, onDismiss: onDismiss)
        let modal = StackController(navigator: child)
        modal.setViewControllers([child.makeHost(route: route, content: view, transition: nil)], animated: false)
        child.controller = modal
        modal.apply(style)
        presenter.presented = child
        child.syncStack()
        context.emit(.presented(route))
        presenterController.present(modal, animated: presenterController.canAnimate(animated)) {
            completion(child)
        }
    }

    func dismissPresentedNow(animated: Bool, completion: @escaping @MainActor () -> Void) {
        guard let controller, controller.presentedViewController != nil else { return completion() }
        var chain: [Navigator] = []
        var next = presented
        while let navigator = next {
            chain.append(navigator)
            next = navigator.presented
        }
        // Dismiss from the presenter: calling `dismiss` on a modal that has its own presented modal
        // would dismiss only the inner one.
        controller.dismiss(animated: controller.canAnimate(animated)) {
            chain.reversed().forEach { $0.finishModal() }
            completion()
        }
    }

    /// Applies a deep-link plan starting at this navigator. Pushes in a row are applied as a single stack change.
    func run(_ steps: ArraySlice<NavigationStep>, completion: @escaping @MainActor () -> Void) {
        guard let first = steps.first else { return completion() }
        guard let style = first.presentation else {
            let pushes = steps.prefix { $0.presentation == nil }
            let rest = steps.dropFirst(pushes.count)
            appendNow(pushes.map(\.route), animated: rest.isEmpty, transition: nil) {
                self.run(rest, completion: completion)
            }
            return
        }
        presentNow(first.route, style: style, animated: true, onDismiss: nil) { child in
            guard let child else { return completion() }
            child.run(steps.dropFirst(), completion: completion)
        }
    }
}
