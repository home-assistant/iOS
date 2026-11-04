import Foundation
import PromiseKit

public final class ImmediateBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    public init() {}

    public func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        wrapping(nil)
    }
}
