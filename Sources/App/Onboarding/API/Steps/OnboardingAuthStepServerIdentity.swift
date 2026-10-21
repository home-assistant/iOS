import PromiseKit
import Shared

/// Asks the user whether a server reporting an instance ID the app already knows, at an address it
/// does not, replaces that server or is added next to it. Runs after `OnboardingAuthStepConfig`,
/// whose `get_config` is what fills in the instance ID, and leaves the answer on the presenter for
/// `OnboardingAuth` to read when it persists the server.
struct OnboardingAuthStepServerIdentity: OnboardingAuthPostStep {
    init(api: HomeAssistantAPI, presenter: OnboardingAuthPresenter) {
        self.api = api
        self.presenter = presenter
    }

    var api: HomeAssistantAPI
    var presenter: OnboardingAuthPresenter

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.afterRegister])
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        presenter.resolvedServerIdentifier = nil

        let identity = OnboardingAuth.serverIdentity(
            for: api.server.info,
            fallback: api.server.identifier,
            existingServers: Current.servers.all
        )

        guard case let .ambiguous(existing, separateIdentifier) = identity else {
            return .value(())
        }

        Current.Log.info("server reports the instance ID of \(existing.identifier) at another address, asking")

        return Promise { seal in
            let request = OnboardingServerIdentityRequest(
                newServer: ServerIdentityConflictingServer(info: api.server.info),
                existingServer: ServerIdentityConflictingServer(info: existing.info),
                onDecision: { decision in
                    presenter.resolvedServerIdentifier = decision == .replace
                        ? existing.identifier
                        : separateIdentifier
                    presenter.dismissServerIdentityRequest()
                    seal.fulfill(())
                },
                onCancel: {
                    presenter.dismissServerIdentityRequest()
                    seal.reject(PMKError.cancelled)
                }
            )

            presenter.present(serverIdentityRequest: request)
        }
    }
}
