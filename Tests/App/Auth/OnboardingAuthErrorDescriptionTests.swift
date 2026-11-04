import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// The message each onboarding failure shows: every kind has one, and a missing local network
/// permission says so before the system's own wording.
struct OnboardingAuthErrorDescriptionTests {
    private enum PlainError: Error {
        case failed
    }

    @Test func everyKindHasADescription() {
        let kinds: [OnboardingAuthError.ErrorKind] = [
            .invalidURL,
            .basicAuth,
            .authenticationUnsupported("digest"),
            .sslUntrusted([URLError(.serverCertificateUntrusted), URLError(.serverCertificateHasBadDate)]),
            .clientCertificateUnsupported,
            .clientCertificateRequired,
            .clientCertificateError(PlainError.failed),
            .other(URLError(.timedOut)),
            .other(PlainError.failed),
        ]
        for kind in kinds {
            let description = OnboardingAuthError(kind: kind).errorDescription
            #expect(description?.isEmpty == false, "\(kind) has no description")
        }
        #expect(
            OnboardingAuthError(kind: .authenticationUnsupported("digest")).errorDescription?
                .contains("digest") == true
        )
    }

    @Test func aMissingLocalNetworkPermissionIsExplainedFirst() throws {
        let underlying = URLError(.notConnectedToInternet)
        let description = try #require(OnboardingAuthError(kind: .other(underlying)).errorDescription)
        #expect(description.hasPrefix(L10n.Onboarding.ConnectionTestResult.LocalNetworkPermission.description))
        #expect(description.hasSuffix(underlying.localizedDescription))
    }

    @Test func aLongResponseIsTruncated() throws {
        let error = OnboardingAuthError(kind: .basicAuth, data: Data(String(repeating: "a", count: 2000).utf8))
        let response = try #require(error.responseString)
        #expect(response.count == 1024)
        #expect(response.hasSuffix("…"))
        #expect(OnboardingAuthError(kind: .basicAuth).responseString == nil)
    }
}
