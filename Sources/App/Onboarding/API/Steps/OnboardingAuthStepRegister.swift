import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepRegister: OnboardingAuthPostStep {
    var connection: HAConnection
    var api: HomeAssistantAPI
    var sender: UIViewController

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.register])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        api.register()
    }
}
