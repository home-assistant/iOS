import Foundation

public extension HAWatchConnectivity {
    /// Identifies a single registration in an `Observable.store`. Distinct instances are distinct keys
    /// even when they share a queue, so multiple observers can register on `.main`.
    struct Observation: Hashable {
        public let queue: DispatchQueue
        private let id = UUID()

        public init(queue: DispatchQueue = .main) {
            self.queue = queue
        }

        public static func == (lhs: Observation, rhs: Observation) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    /// Opaque handle returned by `observe(_:)`, passed back to `unobserve(_:)`.
    struct ObservationToken: Hashable {
        fileprivate let id = UUID()
    }

    /// A queue-aware multicast registry reproducing both idioms the app uses: the
    /// `observations.store[.init(queue:)] = { … }` set idiom and the `observe { … }` / `unobserve(token)`
    /// token idiom. Handlers are always dispatched async on their registered queue (default `.main`),
    /// never on the WatchConnectivity delegate queue.
    final class Observable<T> {
        private let lock = NSLock()
        private var storeStorage: [Observation: (T) -> Void] = [:]
        private var tokenStorage: [ObservationToken: (queue: DispatchQueue, handler: (T) -> Void)] = [:]

        init() {}

        public var observations: Observable<T> { self }

        public var store: [Observation: (T) -> Void] {
            get {
                lock.lock(); defer { lock.unlock() }
                return storeStorage
            }
            set {
                lock.lock(); defer { lock.unlock() }
                storeStorage = newValue
            }
            // Writeback mutations (`store[observation] = handler`) go through `_modify`, which holds
            // the lock across the whole read-modify-write so concurrent registrations can't be lost
            // to a get-copy → mutate → set interleave.
            _modify {
                lock.lock(); defer { lock.unlock() }
                yield &storeStorage
            }
        }

        /// Register a handler. Capture `[weak self]` in the handler — the registry retains it until
        /// `unobserve(_:)`.
        @discardableResult
        public func observe(queue: DispatchQueue = .main, _ handler: @escaping (T) -> Void) -> ObservationToken {
            let token = ObservationToken()
            lock.lock()
            tokenStorage[token] = (queue, handler)
            lock.unlock()
            return token
        }

        public func unobserve(_ token: ObservationToken) {
            lock.lock()
            tokenStorage[token] = nil
            lock.unlock()
        }

        func notify(_ value: T) {
            lock.lock()
            let storeSnapshot = storeStorage
            let tokenSnapshot = tokenStorage
            lock.unlock()

            for (observation, handler) in storeSnapshot {
                observation.queue.async { handler(value) }
            }
            for entry in tokenSnapshot.values {
                entry.queue.async { entry.handler(value) }
            }
        }
    }
}
