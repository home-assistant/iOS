import HAKit
import PromiseKit
import Shared

enum OnboardingAuthStepPoint: Int, Comparable {
    case beforeAuth

    case beforeRegister
    case register
    case afterRegister

    case complete

    static func < (lhs: OnboardingAuthStepPoint, rhs: OnboardingAuthStepPoint) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

protocol OnboardingAuthStep {
    static var supportedPoints: Set<OnboardingAuthStepPoint> { get }
    func perform(point: OnboardingAuthStepPoint) -> Promise<Void>
}

protocol OnboardingAuthPreStep: OnboardingAuthStep {
    init(authDetails: OnboardingAuthDetails, sender: UIViewController)
}

protocol OnboardingAuthPostStep: OnboardingAuthStep {
    init(connection: HAConnection, api: HomeAssistantAPI, sender: UIViewController)
}
