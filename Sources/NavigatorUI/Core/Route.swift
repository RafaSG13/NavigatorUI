import Foundation

/// A value that identifies a screen.
///
/// Conform an enum (or any `Hashable` type) to `Route` and register a view for it in a
/// ``RouteRegistry``. The same route can be pushed or presented; the presentation is chosen
/// at the call site, not baked into the type.
///
/// Features can each define their own route type. Nothing requires one app-wide enum.
public protocol Route: Hashable {}

/// A type-erased ``Route``, used wherever routes of different types share a collection
/// (stack inspection, deep-link steps).
public struct AnyRoute: Hashable, CustomStringConvertible {
    private let box: AnyHashable

    public init<R: Route>(_ route: R) {
        self.box = AnyHashable(route)
    }

    /// The wrapped route value.
    public var base: Any { box.base }

    /// The wrapped route as `R`, or `nil` if it is a different route type.
    public func `as`<R: Route>(_ type: R.Type = R.self) -> R? {
        box.base as? R
    }

    var typeID: ObjectIdentifier { ObjectIdentifier(type(of: box.base)) }

    public var description: String { String(describing: box.base) }
}
