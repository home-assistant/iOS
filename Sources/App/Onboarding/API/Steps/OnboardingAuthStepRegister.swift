import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepRegister: OnboardingAuthPostStep {
    var api: HomeAssistantAPI
    var sender: UIViewController

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.register])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        api.register()
    }
}
