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
        NotificationCenter.default.post(
            name: HomeAssistantAPI.didConnectNotification,
            object: nil,
            userInfo: nil
        )

        Current.onboardingObservation.didConnect()

        return .value(())
    }
}
