import SwiftUI
import UIKit

/// Controls one navigation stack: the root stack, or the stack inside one modal.
///
/// Screens get their navigator from the environment:
///
/// ```swift
/// @Environment(\.navigator) private var navigator
/// Button("Open") { navigator.push(AppRoute.settings) }
/// ```
///
/// Calls are queued and run one at a time, in order, each after the previous transition has finished.
/// So `push(a); push(b); present(c)` is safe even when animated. Calls made before the UI is on
/// screen are held until it appears.
///
/// A navigator only touches its own stack. `push` from a screen that is covered by a modal pushes
/// onto the covered stack. `present` from a screen that is covered presents on top of the visible modal.
@MainActor
public final class Navigator: ObservableObject {
    /// Routes in this stack, bottom to top. A root screen that is a plain view (not a route) is not listed.
    @Published public internal(set) var routes: [AnyRoute] = []

    /// Number of screens in this stack, including the root screen.
    @Published public internal(set) var depth: Int = 0

    /// Receives every ``NavigationEvent`` in this navigator's tree.
    public var eventHandler: (@MainActor (NavigationEvent) -> Void)? {
        get { context.eventHandler }
        set { context.eventHandler = newValue }
    }

    /// Resolves URLs passed to ``open(_:)``.
    public var deepLinks: DeepLinkRouter? {
        get { context.deepLinks }
        set { context.deepLinks = newValue }
    }

    /// `true` for the stack inside a sheet or full-screen cover.
    public var isModal: Bool { parent != nil }

    /// `true` once a ``NavigationRoot`` has created this navigator's UIKit stack.
    public var isAttached: Bool { controller != nil }

    /// The navigator of the stack that owns the root screen.
    public var root: Navigator { parent?.root ?? self }

    let context: NavigationContext
    weak var parent: Navigator?
    weak var presented: Navigator?
    weak var controller: StackController?

    let isInert: Bool
    let presentedRoute: AnyRoute?
    var onDismiss: (@MainActor () -> Void)?
    var didFinishModal = false

    /// Creates the navigator for a root stack. Pass it to ``NavigationRoot`` to keep a handle outside the view tree
    /// (for example to open URLs from an app delegate).
    public init() {
        context = NavigationContext()
        isInert = false
        presentedRoute = nil
        context.queue.isBlocked = true
        context.queue.onTimeout = { [context] in
            context.fail("A navigation operation never completed and was abandoned after \(NavigationQueue.timeout).")
        }
    }

    init(parent: Navigator, presentedRoute: AnyRoute, onDismiss: (@MainActor () -> Void)?) {
        context = parent.context
        isInert = false
        self.parent = parent
        self.presentedRoute = presentedRoute
        self.onDismiss = onDismiss
    }

    private init(inert: Bool) {
        context = NavigationContext()
        isInert = inert
        presentedRoute = nil
    }

    /// Stand-in used when a view is rendered outside a ``NavigationRoot`` (previews). Every call is dropped and logged.
    static let inert = Navigator(inert: true)

    // MARK: - Inspection

    /// The routes of type `R` in this stack, bottom to top.
    public func routes<R: Route>(of type: R.Type) -> [R] {
        routes.compactMap { $0.as(R.self) }
    }

    public func contains<R: Route>(_ route: R) -> Bool {
        routes.contains(AnyRoute(route))
    }

    // MARK: - Stack

    /// Pushes a route onto this stack.
    public func push<R: Route>(_ route: R, animated: Bool = true, transition: NavigationTransition? = nil) {
        push(AnyRoute(route), animated: animated, transition: transition)
    }

    public func push(_ route: AnyRoute, animated: Bool = true, transition: NavigationTransition? = nil) {
        enqueue { finish in
            self.appendNow([route], animated: animated, transition: transition, completion: finish)
        }
    }

    /// Pops `count` screens. Stops at the root screen. Screens that installed a ``SwiftUI/View/popGuard(_:)``
    /// can refuse, unless `force` is `true`.
    public func pop(_ count: Int = 1, animated: Bool = true, force: Bool = false) {
        enqueue { finish in
            self.popNow(keeping: self.depth - max(count, 0), animated: animated, force: force, completion: finish)
        }
    }

