import Foundation
import OSLog
import SwiftUI

/// Something that happened in the navigation tree.
/// Observe through ``Navigator/eventHandler`` for analytics or debugging.
public enum NavigationEvent {
    /// A stack changed (push, pop, swipe-back, replace). Carries the routes of that stack.
    case stackChanged(routes: [AnyRoute])
    case presented(AnyRoute)
    /// A modal went away, by any means. Carries the route it was presented with.
    case dismissed(AnyRoute?)
    /// A pop was refused by a ``SwiftUI/View/popGuard(_:)``.
    case popBlocked
    case deepLink(URL, handled: Bool)
    /// An operation could not be carried out (unregistered route, no presenter, ...).
    case failure(String)
}

/// State shared by every navigator in one tree (a root and all of its modals).
@MainActor
final class NavigationContext {
    var registry = RouteRegistry()
    var deepLinks: DeepLinkRouter?
    var decorate: (@MainActor (AnyView) -> AnyView)?
    var eventHandler: (@MainActor (NavigationEvent) -> Void)?
    let queue = NavigationQueue()

    private let logger = Logger(subsystem: "NavigatorUI", category: "Navigation")

    func emit(_ event: NavigationEvent) {
        eventHandler?(event)
    }

    func fail(_ message: String) {
        logger.error("\(message, privacy: .public)")
        emit(.failure(message))
    }

    func decorated(_ view: AnyView) -> AnyView {
        decorate?(view) ?? view
    }
}
