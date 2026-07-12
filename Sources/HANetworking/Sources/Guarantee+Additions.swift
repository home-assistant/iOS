import Foundation
import PromiseKit

public extension Guarantee {
    // silence discarded result, like promises
    func cauterize() {}
}

public extension Promise {
    /// Bridges this promise into Swift Concurrency, returning its value or throwing its error.
    func asyncValue() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            pipe { result in
                switch result {
                case let .fulfilled(value):
                    continuation.resume(returning: value)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
