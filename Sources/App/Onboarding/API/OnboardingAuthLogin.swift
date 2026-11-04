import Foundation
import PromiseKit
import Shared

struct OnboardingAuthLoginResult {
    let code: String
    /// Server base URL the web view ended on; may differ in port/scheme from the URL we started with.
    let resolvedURL: URL?
}

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, presenter: OnboardingAuthPresenter)
        -> Promise<OnboardingAuthLoginResult>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    func open(
        authDetails: OnboardingAuthDetails,
        presenter: OnboardingAuthPresenter
    ) -> Promise<OnboardingAuthLoginResult> {
        Current.Log.verbose(authDetails.url)

        let viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
        presenter.push(.login(viewModel))

        // Deliberately not popping here: on success the flow advances by replacing the pushed
        // destination (device naming, permissions); the servers list pops only when the flow ends.
        return viewModel.resultPromise
    }
}
