@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct OnboardingServersListViewModelTests {
    @Test func testInitAddsSelfAsObserver() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()
        assert(sut.discoveredInstances.isEmpty)
        assert((mockBonjour.observer as? OnboardingServersListViewModel) != nil)
    }

    @Test func testStartDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.startDiscovery()
        assert(sut.discoveredInstances.isEmpty)
        assert(mockBonjour.startCalled)
    }

    @Test func testStopDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.stopDiscovery()
        assert(mockBonjour.stopCalled)
    }

    @Test func testSelectInstance() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()
        let instance = DiscoveredHomeAssistant(
            manualURL: URL(string: "http://192.168.0.1:8123")!,
            name: "Home"
        )
        let dummyController = await UIViewController()
        sut.selectInstance(instance, controller: dummyController)

        assert(sut.currentlyInstanceLoading == instance)
    }

    @Test func testResetFlow() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.resetFlow()
        assert(sut.currentlyInstanceLoading == nil)
        assert(sut.isLoading == false)
    }
}
