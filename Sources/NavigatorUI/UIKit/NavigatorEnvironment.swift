import SwiftUI

private struct NavigatorKey: EnvironmentKey {
    static var defaultValue: Navigator {
        MainActor.assumeIsolated { Navigator.inert }
    }
}

extension EnvironmentValues {
    /// The navigator of the stack that contains this view.
    ///
    /// Outside a ``NavigationRoot`` (previews) this is an inert navigator that drops every call
    /// and logs it, so views do not crash when rendered in isolation.
    public var navigator: Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

struct PopGuard: Equatable, Sendable {
    let id = UUID()
    let allows: @MainActor @Sendable () -> Bool

    static func == (lhs: PopGuard, rhs: PopGuard) -> Bool { lhs.id == rhs.id }
}

struct PopGuardKey: PreferenceKey {
    static var defaultValue: PopGuard? { nil }

    static func reduce(value: inout PopGuard?, nextValue: () -> PopGuard?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Lets this screen refuse to be popped: back button, swipe-back, `pop`, `popToRoot`, `pop(to:)` and `dismiss`.
    ///
    /// Return `true` to allow. To ask the user first, return `false`, show your confirmation, and on
    /// confirm call `navigator.pop(force: true)`. `setStack` and deep links with
    /// ``DeepLinkRouter/Strategy/replaceStack`` do not consult guards.
    public func popGuard(_ allowsPop: @escaping @MainActor @Sendable () -> Bool) -> some View {
        preference(key: PopGuardKey.self, value: PopGuard(allows: allowsPop))
    }
}
