import Alamofire
@testable import HomeAssistant
import OHHTTPStubs
import PromiseKit
import XCTest

class OnboardingAuthStepConnectivityTests: XCTestCase {
    private var step: OnboardingAuthStepConnectivity!
    private var authDetails: OnboardingAuthDetails!
    private var sender: FakeUIViewController!
    private var urlProtocol: ConnectivityURLProtocol.Type!

    override func setUpWithError() throws {
        try super.setUpWithError()

        urlProtocol = ConnectivityURLProtocol.self
        authDetails = try OnboardingAuthDetails(baseURL: URL(string: "http://example.com")!)
        sender = FakeUIViewController()

        step = OnboardingAuthStepConnectivity(authDetails: authDetails, sender: sender)
        step.prepareSessionConfiguration = { sessionConfiguration in
            sessionConfiguration.protocolClasses = [ConnectivityURLProtocol.self]
        }
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepConnectivity.supportedPoints.contains(.beforeAuth))
    }

    private static func protectionSpace(method: String) -> URLProtectionSpace {
        URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: method
        )
    }

    private static func finish(
        authDetails: OnboardingAuthDetails?,
        client: URLProtocolClient,
        proto: URLProtocol,
        statusCode: Int
    ) {
        do {
            client.urlProtocol(proto, didReceive: try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(authDetails).url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )), cacheStoragePolicy: .notAllowed)
            client.urlProtocol(proto, didLoad: Data())
            client.urlProtocolDidFinishLoading(proto)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testAuthenticationMethodIgnored() {
        ConnectivityURLProtocol.handler = { [authDetails] proto, client in
            client.urlProtocol(proto, didReceive: URLAuthenticationChallenge(
                protectionSpace: Self.protectionSpace(method: NSURLAuthenticationMethodServerTrust),
                proposedCredential: nil,
                previousFailureCount: 0,
                failureResponse: nil,
                error: nil,
                sender: FakeURLAuthenticationChallengeSender(
                    defaultHandling: {
                        Self.finish(authDetails: authDetails, client: client, proto: proto, statusCode: 200)
                    }
                )
            ))
        }

        XCTAssertNoThrow(try hang(step.perform(point: .beforeAuth)))
    }

    func testAuthenticationMethodFailures() {
        struct MethodKind {
            var method: String
            var errorKind: OnboardingAuthError.ErrorKind
        }

        for methodKind: MethodKind in [
            .init(method: NSURLAuthenticationMethodHTTPBasic, errorKind: .basicAuth),
            .init(
                method: NSURLAuthenticationMethodHTTPDigest,
                errorKind: .authenticationUnsupported(NSURLAuthenticationMethodHTTPDigest)
            ),
        ] {
            ConnectivityURLProtocol.handler = { proto, client in
                client.urlProtocol(proto, didReceive: URLAuthenticationChallenge(
                    protectionSpace: Self.protectionSpace(method: methodKind.method),
                    proposedCredential: nil,
                    previousFailureCount: 0,
                    failureResponse: nil,
                    error: nil,
                    sender: FakeURLAuthenticationChallengeSender(defaultHandling: {
                        // this is not expected to happen, so error with something obviously incorrect
                        client.urlProtocol(proto, didFailWithError: URLError(.badServerResponse))
                    })
                ))
            }

            XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
                XCTAssertEqual((error as? OnboardingAuthError)?.kind, methodKind.errorKind)
            }
        }
    }

    func testInvalidCertificateApproval() throws {
        // UnitTest.Example.com
        let certificate = try XCTUnwrap(Data(base64Encoded: """
            MIIFdDCCA1wCCQDtr2bmPQk6CTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVVDESMBAGA1UECAwJVW5pdCBUZXN0MRIwEAYD
            VQQHDAlVbml0IFRlc3QxEjAQBgNVBAoMCVVuaXQgVGVzdDESMBAGA1UECwwJVW5pdCBUZXN0MR0wGwYDVQQDDBRVbml0VGVzdC5F
            eGFtcGxlLmNvbTAeFw0yMjA1MTgwNTIwMjZaFw0yMzA1MTcwNTIwMjZaMHwxCzAJBgNVBAYTAlVUMRIwEAYDVQQIDAlVbml0IFRl
            c3QxEjAQBgNVBAcMCVVuaXQgVGVzdDESMBAGA1UECgwJVW5pdCBUZXN0MRIwEAYDVQQLDAlVbml0IFRlc3QxHTAbBgNVBAMMFFVu
            aXRUZXN0LkV4YW1wbGUuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEArkoUMNfQdHjRj7ObNri+/XW4yrVdFQ1t
            A7OsVfzc3JF3giPky4cdn8/cC9/dSek7xAdUFAQvmiYR2RsxSnfnYAxDiFvfgq8qP3z1Wk5rfjGQhrhWLWDop91UAPL+2k2YLJfD
            V4eFf3nG7n5Hp81i30d9fBLUgK22QOrMY0WA/k2MQzVDxF7lfYj2fuudQVzs266aIdCGTFst/SsFjDC6AGjdChdnwXLelL1WihxR
            QWcEUdqajZ+V5DF2rI+jdWGamcxsyXGCkP3gRCyyIW1MXVgYM21gTnf49TcOthjuUOg+Ky4Ku1NHdOqJTZBfKks2YcqM6yARdEOY
            TAeaEHETs/y4pdFhiM0mMd7XBvCEHCH3vctMQMC0YzZJfarvDIUAklXqNPisgAfzpiGAb3WjdwV/It7joHU1KFUUwWgD91i594OL
            7u+F54SjVtU2TflLqXboNGTAx+x94D/xBiJNa9FlzGRdAUgWhNefeHDIQ+azeAuvfIIYJdWxwoBBF9KQiIKKHNg14gDPMzwXcY22
            e5TwCiZA7KOdQcrVjBJ4ypQx9umsRw1TfftqZo/2gLPUqvq2CWGX2suXauoqHUIOrUcJy2RZhvEsxb+Av8D3TfPk50lpEXf3R+q1
            cGWlRYwzHJmaf0xXh8hjSY3bPiUQwn1EPrmRAk0KlIi7apDG93kCAwEAATANBgkqhkiG9w0BAQsFAAOCAgEAYLH7Oq19ZUhM0IrR
            FDfTlU1RZ/hVyUMSctj5ocYCHeKYi6ytiZR2RBA79ejjYKsdUB7SLCfekrZMPymjD2uxXi20mPL7jnjaamZlfYYt1YTvbFnLFKx/
            rgftcoumdtusipzJjyHXe7Z+TT78fQuYgt8NzZSj3wYb0dUJKcOhcp4krAQSrmLPCRlQzE9Bw1ZJnwwjhzCeXqy2G4X+lcVnZv9c
            lJyRxpb2gMRbqWRg2JdBQ4PfzK6d8P8sVpg+lnIB5syXd5R4CV1lDQLYpGEMu1zEEMy/QtmGbywx6VQYzLaldiLVPJzfxKr/p3or
            s1/3MoXtOXGsyrmWcNILk1bnX74cAZ/HCtT2Yne3R97AjV7upKdP4p3UUN2CHwIUWb3CJKj0kRoi4zGCDYqprPc/5FhSBFE9oJvf
            jUKvVYN/UFxvF28PBRxD8P9xHQYT5A5FaFmKJYsTmwgZ02NTOSzV/vuTl3/kg7UZe++j/RlypssJ6wT+wgFxUbSeqnJpg/4Mzw7Y
            cC45dV2lwwVYpZkJqruIgbQJuDh7Qja0apNiiRQmzjRQRid5O0CKi2Gr6M5Ug+SHsq6UgYkHkzJ5RYWIuVYHwRk2lGMWIwWL6o54
            3Mu+48MOWormNDeHqCbNekDf5MlKSphtvvsD2gPAAREflOJBNnB8x+rSnXUIN/+jFAA=
        """, options: [.ignoreUnknownCharacters]))

        func newSecTrust() throws -> SecTrust {
            var secTrust: SecTrust?
            SecTrustCreateWithCertificates([
                try XCTUnwrap(SecCertificateCreateWithData(nil, certificate as CFData)),
            ] as CFArray, nil, &secTrust)
            return try XCTUnwrap(secTrust)
        }

        struct TestCase: CaseIterable {
            enum AlertResponse {
                case trust
                case cancel
            }

            var alertResponse: AlertResponse
            var statusCode: Int
            var expectingError: Bool {
                switch alertResponse {
                case .trust: return statusCode != 200
                case .cancel: return true
                }
            }

            static var allCases: [TestCase] { [
                .init(alertResponse: .trust, statusCode: 200),
                .init(alertResponse: .trust, statusCode: 401),
                .init(alertResponse: .trust, statusCode: 503),
                .init(alertResponse: .cancel, statusCode: 200),
            ] }
        }

        for testCase in TestCase.allCases {
            authDetails.exceptions = .init()

            let secTrust = try newSecTrust()
            XCTAssertFalse(SecTrustEvaluateWithError(secTrust, nil), "we should start without it being trusted")

            sender.didPresent = { controller in
                guard let controller = controller as? UIAlertController else {
                    XCTFail("expected alert, got \(controller)")
                    return
                }

                switch testCase.alertResponse {
                case .trust:
                    if let alert = controller.actions.first(where: { $0.style == .destructive }) {
                        alert.ha_handler(alert)
                    } else {
                        XCTFail("expected an action")
                    }
                case .cancel:
                    if let alert = controller.actions.first(where: { $0.style == .cancel }) {
                        alert.ha_handler(alert)
                    } else {
                        XCTFail("expected an action")
                    }
                }
            }

            ConnectivityURLProtocol.handler = { [authDetails] proto, client in
                client.urlProtocol(proto, didReceive: URLAuthenticationChallenge(
                    protectionSpace: {
                        let space = URLProtectionSpace(
                            host: "UnitTest.Example.com",
                            port: 443,
                            protocol: nil,
                            realm: nil,
                            authenticationMethod: NSURLAuthenticationMethodServerTrust
                        )
                        // not in the mood to fight CFNetwork right now, there's no public method for this
                        space.perform(Selector(("_setServerTrust:")), with: secTrust)
                        return space
                    }(),
                    proposedCredential: nil,
                    previousFailureCount: 0,
                    failureResponse: nil,
                    error: nil,
                    sender: FakeURLAuthenticationChallengeSender(
                        defaultHandling: {
                            client.urlProtocol(proto, didFailWithError: URLError(.serverCertificateUntrusted))
                        },
                        cancelChallenge: {
                            client.urlProtocol(proto, didFailWithError: URLError(.serverCertificateUntrusted))
                        }, useCredential: { _ in
                            XCTAssertTrue(SecTrustEvaluateWithError(secTrust, nil))
                            Self.finish(
                                authDetails: authDetails,
                                client: client,
                                proto: proto,
                                statusCode: testCase.statusCode
                            )
                        }
                    )
                ))
            }

            if testCase.expectingError {
                XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
                    if testCase.alertResponse == .cancel {
                        switch (error as? OnboardingAuthError)?.kind {
                        case .sslUntrusted: break
                        default: XCTFail("expected ssl error, got \(error)")
                        }
                    } else {
                        switch (error as? OnboardingAuthError)?.kind {
                        case .other(PMKHTTPError.badStatusCode(testCase.statusCode, _, _)): break
                        default: XCTFail("expected status code error, got \(error)")
                        }
                    }
                }
            } else {
                XCTAssertNoThrow(try hang(step.perform(point: .beforeAuth)))
                XCTAssertTrue(SecTrustEvaluateWithError(secTrust, nil), "it should have been excepted")

                // construct a new SecTrust & apply the exceptions it made - it should pass
                let afterSecTrust = try newSecTrust()
                XCTAssertFalse(SecTrustEvaluateWithError(afterSecTrust, nil))
                try authDetails.exceptions.evaluate(afterSecTrust)
                XCTAssertTrue(SecTrustEvaluateWithError(afterSecTrust, nil))
            }
        }
    }

    func testClientCertificates() throws {
        var returnError = true

        ConnectivityURLProtocol.handler = { [authDetails] proto, client in
            client.urlProtocol(proto, didReceive: URLAuthenticationChallenge(
                protectionSpace: Self.protectionSpace(method: NSURLAuthenticationMethodClientCertificate),
                proposedCredential: nil,
                previousFailureCount: 0,
                failureResponse: nil,
                error: nil,
                sender: FakeURLAuthenticationChallengeSender(
                    defaultHandling: {
                        Self.finish(
                            authDetails: authDetails,
                            client: client,
                            proto: proto,
                            statusCode: returnError ? 401 : 200
                        )
                    }
                )
            ))
        }

        // tests if a client certificate is requested & we get an error response without
        returnError = true

        XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
            switch (error as? OnboardingAuthError)?.kind {
            case .clientCertificateRequired: break
            default: XCTFail("expected client certificate error, got \(error)")
            }
        }

        // tests if a client certificate is requested, but we succeed still without
        returnError = false

        XCTAssertNoThrow(try hang(step.perform(point: .beforeAuth)))
    }

    func testSslErrors() throws {
        for code: URLError.Code in [
            .serverCertificateUntrusted,
            .serverCertificateHasBadDate,
            .serverCertificateNotYetValid,
            .serverCertificateHasUnknownRoot,
        ] {
            ConnectivityURLProtocol.handler = { proto, client in
                client.urlProtocol(proto, didFailWithError: URLError(code))
            }

            XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
                XCTAssertEqual((error as? OnboardingAuthError)?.kind, .sslUntrusted([URLError(code)]))
            }
        }
    }

    func testUrlErrors() throws {
        for code: URLError.Code in [
            .timedOut,
            .httpTooManyRedirects,
            .notConnectedToInternet,
        ] {
            ConnectivityURLProtocol.handler = { proto, client in
                client.urlProtocol(proto, didFailWithError: URLError(code))
            }

            XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
                XCTAssertEqual((error as? OnboardingAuthError)?.kind, .other(URLError(code)))
            }
        }
    }

    func testBadStatusCode() throws {
        for statusCode: Int in [400, 401, 403, 404, 500, 503] {
            ConnectivityURLProtocol.handler = { [authDetails] proto, client in
                Self.finish(authDetails: authDetails, client: client, proto: proto, statusCode: statusCode)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: authDetails.url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            ))

            XCTAssertThrowsError(try hang(step.perform(point: .beforeAuth))) { error in
                XCTAssertEqual(
                    (error as? OnboardingAuthError)?.kind,
                    .other(PMKHTTPError.badStatusCode(statusCode, Data(), response))
                )
            }
        }
    }

    func testGoodStatusCode() throws {
        for statusCode: Int in [200] {
            ConnectivityURLProtocol.handler = { [authDetails] proto, client in
                Self.finish(authDetails: authDetails, client: client, proto: proto, statusCode: statusCode)
            }

            XCTAssertNoThrow(try hang(step.perform(point: .beforeAuth)))
        }
    }
}

