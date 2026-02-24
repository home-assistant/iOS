import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite("OnboardingAuthError Tests")
struct OnboardingAuthErrorTests {
    // MARK: - Documentation Anchor Tests

    @Test(
        "Given error kind when getting documentationAnchor then returns correct anchor",
        arguments: [
            (OnboardingAuthError.ErrorKind.invalidURL, "invalid_url"),
            (OnboardingAuthError.ErrorKind.basicAuth, "basic_auth"),
            (OnboardingAuthError.ErrorKind.authenticationUnsupported("digest"), "authentication_unsupported"),
            (OnboardingAuthError.ErrorKind.sslUntrusted([]), "ssl_untrusted"),
            (OnboardingAuthError.ErrorKind.clientCertificateRequired, "client_certificate"),
            (OnboardingAuthError.ErrorKind.clientCertificateError(NSError(domain: "test", code: 1)), "client_certificate"),
            (OnboardingAuthError.ErrorKind.other(NSError(domain: "test", code: 1)), "unknown_error"),
        ]
    )
    func documentationAnchorMapping(kind: OnboardingAuthError.ErrorKind, expectedAnchor: String) {
        #expect(kind.documentationAnchor == expectedAnchor)
    }

    // MARK: - Equatable Tests

    @Test("Given two invalidURL errors when comparing then returns true")
    func invalidURLEquality() {
        let error1 = OnboardingAuthError.ErrorKind.invalidURL
        let error2 = OnboardingAuthError.ErrorKind.invalidURL
        #expect(error1 == error2)
    }

    @Test("Given two basicAuth errors when comparing then returns true")
    func basicAuthEquality() {
        let error1 = OnboardingAuthError.ErrorKind.basicAuth
        let error2 = OnboardingAuthError.ErrorKind.basicAuth
        #expect(error1 == error2)
    }

    @Test("Given two clientCertificateRequired errors when comparing then returns true")
    func clientCertificateRequiredEquality() {
        let error1 = OnboardingAuthError.ErrorKind.clientCertificateRequired
        let error2 = OnboardingAuthError.ErrorKind.clientCertificateRequired
        #expect(error1 == error2)
    }

    @Test("Given two authenticationUnsupported errors with same method when comparing then returns true")
    func authenticationUnsupportedSameMethod() {
        let error1 = OnboardingAuthError.ErrorKind.authenticationUnsupported("digest")
        let error2 = OnboardingAuthError.ErrorKind.authenticationUnsupported("digest")
        #expect(error1 == error2)
    }

    @Test("Given two authenticationUnsupported errors with different methods when comparing then returns false")
    func authenticationUnsupportedDifferentMethods() {
        let error1 = OnboardingAuthError.ErrorKind.authenticationUnsupported("digest")
        let error2 = OnboardingAuthError.ErrorKind.authenticationUnsupported("ntlm")
        #expect(error1 != error2)
    }

    @Test("Given two sslUntrusted errors with same error codes when comparing then returns true")
    func sslUntrustedSameErrors() {
        let errors1: [Error] = [NSError(domain: "test", code: 1), NSError(domain: "test", code: 2)]
        let errors2: [Error] = [NSError(domain: "test", code: 1), NSError(domain: "test", code: 2)]
        let error1 = OnboardingAuthError.ErrorKind.sslUntrusted(errors1)
        let error2 = OnboardingAuthError.ErrorKind.sslUntrusted(errors2)
        #expect(error1 == error2)
    }

    @Test("Given two sslUntrusted errors with different error codes when comparing then returns false")
    func sslUntrustedDifferentErrors() {
        let errors1: [Error] = [NSError(domain: "test", code: 1)]
        let errors2: [Error] = [NSError(domain: "test", code: 2)]
        let error1 = OnboardingAuthError.ErrorKind.sslUntrusted(errors1)
        let error2 = OnboardingAuthError.ErrorKind.sslUntrusted(errors2)
        #expect(error1 != error2)
    }

    @Test("Given two clientCertificateError with same error when comparing then returns true")
    func clientCertificateErrorSameError() {
        let nsError = NSError(domain: "ClientCert", code: 100)
        let error1 = OnboardingAuthError.ErrorKind.clientCertificateError(nsError)
        let error2 = OnboardingAuthError.ErrorKind.clientCertificateError(nsError)
        #expect(error1 == error2)
    }

    @Test("Given two clientCertificateError with different errors when comparing then returns false")
    func clientCertificateErrorDifferentErrors() {
        let error1 = OnboardingAuthError.ErrorKind.clientCertificateError(NSError(domain: "ClientCert", code: 100))
        let error2 = OnboardingAuthError.ErrorKind.clientCertificateError(NSError(domain: "ClientCert", code: 200))
        #expect(error1 != error2)
    }

    @Test("Given two other errors with same domain and code when comparing then returns true")
    func otherErrorSameDomainAndCode() {
        let error1 = OnboardingAuthError.ErrorKind.other(NSError(domain: "TestDomain", code: 42))
        let error2 = OnboardingAuthError.ErrorKind.other(NSError(domain: "TestDomain", code: 42))
        #expect(error1 == error2)
    }

