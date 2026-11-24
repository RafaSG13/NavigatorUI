import SwiftUI

/// Maps route types to the views that render them.
///
/// ```swift
/// let registry = RouteRegistry()
/// registry.register(AppRoute.self) { route in
///     switch route {
///     case .profile(let id): ProfileView(id: id)
///     case .settings: SettingsView()
///     }
/// }
/// ```
///
/// Feature modules can expose their own registry and the app combines them with ``include(_:)``.
/// Views are built once, when the route is pushed or presented. A pushed screen that must react
/// to later state changes should own or observe that state itself.
@MainActor
public final class RouteRegistry {
    private var builders: [ObjectIdentifier: @MainActor (AnyRoute) -> AnyView?] = [:]

    public init() {}

    /// Registers the view builder for every value of `type`.
    /// A later registration for the same type replaces the earlier one.
    public func register<R: Route, Content: View>(
        _ type: R.Type,
        @ViewBuilder content: @escaping @MainActor (R) -> Content
    ) {
        builders[ObjectIdentifier(type)] = { route in
            guard let typed = route.as(R.self) else { return nil }
            return AnyView(content(typed))
        }
    }

    /// Copies every registration from `other`. On conflict, `other` wins.
    public func include(_ other: RouteRegistry) {
        builders.merge(other.builders) { _, new in new }
    }

    func view(for route: AnyRoute) -> AnyView? {
        builders[route.typeID].flatMap { $0(route) }
    }
}
