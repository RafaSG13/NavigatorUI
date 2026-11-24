import SwiftUI
import UIKit

/// One screen: a hosting controller that injects its stack's ``Navigator`` into the environment
/// and exposes the screen's pop guard to UIKit.
@MainActor
final class RouteHostingController: UIHostingController<AnyView> {
    /// `nil` for a root screen that is a plain view rather than a route.
    let route: AnyRoute?
    let transition: NavigationTransition?
    private let navigator: Navigator
    private var popGuard: (@MainActor () -> Bool)?

    init(route: AnyRoute?, navigator: Navigator, content: AnyView, transition: NavigationTransition?) {
        self.route = route
        self.navigator = navigator
        self.transition = transition
        super.init(rootView: AnyView(EmptyView()))
        install(content)
        // The system back button runs this instead of popping, so a guard can refuse. Swipe-back is
        // handled separately by `StackController.gestureRecognizerShouldBegin`.
        navigationItem.backAction = UIAction { [weak self] _ in
            MainActor.assumeIsolated { self?.backButtonTapped() }
        }
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("RouteHostingController is created in code only")
    }

    /// Sets the screen's content. Decoration (user environment) goes inside so the navigator
    /// in the environment cannot be overridden by it.
    func install(_ content: AnyView) {
        let decorated = navigator.context.decorated(content)
        rootView = AnyView(
            decorated
                .environment(\.navigator, navigator)
                .onPreferenceChange(PopGuardKey.self) { [weak self] value in
                    MainActor.assumeIsolated { self?.popGuard = value?.allows }
                }
        )
    }

    func allowsPop() -> Bool {
        popGuard?() ?? true
    }

    private func backButtonTapped() {
        if allowsPop() {
            navigator.pop(force: true)
        } else {
            navigator.context.emit(.popBlocked)
        }
    }
}
