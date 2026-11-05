import Foundation
import HAKit

/// Keeps mirror writes in the order their saves committed under the server cache lock.
///
/// Mirror writes are database I/O, so they run outside that lock. Two saves of the same server can then
/// reach the mirror in the opposite order they were committed, leaving the mirror with the older value.
/// Each save takes a ticket while it still holds the lock, and a write is skipped when a later ticket for
/// the same key, or a later clear of the whole mirror, has already landed.
public final class ServerManagerMirrorWriteSequencer {
    public typealias Ticket = UInt64

    private struct State {
        var next: Ticket = 0
        var applied: [String: Ticket] = [:]
        var clearedAt: Ticket = 0
    }

    private let state = HAProtected<State>(value: .init())
    private let writeLock = NSLock()

    public init() {}

    /// Takes the next ticket. Call it while holding the lock that orders the saves.
    public func ticket() -> Ticket {
        state.mutate { state in
            state.next += 1
            return state.next
        }
    }

    /// Runs `write` for `key` unless a later ticket already wrote or cleared it. Returns whether it ran.
    @discardableResult
    public func apply(_ ticket: Ticket, key: String, write: () -> Void) -> Bool {
        writeLock.lock()
        defer { writeLock.unlock() }

        let superseded = state.read { state in
            state.applied[key, default: 0] >= ticket || state.clearedAt >= ticket
        }
        guard !superseded else { return false }

        write()
        state.mutate { state in
            state.applied[key] = ticket
        }
        return true
    }

    /// Clears the whole mirror unless a later clear already landed. `clear` receives the keys a later ticket
    /// already wrote, which it must keep: those rows are newer than this clear. Returns whether it ran.
    @discardableResult
    public func applyClear(_ ticket: Ticket, clear: (_ keeping: Set<String>) -> Void) -> Bool {
        writeLock.lock()
        defer { writeLock.unlock() }

        let keeping = state.read { state -> Set<String>? in
            guard state.clearedAt < ticket else { return nil }
            return Set(state.applied.filter { $0.value > ticket }.keys)
        }
        guard let keeping else { return false }

        clear(keeping)
        state.mutate { state in
            state.clearedAt = ticket
            state.applied = state.applied.filter { keeping.contains($0.key) }
        }
        return true
    }
}
