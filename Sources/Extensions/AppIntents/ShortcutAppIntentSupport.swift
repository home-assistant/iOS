import Foundation
import PromiseKit

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
