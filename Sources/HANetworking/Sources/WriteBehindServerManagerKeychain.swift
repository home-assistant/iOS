import Foundation
import HAKit

/// Decorates a `ServerManagerKeychain` so writes return immediately: values are kept in an
/// in-memory overlay and flushed to the wrapped Keychain on a serial background executor.
///
/// `SecItemUpdate`/`SecItemDelete` perform synchronous XPC to securityd, which can take seconds
/// when the daemon is busy (e.g. right after unlock); saving server info during token refresh on
/// the main thread was one of the app's top field hangs. Reads consult the overlay first, so
/// read-after-write stays consistent even in processes that bypass the in-memory server cache
/// (app extensions, where caching is restricted).
public final class WriteBehindServerManagerKeychain: ServerManagerKeychain {
    private enum PendingWrite: Equatable {
        case set(Data)
        case remove
    }

    private struct Overlay {
        // Masks the wrapped keychain's existing entries until the queued removeAll flushes.
        var maskingRemoveAll = false
        // Each write gets a generation so a flush only clears the overlay entry it actually
        // persisted; a newer write for the same key stays visible until its own flush runs.
        var generation: UInt64 = 0
        var writes = [String: (generation: UInt64, write: PendingWrite)]()

        mutating func append(_ write: PendingWrite, key: String) {
            generation += 1
            writes[key] = (generation, write)
        }
    }

    private let upstream: ServerManagerKeychain
    private let overlay = HAProtected<Overlay>(value: .init())
    private let flushExecutor: (@escaping () -> Void) -> Void

    private static let flushQueue = DispatchQueue(label: "server-keychain-write-behind", qos: .utility)

    public init(
        upstream: ServerManagerKeychain,
        flushExecutor: ((@escaping () -> Void) -> Void)? = nil
    ) {
        self.upstream = upstream
        self.flushExecutor = flushExecutor ?? { work in Self.flushQueue.async(execute: work) }
    }

    public func set(_ value: Data, key: String) throws {
        overlay.mutate { overlay in
            overlay.append(.set(value), key: key)
        }
        flushExecutor { [self] in
            flush(key: key)
        }
    }

    public func remove(_ key: String) throws {
        overlay.mutate { overlay in
            overlay.append(.remove, key: key)
        }
        flushExecutor { [self] in
            flush(key: key)
        }
    }

    public func removeAll() throws {
        overlay.mutate { overlay in
            overlay.maskingRemoveAll = true
            overlay.writes = [:]
        }
        flushExecutor { [self] in
            do {
                try upstream.removeAll()
            } catch {
                HANetworkingEnvironment.current.log.error("failed to flush keychain removeAll: \(error)")
            }
            overlay.mutate { overlay in
                overlay.maskingRemoveAll = false
            }
        }
    }

    public func getData(_ key: String) throws -> Data? {
        enum Overlaid {
            case value(Data?)
            case upstream
        }

        let overlaid = overlay.read { overlay -> Overlaid in
            switch overlay.writes[key]?.write {
            case let .set(data): return .value(data)
            case .remove: return .value(nil)
            case nil: return overlay.maskingRemoveAll ? .value(nil) : .upstream
            }
        }

        switch overlaid {
        case let .value(data): return data
        case .upstream: return try upstream.getData(key)
        }
    }

    public func allKeys() -> [String] {
        let (snapshot, upstreamMasked) = overlay.read { ($0.writes, $0.maskingRemoveAll) }

        var keys = Set(upstreamMasked ? [] : upstream.allKeys())
        for (key, pending) in snapshot {
            switch pending.write {
            case .set: keys.insert(key)
            case .remove: keys.remove(key)
            }
        }
        return Array(keys)
    }

    private func flush(key: String) {
        // Take the newest pending write for the key; earlier queued flushes for the same key
        // become no-ops, so a rapid set/set or set/remove sequence lands only its final state.
        guard let pending = overlay.read({ $0.writes[key] }) else { return }

        do {
            switch pending.write {
            case let .set(data): try upstream.set(data, key: key)
            case .remove: try upstream.remove(key)
            }
        } catch {
            // Keep the pending write on failure so readers still see it and the next flush
            // for this key retries it.
            HANetworkingEnvironment.current.log.error("failed to flush keychain write for \(key): \(error)")
            return
        }

        // Only clear the entry that was just persisted: a write that raced in during the
        // upstream call must stay visible to readers until its own flush lands.
        overlay.mutate { overlay in
            if overlay.writes[key]?.generation == pending.generation {
                overlay.writes[key] = nil
            }
        }
    }
}
