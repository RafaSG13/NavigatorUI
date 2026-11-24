import UIKit

/// The `UINavigationController` behind every stack. It owns pop interception (back button and
/// swipe-back), custom transitions, and reports user-driven changes back to its ``Navigator``.
@MainActor
final class StackController: UINavigationController {
    let navigator: Navigator
    var onDismissAttempt: (@MainActor () -> Void)?

    init(navigator: Navigator) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StackController is created in code only")
    }

    var hosts: [RouteHostingController] {
        viewControllers.compactMap { $0 as? RouteHostingController }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigator.controllerDidAppear(self)
    }

    /// UIKit logs warnings and skips work when asked to animate while off screen.
    func canAnimate(_ requested: Bool) -> Bool {
        requested && viewIfLoaded?.window != nil
    }

    /// Calls `completion` once UIKit has applied a stack change and finished its transition.
    ///
    /// UIKit defers a push or pop that is issued in the same run-loop turn as another one: the
    /// call returns, `viewControllers` is unchanged and there is no transition coordinator yet.
    /// Treating that as "done" would let the next operation start too early, so this waits
    /// (bounded; the queue watchdog is the final backstop) until `isApplied` holds.
    func afterApplied(
        animated: Bool,
        _ isApplied: @escaping @MainActor () -> Bool,
        _ completion: @escaping @MainActor () -> Void
    ) {
        waitUntilApplied(isApplied, attemptsLeft: 400) { [weak self] in
            self?.afterTransition(animated: animated, completion) ?? completion()
        }
    }

    private func waitUntilApplied(
        _ isApplied: @escaping @MainActor () -> Bool,
        attemptsLeft: Int,
        _ completion: @escaping @MainActor () -> Void
    ) {
        guard !isApplied(), attemptsLeft > 0 else { return completion() }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5)) { [weak self] in
            MainActor.assumeIsolated {
                self?.waitUntilApplied(isApplied, attemptsLeft: attemptsLeft - 1, completion) ?? completion()
            }
        }
    }

    /// Calls `completion` when the transition that was just started ends (immediately when there is none).
    private func afterTransition(animated: Bool, _ completion: @escaping @MainActor () -> Void) {
        guard animated, let coordinator = transitionCoordinator else { return completion() }
        coordinator.animate(alongsideTransition: nil) { _ in
            MainActor.assumeIsolated { completion() }
        }
    }

    func apply(_ presentation: Presentation) {
        switch presentation.kind {
        case .sheet(let detents, let showsGrabber, let isDismissDisabled, let onDismissAttempt):
            modalPresentationStyle = .pageSheet
            if let sheet = sheetPresentationController {
                sheet.detents = detents.map { $0 == .medium ? .medium() : .large() }
                sheet.prefersGrabberVisible = showsGrabber
            }
            isModalInPresentation = isDismissDisabled
            self.onDismissAttempt = onDismissAttempt
        case .fullScreen(let transition):
            modalPresentationStyle = .fullScreen
            switch transition {
            case .coverVertical: modalTransitionStyle = .coverVertical
            case .crossDissolve: modalTransitionStyle = .crossDissolve
            case .flipHorizontal: modalTransitionStyle = .flipHorizontal
            }
        }
        presentationController?.delegate = self
    }
}

extension StackController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        navigator.syncStack()
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        if let state = interactivePopGestureRecognizer?.state, state == .began || state == .changed {
            return nil
        }
        let screen = operation == .push ? toVC : fromVC
        return (screen as? RouteHostingController)?.transition?.animator(operation)
    }
}

extension StackController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        guard viewControllers.count > 1 else { return false }
        let allowed = (topViewController as? RouteHostingController)?.allowsPop() ?? true
        if !allowed { navigator.context.emit(.popBlocked) }
        return allowed
    }
}

extension StackController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        navigator.interactiveDismissDidFinish()
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        onDismissAttempt?()
    }
}
