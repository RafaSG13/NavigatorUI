import Foundation

/// Runs navigation operations strictly one at a time.
///
/// UIKit refuses (or visually glitches on) pushing during a push transition, or presenting while
/// another presentation is in flight. Every navigation call goes through this queue, and an
/// operation reports completion when its transition ends. Operations that finish synchronously
/// (unanimated, or no-ops) run immediately, so `push(..., animated: false)` is visible right away.
///
/// The queue stays blocked until the root controller is on screen, so calls made before the UI
/// exists (cold-start deep links) run once it appears.
@MainActor
final class NavigationQueue {
    typealias Finish = @MainActor () -> Void
    typealias Operation = @MainActor (_ finish: @escaping Finish) -> Void

    private final class Token {
        var isFinished = false
        var watchdog: Task<Void, Never>?
    }

    /// Longest an operation may take before it is considered lost. For example a `present`
    /// on a controller that is not in a window never reports completion.
    static let timeout: Duration = .seconds(2)

    private var pending: [Operation] = []
    private var isRunning = false
    var isBlocked = false
    var onTimeout: (@MainActor () -> Void)?

    var isIdle: Bool { !isRunning && pending.isEmpty }

    func enqueue(_ operation: @escaping Operation) {
        pending.append(operation)
        drain()
    }

    func drain() {
        guard !isRunning, !isBlocked, !pending.isEmpty else { return }
        isRunning = true
        let operation = pending.removeFirst()
        let token = Token()
        let finish: Finish = { [weak self] in
            guard !token.isFinished else { return }
            token.isFinished = true
            token.watchdog?.cancel()
            // The queue can be gone if a UIKit completion arrives after teardown.
            guard let self else { return }
            isRunning = false
            drain()
        }
        operation(finish)
        guard !token.isFinished else { return }
        token.watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.timeout)
            guard !Task.isCancelled, !token.isFinished else { return }
            self?.onTimeout?()
            finish()
        }
    }
}
