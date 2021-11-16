import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepModels: OnboardingAuthPostStep {
    var api: HomeAssistantAPI
    var sender: UIViewController

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.afterRegister])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Current.modelManager.fetch(apis: [api])
    }
}
