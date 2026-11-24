import UIKit

public enum SheetDetent: Sendable {
    case medium
    case large
}

public enum FullScreenTransition: Sendable {
    case coverVertical
    case crossDissolve
    case flipHorizontal
}

/// How a route is presented modally. Each modal gets its own navigation stack and ``Navigator``.
public struct Presentation {
    enum Kind {
        case sheet(
            detents: [SheetDetent],
            showsGrabber: Bool,
            isDismissDisabled: Bool,
            onDismissAttempt: (@MainActor () -> Void)?
        )
        case fullScreen(transition: FullScreenTransition)
    }

    let kind: Kind

    /// A page sheet.
    /// - Parameters:
    ///   - detents: Heights the sheet can rest at.
    ///   - showsGrabber: Shows the grabber handle.
    ///   - isDismissDisabled: Blocks swipe-to-dismiss. Programmatic dismissal still works.
    ///   - onDismissAttempt: Called when the user tries to swipe-dismiss a sheet with `isDismissDisabled`.
    public static func sheet(
        detents: [SheetDetent] = [.large],
        showsGrabber: Bool = false,
        isDismissDisabled: Bool = false,
        onDismissAttempt: (@MainActor () -> Void)? = nil
    ) -> Presentation {
        Presentation(kind: .sheet(detents: detents,
                                  showsGrabber: showsGrabber,
                                  isDismissDisabled: isDismissDisabled,
                                  onDismissAttempt: onDismissAttempt))
    }

    /// A full-screen cover.
    public static func fullScreen(transition: FullScreenTransition = .coverVertical) -> Presentation {
        Presentation(kind: .fullScreen(transition: transition))
    }
}

/// A custom push/pop animation.
///
/// The animator is asked for on every programmatic push and pop of a screen that was pushed
/// with this transition. Interactive swipe-back always uses the system animation so the gesture keeps working.
public struct NavigationTransition {
    let animator: @MainActor (UINavigationController.Operation) -> (any UIViewControllerAnimatedTransitioning)?

    public init(
        _ animator: @escaping @MainActor (UINavigationController.Operation)
            -> (any UIViewControllerAnimatedTransitioning)?
    ) {
        self.animator = animator
    }

    /// Cross-fades between screens.
    public static var fade: NavigationTransition {
        NavigationTransition { FadeAnimator(operation: $0) }
    }
}
