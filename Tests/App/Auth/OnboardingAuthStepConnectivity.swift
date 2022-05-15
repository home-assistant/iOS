import Alamofire
@testable import HomeAssistant
import OHHTTPStubs
import PromiseKit
import XCTest

class OnboardingAuthStepConnectivityTests: XCTestCase {
    private var step: OnboardingAuthStepConnectivity!
    private var authDetails: OnboardingAuthDetails!
    private var sender: UIViewController!
    private var urlProtocol: ConnectivityURLProtocol.Type!

    override func setUpWithError() throws {
        try super.setUpWithError()

        urlProtocol = ConnectivityURLProtocol.self
        authDetails = try OnboardingAuthDetails(baseURL: URL(string: "http://example.com")!)
        sender = UIViewController()

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

    init(defaultHandling: @escaping () -> Void = {}) {
        self.defaultHandling = defaultHandling
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [self] in
            defaultHandling()
        }
    }
}
