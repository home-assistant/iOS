@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

@Suite(.sharedState)
struct OnboardingNavigationTests {
    @Test func testOnboardingNavigationWhenNoServers() async throws {
        Current.servers = FakeServerManager(initial: 0)
        let result = OnboardingNavigation.requiredOnboardingStyle
        assert(result == .required)
    }
}
