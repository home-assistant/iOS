import Foundation

/// Keeps overlapping commands from overwriting each other.
///
/// Control Center invites rapid presses. Three taps on Next send three commands, and the read-back
/// for the first can arrive after the third has landed — which would put the card back on a track
/// the user has already skipped past. Each command claims a generation before it goes out; only the
/// newest generation may write, and starting one cancels the reconciliation still running for the
/// last.
@MainActor
public final class RemoteMediaReconciliationGate {
    private var generation = 0
    private var task: Task<Void, Never>?

    public init() {}

    public var current: Int { generation }

    /// Claims the next generation and cancels whatever the previous one was still doing.
    public func begin() -> Int {
        task?.cancel()
        task = nil
        generation += 1
        return generation
    }

    /// Whether a result belonging to `generation` is still the newest word on the subject.
    public func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation
    }

    public func track(_ task: Task<Void, Never>, for generation: Int) {
        guard isCurrent(generation) else {
            task.cancel()
            return
        }
        self.task = task
    }

    /// Clears the tracked task once it finishes, if it is still the current one.
    public func finish(_ generation: Int) {
        guard isCurrent(generation) else { return }
        task = nil
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
