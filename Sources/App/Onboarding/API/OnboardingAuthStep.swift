import HAKit
import PromiseKit
import Shared

enum OnboardingAuthStepPoint: Int {
    case beforeAuth

    case beforeRegister
    case register
    case afterRegister

    case complete
}

protocol OnboardingAuthStep {
    static var supportedPoints: Set<OnboardingAuthStepPoint> { get }
    func perform(point: OnboardingAuthStepPoint) -> Promise<Void>
}

protocol OnboardingAuthPreStep: OnboardingAuthStep {
    init(authDetails: OnboardingAuthDetails, sender: UIViewController)
}

protocol OnboardingAuthPostStep: OnboardingAuthStep {
    init(api: HomeAssistantAPI, sender: UIViewController)
}
