import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepConfig: OnboardingAuthPostStep {
    var api: HomeAssistantAPI
    var presenter: OnboardingAuthPresenter

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.afterRegister])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        api.getConfig(overrideURL: Self.signedInURL(of: api.server.info.connection))
    }

    /// The URL onboarding signed in and registered through, which is known to reach the server.
    ///
    /// Left to itself the webhook would go to the cloudhook registration just handed back, because
    /// the home network isn't known this early, and a cloudhook Home Assistant Cloud rejects would
    /// fail onboarding for a server that is reachable. `OnboardingAuth.connect` tries the internal
    /// URL first and drops it when falling back to the external one, so internal-then-external is
    /// the URL it connected through.
    static func signedInURL(of connection: ConnectionInfo) -> URL? {
        (connection.address(for: .internal) ?? connection.address(for: .external))?.sanitized()
    }
}
