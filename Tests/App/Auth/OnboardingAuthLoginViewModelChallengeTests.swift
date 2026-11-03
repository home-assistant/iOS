import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import WebKit

/// The login web view's loading state and the authentication challenges it answers: a client
/// certificate it doesn't have, one the keychain can't provide, and everything else handed to the
/// server's security exceptions.
///
/// Shared state: creating the view model runs `WebKitEnhancedSecurity.prepare`, which writes or removes
/// its override in `UserDefaults.standard`, the same key `WebKitEnhancedSecurityTests` sets and asserts.
@Suite(.sharedState)
@MainActor
struct OnboardingAuthLoginViewModelChallengeTests {
    private final class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
        func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
        func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
        func cancel(_ challenge: URLAuthenticationChallenge) {}
    }

    private func makeViewModel() throws -> OnboardingAuthLoginViewModel {
        try OnboardingAuthLoginViewModel(authDetails: OnboardingAuthDetails(
            baseURL: #require(URL(string: "http://127.0.0.1:9"))
        ))
    }

    private func challenge(method: String) -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: "127.0.0.1",
                port: 9,
                protocol: NSURLProtectionSpaceHTTPS,
                realm: nil,
                authenticationMethod: method
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: ChallengeSender()
        )
    }

    private func answer(
        _ challenge: URLAuthenticationChallenge,
        on viewModel: OnboardingAuthLoginViewModel
    ) -> URLSession.AuthChallengeDisposition? {
        var disposition: URLSession.AuthChallengeDisposition?
        viewModel.webView(viewModel.webView, didReceive: challenge) { result, _ in
            disposition = result
        }
        return disposition
    }

    @Test func aClientCertificateChallengeWithoutACertificateIsCancelled() throws {
        let viewModel = try makeViewModel()
        #expect(
            answer(challenge(method: NSURLAuthenticationMethodClientCertificate), on: viewModel)
                == .cancelAuthenticationChallenge
        )
    }

    @Test func aClientCertificateMissingFromTheKeychainIsCancelled() throws {
        let viewModel = try makeViewModel()
        viewModel.authDetails.clientCertificate = ClientCertificate(
            keychainIdentifier: "missing-\(UUID().uuidString)",
            displayName: "Missing"
        )
        #expect(
            answer(challenge(method: NSURLAuthenticationMethodClientCertificate), on: viewModel)
                == .cancelAuthenticationChallenge
        )
    }

    @Test func otherChallengesAreLeftToTheSecurityExceptions() throws {
        let viewModel = try makeViewModel()
        #expect(answer(challenge(method: NSURLAuthenticationMethodHTTPBasic), on: viewModel) != nil)
    }

    @Test func theLoadingStateFollowsNavigation() throws {
        let viewModel = try makeViewModel()

        viewModel.webView(viewModel.webView, didStartProvisionalNavigation: nil)
        #expect(viewModel.isLoading)
        viewModel.webView(viewModel.webView, didFinish: nil)
        #expect(!viewModel.isLoading)

        viewModel.webView(viewModel.webView, didStartProvisionalNavigation: nil)
        viewModel.webView(viewModel.webView, didFailProvisionalNavigation: nil, withError: URLError(.timedOut))
        #expect(!viewModel.isLoading)
    }
}