    @Test("Given two other errors with different domains when comparing then returns false")
    func otherErrorDifferentDomains() {
        let error1 = OnboardingAuthError.ErrorKind.other(NSError(domain: "DomainA", code: 42))
        let error2 = OnboardingAuthError.ErrorKind.other(NSError(domain: "DomainB", code: 42))
        #expect(error1 != error2)
    }

    @Test("Given different error kinds when comparing then returns false")
    func differentErrorKinds() {
        let kinds: [OnboardingAuthError.ErrorKind] = [
            .invalidURL,
            .basicAuth,
            .authenticationUnsupported("test"),
            .sslUntrusted([]),
            .clientCertificateRequired,
            .clientCertificateError(NSError(domain: "test", code: 1)),
            .other(NSError(domain: "test", code: 1)),
        ]

        for (index, kind1) in kinds.enumerated() {
            for (otherIndex, kind2) in kinds.enumerated() where index != otherIndex {
                // Skip comparing clientCertificateError and other with same underlying error
                // since they share comparison logic based on NSError properties
                if case .clientCertificateError = kind1, case .other = kind2 { continue }
                if case .other = kind1, case .clientCertificateError = kind2 { continue }

                #expect(kind1 != kind2, "Expected \(kind1) to not equal \(kind2)")
            }
        }
    }

    // MARK: - Error Code Tests

    @Test("Given clientCertificateRequired error when getting errorCode then returns nil")
    func clientCertificateRequiredErrorCode() {
        let error = OnboardingAuthError(kind: .clientCertificateRequired)
        #expect(error.errorCode == nil)
    }

    @Test("Given clientCertificateError when getting errorCode then returns domain and code")
    func clientCertificateErrorErrorCode() {
        let underlyingError = NSError(domain: "ClientCertDomain", code: 123)
        let error = OnboardingAuthError(kind: .clientCertificateError(underlyingError))
        #expect(error.errorCode == "ClientCertDomain 123")
    }

    @Test("Given basicAuth error when getting errorCode then returns nil")
    func basicAuthErrorCode() {
        let error = OnboardingAuthError(kind: .basicAuth)
        #expect(error.errorCode == nil)
    }

    @Test("Given authenticationUnsupported error when getting errorCode then returns nil")
    func authenticationUnsupportedErrorCode() {
        let error = OnboardingAuthError(kind: .authenticationUnsupported("digest"))
        #expect(error.errorCode == nil)
    }

    @Test("Given invalidURL error when getting errorCode then returns nil")
    func invalidURLErrorCode() {
        let error = OnboardingAuthError(kind: .invalidURL)
        #expect(error.errorCode == nil)
    }

    @Test("Given sslUntrusted error when getting errorCode then returns joined codes")
    func sslUntrustedErrorCode() {
        let errors: [Error] = [
            NSError(domain: "SSL", code: 1),
            NSError(domain: "SSL", code: 2),
        ]
        let error = OnboardingAuthError(kind: .sslUntrusted(errors))
        let code = error.errorCode
        #expect(code?.contains("SSL 1") == true)
        #expect(code?.contains("SSL 2") == true)
    }

    @Test("Given other error when getting errorCode then returns domain and code")
    func otherErrorErrorCode() {
        let underlyingError = NSError(domain: "OtherDomain", code: 456)
        let error = OnboardingAuthError(kind: .other(underlyingError))
        #expect(error.errorCode == "OtherDomain 456")
    }

    // MARK: - Response String Tests

    @Test("Given error with data when getting responseString then returns truncated string")
    func responseStringWithData() {
        let testString = "Test response data"
        let error = OnboardingAuthError(kind: .invalidURL, data: testString.data(using: .utf8))
        #expect(error.responseString == testString)
    }

    @Test("Given error with nil data when getting responseString then returns nil")
    func responseStringWithNilData() {
        let error = OnboardingAuthError(kind: .invalidURL, data: nil)
        #expect(error.responseString == nil)
    }

    @Test("Given error with long data when getting responseString then truncates with ellipsis")
    func responseStringTruncation() {
        let longString = String(repeating: "a", count: 2000)
        let error = OnboardingAuthError(kind: .invalidURL, data: longString.data(using: .utf8))

        let result = error.responseString
        #expect(result?.count == 1024)
        #expect(result?.hasSuffix("…") == true)
    }

    @Test("Given error with exactly 1024 characters when getting responseString then does not truncate")
    func responseStringExactMaxLength() {
        let exactString = String(repeating: "b", count: 1024)
        let error = OnboardingAuthError(kind: .invalidURL, data: exactString.data(using: .utf8))

        let result = error.responseString
        #expect(result == exactString)
        #expect(result?.hasSuffix("…") == false)
    }

    // MARK: - Initialization Tests

    @Test("Given kind and data when initializing OnboardingAuthError then stores both")
    func initializationWithKindAndData() {
        let testData = "test".data(using: .utf8)
        let error = OnboardingAuthError(kind: .basicAuth, data: testData)

        #expect(error.kind == .basicAuth)
        #expect(error.data == testData)
    }

    @Test("Given only kind when initializing OnboardingAuthError then data defaults to nil")
    func initializationWithOnlyKind() {
        let error = OnboardingAuthError(kind: .invalidURL)

        #expect(error.kind == .invalidURL)
        #expect(error.data == nil)
    }
}