    public func popToRoot(animated: Bool = true, force: Bool = false) {
        enqueue { finish in
            self.popNow(keeping: 1, animated: animated, force: force, completion: finish)
        }
    }

    /// Pops back to the topmost screen showing `route`. Logs a failure if the route is not in the stack.
    public func pop<R: Route>(to route: R, animated: Bool = true, force: Bool = false) {
        let target = AnyRoute(route)
        enqueue { finish in
            guard let index = self.controller?.hosts.lastIndex(where: { $0.route == target }) else {
                self.context.fail("pop(to: \(target)): route is not in this stack.")
                return finish()
            }
            self.popNow(keeping: index + 1, animated: animated, force: force, completion: finish)
        }
    }

    /// Replaces everything above the root screen with `routes`. Screens whose route is unchanged from the bottom
    /// are kept as they are. Does not consult pop guards.
    public func setStack(_ routes: [AnyRoute], animated: Bool = true) {
        enqueue { finish in
            self.setStackNow(routes, animated: animated, completion: finish)
        }
    }

    public func setStack<R: Route>(_ routes: [R], animated: Bool = true) {
        setStack(routes.map { AnyRoute($0) }, animated: animated)
    }

    // MARK: - Modals

    /// Presents a route modally, in its own navigation stack.
    /// - Parameter onDismiss: Called once when the modal goes away for any reason (swipe, `dismiss`, `dismissAll`).
    public func present<R: Route>(
        _ route: R,
        style: Presentation = .sheet(),
        animated: Bool = true,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        present(AnyRoute(route), style: style, animated: animated, onDismiss: onDismiss)
    }

    public func present(
        _ route: AnyRoute,
        style: Presentation = .sheet(),
        animated: Bool = true,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        enqueue { finish in
            self.presentNow(route, style: style, animated: animated, onDismiss: onDismiss) { _ in finish() }
        }
    }

    /// Goes back one level: pops if this stack has more than its root screen, otherwise dismisses this modal.
    /// Does nothing on the root stack's root screen.
    public func dismiss(animated: Bool = true, force: Bool = false) {
        enqueue { finish in
            if self.depth > 1 {
                self.popNow(keeping: self.depth - 1, animated: animated, force: force, completion: finish)
            } else if let parent = self.parent {
                parent.dismissPresentedNow(animated: animated, completion: finish)
            } else {
                finish()
            }
        }
    }

    /// Dismisses this navigator's modal, and anything presented above it, however many screens were pushed in it.
    public func dismissModal(animated: Bool = true) {
        enqueue { finish in
            guard let parent = self.parent else { return finish() }
            parent.dismissPresentedNow(animated: animated, completion: finish)
        }
    }

    /// Dismisses every modal in the tree, leaving the root stack as it is.
    public func dismissAll(animated: Bool = true) {
        enqueue { finish in
            self.root.dismissPresentedNow(animated: animated, completion: finish)
        }
    }

    // MARK: - Deep links

    /// Opens a URL through ``deepLinks``.
    /// - Returns: `false` if no router is set or no pattern accepts the URL; the navigation state is then untouched.
    @discardableResult
    public func open(_ url: URL) -> Bool {
        guard !isInert else {
            context.fail("open(\(url)): no navigator in the environment.")
            return false
        }
        guard let router = context.deepLinks, let steps = router.steps(for: url) else {
            context.emit(.deepLink(url, handled: false))
            return false
        }
        context.emit(.deepLink(url, handled: true))
        let root = self.root
        let strategy = router.strategy
        context.queue.enqueue { finish in
            switch strategy {
            case .replaceStack:
                root.dismissPresentedNow(animated: false) {
                    root.popNow(keeping: 1, animated: false, force: true) {
                        root.run(steps[...], completion: finish)
                    }
                }
            case .append:
                root.topmost.run(steps[...], completion: finish)
            }
        }
        return true
    }
}
