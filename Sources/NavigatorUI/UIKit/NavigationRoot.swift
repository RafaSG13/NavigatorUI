import SwiftUI
import UIKit

/// The root of a navigation tree. Place it where you would place a `NavigationStack`.
///
/// ```swift
/// NavigationRoot(registry: registry, deepLinks: links, root: AppRoute.home)
/// // or, with a plain view as the root screen:
/// NavigationRoot(registry: registry) { HomeView() }
/// ```
///
/// Each stack is a `UINavigationController`. Screens must **not** contain their own `NavigationStack`.
/// Use `.navigationTitle`, `.toolbar` and friends inside screens as usual.
///
/// **Environment.** Screens are hosted in UIKit, so environment objects set *above* a
/// `NavigationRoot` do not reach them. Inject them with ``decorateScreens(_:)``.
/// Trait-based values (dark mode, dynamic type, layout direction) propagate through UIKit as normal.
public struct NavigationRoot: View {
    @StateObject private var navigator: Navigator
    private let registry: RouteRegistry
    private let deepLinks: DeepLinkRouter?
    private let rootContent: @MainActor () -> Navigator.RootContent
    private var decorate: (@MainActor (AnyView) -> AnyView)?

    /// Creates a root whose first screen is a plain view.
    /// - Parameters:
    ///   - navigator: Pass one to control navigation from outside the view tree.
    ///   - registry: The views for every route that may be pushed or presented.
    ///   - deepLinks: Resolves URLs received by `onOpenURL` and universal links.
    public init<Content: View>(
        navigator: Navigator? = nil,
        registry: RouteRegistry,
        deepLinks: DeepLinkRouter? = nil,
        @ViewBuilder root: @escaping () -> Content
    ) {
        _navigator = StateObject(wrappedValue: navigator ?? Navigator())
        self.registry = registry
        self.deepLinks = deepLinks
        self.rootContent = { .view(AnyView(root())) }
    }

    /// Creates a root whose first screen is a registered route.
    public init<R: Route>(
        navigator: Navigator? = nil,
        registry: RouteRegistry,
        deepLinks: DeepLinkRouter? = nil,
        root route: R
    ) {
        _navigator = StateObject(wrappedValue: navigator ?? Navigator())
        self.registry = registry
        self.deepLinks = deepLinks
        self.rootContent = { .route(AnyRoute(route)) }
    }

    /// Wraps every screen (root, pushed and modal) before it is shown. Use it to inject environment
    /// objects and values that UIKit hosting does not inherit.
    ///
    /// ```swift
    /// NavigationRoot(registry: registry, root: AppRoute.home)
    ///     .decorateScreens { $0.environmentObject(session).tint(.orange) }
    /// ```
    public func decorateScreens<Decorated: View>(_ transform: @escaping (AnyView) -> Decorated) -> NavigationRoot {
        var copy = self
        copy.decorate = { AnyView(transform($0)) }
        return copy
    }

    public var body: some View {
        RootRepresentable(navigator: navigator,
                          registry: registry,
                          deepLinks: deepLinks,
                          decorate: decorate,
                          content: rootContent())
            .ignoresSafeArea()
            .onOpenURL { _ = navigator.open($0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { _ = navigator.open(url) }
            }
    }
}

private struct RootRepresentable: UIViewControllerRepresentable {
    let navigator: Navigator
    let registry: RouteRegistry
    let deepLinks: DeepLinkRouter?
    let decorate: (@MainActor (AnyView) -> AnyView)?
    let content: Navigator.RootContent

    func makeUIViewController(context: Context) -> StackController {
        configure()
        return navigator.makeRootController(content)
    }

    func updateUIViewController(_ controller: StackController, context: Context) {
        configure()
        navigator.updateRoot(content)
    }

    static func dismantleUIViewController(_ controller: StackController, coordinator: ()) {
        controller.navigator.detach(controller)
    }

    private func configure() {
        navigator.context.registry = registry
        navigator.context.decorate = decorate
        if let deepLinks { navigator.context.deepLinks = deepLinks }
    }
}
