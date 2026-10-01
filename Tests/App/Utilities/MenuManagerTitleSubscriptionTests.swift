import HAKit
@testable import HomeAssistant
@testable import Shared
import Testing

private final class CancellableSpy: HACancellable {
    var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

struct MenuManagerTitleSubscriptionTests {
    @Test func cancelForwardsToTheRequestToken() {
        let token = CancellableSpy()
        let subscription = MenuManagerTitleSubscription(server: .fake(), template: "{{ 1 }}", token: token)

        #expect(subscription.server.info.name == "Fake Server")
        #expect(subscription.template == "{{ 1 }}")

        subscription.cancel()

        #expect(token.cancelCount == 1)
    }

    /// Two subscriptions with the same server and template are still different subscriptions; replacing one with
    /// the other is what cancels the old request.
    @Test func everySubscriptionIsOnlyEqualToItself() {
        let server = Server.fake()
        let first = MenuManagerTitleSubscription(server: server, template: "a", token: CancellableSpy())
        let second = MenuManagerTitleSubscription(server: server, template: "a", token: CancellableSpy())

        #expect(first == first)
        #expect(first != second)
    }
}
