import Foundation
import PromiseKit

// https://github.com/mxcl/PromiseKit/blob/master/Documentation/CommonPatterns.md
func attemptNetworking<T>(
    maximumRetryCount: Int = 3,
    delayBeforeRetry: DispatchTimeInterval = .seconds(2),
    _ body: @escaping () -> Promise<T>
) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            guard attempts < maximumRetryCount, error is URLError else { throw error }

            if Current.isRunningTests {
                return attempt()
            } else {
                return after(delayBeforeRetry).then(on: .main, attempt)
            }
        }
    }
    return attempt()
}
