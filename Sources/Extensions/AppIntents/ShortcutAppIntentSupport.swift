import Foundation
import PromiseKit
import Shared

struct ShortcutAppIntentError: LocalizedError {
    let errorDescription: String?

    init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

extension Promise {
    func async() async throws -> T {
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

    func timeout(seconds: TimeInterval) -> Promise<T> {
        let timeout = after(seconds: seconds).then {
            Promise<T>(error: ShortcutAppIntentError(L10n.AppIntents.Error.timedOut(Int(seconds))))
        }
        return race(self, timeout)
    }

    func async(timeout seconds: TimeInterval) async throws -> T {
        try await timeout(seconds: seconds).async()
    }
}

extension Sequence {
    func asyncCompactMap<ElementOfResult>(
        _ transform: (Element) async throws -> ElementOfResult?
    ) async throws -> [ElementOfResult] {
        var result: [ElementOfResult] = []
        for element in self {
            if let transformed = try await transform(element) {
                result.append(transformed)
            }
        }
        return result
    }
}
