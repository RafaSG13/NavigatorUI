import UIKit

@MainActor
final class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let operation: UINavigationController.Operation

    init(operation: UINavigationController.Operation) {
        self.operation = operation
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.25
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let from = transitionContext.view(forKey: .from),
              let incoming = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        let isPush = operation == .push
        if isPush {
            incoming.alpha = 0
            container.addSubview(incoming)
        } else {
            container.insertSubview(incoming, belowSubview: from)
        }
        UIView.animate(withDuration: transitionDuration(using: transitionContext)) {
            if isPush { incoming.alpha = 1 } else { from.alpha = 0 }
        } completion: { _ in
            from.alpha = 1
            incoming.alpha = 1
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
