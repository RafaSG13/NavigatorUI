import Foundation

/// One step of a deep-link plan: push a route onto the current stack, or present it modally.
/// Steps that follow a presentation apply inside the presented modal.
public struct NavigationStep {
    let route: AnyRoute
    let presentation: Presentation?

    public static func push<R: Route>(_ route: R) -> NavigationStep {
        NavigationStep(route: AnyRoute(route), presentation: nil)
    }

    public static func present<R: Route>(_ route: R, style: Presentation = .sheet()) -> NavigationStep {
        NavigationStep(route: AnyRoute(route), presentation: style)
    }
}

/// The parts of a URL that matched a deep-link pattern.
public struct DeepLinkMatch {
    public let url: URL
    /// Values captured by `:name` segments in the pattern.
    public let parameters: [String: String]
    /// Query items. The last value wins for repeated names.
    public let query: [String: String]

    /// A path parameter, falling back to a query item of the same name.
    public subscript(name: String) -> String? {
        parameters[name] ?? query[name]
    }

    public func int(_ name: String) -> Int? {
        self[name].flatMap { Int($0) }
    }
}

/// Turns URLs into navigation plans.
///
/// ```swift
/// let links = DeepLinkRouter()
/// links.register("profile/:id") { [.push(AppRoute.profile(id: $0["id"] ?? ""))] }
/// links.register("profile/:id/settings") { match in
///     [.push(AppRoute.profile(id: match["id"] ?? "")), .push(AppRoute.settings)]
/// }
/// links.register("onboarding") { _ in [.present(AppRoute.onboarding, style: .fullScreen())] }
/// ```
///
/// **What is matched.** For custom schemes the host counts as the first path segment, so
/// `myapp://profile/123` and `myapp:///profile/123` both match `profile/:id`. For `http`/`https`
/// the host is ignored, so `https://example.com/profile/123` matches too. Literal segments are
/// case-insensitive. `*` matches any single segment.
@MainActor
public final class DeepLinkRouter {
    public enum Strategy {
        /// Dismiss every modal and pop to the root before applying the steps. Ignores pop guards.
        case replaceStack
        /// Apply the steps on top of whatever is currently showing.
        case append
    }

    public var strategy: Strategy

    private var entries: [(pattern: URLPattern, handler: @MainActor (DeepLinkMatch) -> [NavigationStep]?)] = []

    public init(strategy: Strategy = .replaceStack) {
        self.strategy = strategy
    }

    /// Registers a pattern. The first registered pattern whose handler returns steps wins.
    /// Return `nil` from the handler to reject a URL that matched structurally but is invalid
    /// (for example a non-numeric id).
    public func register(_ pattern: String, handler: @escaping @MainActor (DeepLinkMatch) -> [NavigationStep]?) {
        entries.append((URLPattern(pattern), handler))
    }

    /// Registers a pattern that pushes a single route.
    public func register<R: Route>(_ pattern: String, push route: @escaping @MainActor (DeepLinkMatch) -> R?) {
        register(pattern) { match in
            route(match).map { [NavigationStep.push($0)] }
        }
    }

    /// The plan for `url`, or `nil` if no registered pattern accepts it.
    public func steps(for url: URL) -> [NavigationStep]? {
        let components = Self.components(of: url)
        let query = Self.query(of: url)
        for entry in entries {
            guard let parameters = entry.pattern.match(components) else { continue }
            let match = DeepLinkMatch(url: url, parameters: parameters, query: query)
            if let steps = entry.handler(match), !steps.isEmpty { return steps }
        }
        return nil
    }

    static func components(of url: URL) -> [String] {
        var result: [String] = []
        let scheme = url.scheme?.lowercased()
        if scheme != "http", scheme != "https", let host = url.host, !host.isEmpty {
            result.append(host)
        }
        result.append(contentsOf: url.pathComponents.filter { $0 != "/" })
        return result
    }

    static func query(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.reduce(into: [:]) { $0[$1.name] = $1.value }
    }
}

struct URLPattern {
    enum Segment {
        case literal(String)
        case parameter(String)
        case wildcard
    }

    let segments: [Segment]

    init(_ pattern: String) {
        segments = pattern.split(separator: "/").map { part in
            if part.hasPrefix(":") { return .parameter(String(part.dropFirst())) }
            if part == "*" { return .wildcard }
            return .literal(part.lowercased())
        }
    }

    func match(_ components: [String]) -> [String: String]? {
        guard components.count == segments.count else { return nil }
        var parameters: [String: String] = [:]
        for (segment, component) in zip(segments, components) {
            switch segment {
            case .literal(let value):
                guard value == component.lowercased() else { return nil }
            case .parameter(let name):
                parameters[name] = component
            case .wildcard:
                continue
            }
        }
        return parameters
    }
}