class ConnectivityURLProtocol: URLProtocol {
    static var handler: (URLProtocol, URLProtocolClient) -> Void = { _, _ in }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override func startLoading() {
        if let client = client {
            Self.handler(self, client)
        }
    }

    override func stopLoading() {}
}

class FakeURLAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    var defaultHandling: () -> Void
    var cancelChallenge: () -> Void
    var useCredential: (URLCredential) -> Void

    init(
        defaultHandling: @escaping () -> Void = {},
        cancelChallenge: @escaping () -> Void = {},
        useCredential: @escaping (URLCredential) -> Void = { _ in }
    ) {
        self.defaultHandling = defaultHandling
        self.cancelChallenge = cancelChallenge
        self.useCredential = useCredential
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        useCredential(credential)
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}

    func cancel(_ challenge: URLAuthenticationChallenge) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [self] in
            cancelChallenge()
        }
    }

    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [self] in
            defaultHandling()
        }
    }
}

private class FakeUIViewController: UIViewController {
    var didPresent: ((UIViewController) -> Void)?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        didPresent?(viewControllerToPresent)
        completion?()
    }
}

class CustomURLProtectionSpace: URLProtectionSpace {
    var overrideServerTrust: SecTrust?
    override var serverTrust: SecTrust? {
        overrideServerTrust
    }
}
