import SwiftUI
import UIKit

/// Glue between a navigator and its UIKit stack. Called by the UIKit layer.
extension Navigator {
    enum RootContent {
        case route(AnyRoute)
        case view(AnyView)
    }

    func makeHost(for route: AnyRoute, transition: NavigationTransition?) -> RouteHostingController? {
        guard let view = context.registry.view(for: route) else {
            context.fail("No view registered for \(type(of: route.base)) (\(route)).")
            return nil
        }
        return makeHost(route: route, content: view, transition: transition)
    }

    func makeHost(route: AnyRoute?, content: AnyView, transition: NavigationTransition?) -> RouteHostingController {
        RouteHostingController(route: route, navigator: self, content: content, transition: transition)
    }

    func makeRootController(_ content: RootContent) -> StackController {
        let controller = StackController(navigator: self)
        let host: RouteHostingController
        switch content {
        case .route(let route):
            if let view = context.registry.view(for: route) {
                host = makeHost(route: route, content: view, transition: nil)
            } else {
                context.fail("Root route \(route) has no registered view.")
                host = makeHost(route: route, content: AnyView(EmptyView()), transition: nil)
            }
        case .view(let view):
            host = makeHost(route: nil, content: view, transition: nil)
        }
        controller.setViewControllers([host], animated: false)
        self.controller = controller
        syncStack()
        return controller
    }

    /// Re-renders the root screen when it is a plain view.
    func updateRoot(_ content: RootContent) {
        guard case .view(let view) = content,
              let host = controller?.hosts.first, host.route == nil else { return }
        host.install(view)
    }

    func detach(_ controller: StackController) {
        guard self.controller === controller else { return }
        self.controller = nil
        if parent == nil { context.queue.isBlocked = true }
    }

    /// The root controller is on screen: release held operations.
    func controllerDidAppear(_ controller: StackController) {
        guard parent == nil, self.controller === controller, context.queue.isBlocked else { return }
        context.queue.isBlocked = false
        context.queue.drain()
    }

    func syncStack() {
        guard let controller else {
            routes = []
            depth = 0
            return
        }
        let newRoutes = controller.hosts.compactMap(\.route)
        if newRoutes != routes {
            routes = newRoutes
            context.emit(.stackChanged(routes: newRoutes))
        }
        if depth != controller.viewControllers.count { depth = controller.viewControllers.count }
    }

    /// The system dismissed this modal (swipe). Everything presented above it is gone too.
    func interactiveDismissDidFinish() {
        presented?.interactiveDismissDidFinish()
        finishModal()
    }

    func finishModal() {
        guard parent != nil, !didFinishModal else { return }
        didFinishModal = true
        if parent?.presented === self { parent?.presented = nil }
        context.emit(.dismissed(presentedRoute))
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }
}
