import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepNotify: OnboardingAuthPostStep {
    var api: HomeAssistantAPI
    var sender: UIViewController

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.complete])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        // actually persists to outside-onboarding
        Current.servers.add(identifier: api.server.identifier, serverInfo: api.server.info)
        // not super necessary but prevents making a duplicate connection during this session
        Current.cachedApis[api.server.identifier] = api

        NotificationCenter.default.post(
            name: HomeAssistantAPI.didConnectNotification,
            object: nil,
            userInfo: nil
        )

        Current.onboardingObservation.didConnect()

        return .value(())
    }
}
