import Alamofire
import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Every native request must present the storage filled by `WebViewCookieMirror`, or a server behind
/// cookie-based authentication is unreachable.
@MainActor
struct CookieStorageWiringTests {
    @Test("The certificate-aware session sends the mirrored cookies")
    func certificateAwareSession() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            _ = try await HomeAssistantAPI.makeCertificateAwareURLSession(server: .fake()).data(from: url)
        }
    }

    @Test("The unauthenticated request manager sends the mirrored cookies")
    func unauthenticatedManager() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            _ = await HomeAssistantAPI.unauthenticatedManager.request(url).serializingData().response
        }
    }

    @Test("Token refresh sends the mirrored cookies")
    func tokenRefresh() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            let server = Server.fake(update: { $0.connection.set(address: url, for: .external) })
            // Its `Session` cancels every request in flight when it deallocates.
            let api = AuthenticationAPI(server: server)
            _ = try await api.refreshTokenWith(tokenInfo: server.info.token).asyncValue()
            withExtendedLifetime(api) {}
        }
    }

    @Test("The token exchange after login sends the mirrored cookies")
    func tokenExchange() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            _ = try await AuthenticationAPI.fetchToken(authorizationCode: "code", baseURL: url, exceptions: .init())
                .asyncValue()
        }
    }

    @Test("Webhook requests send the mirrored cookies")
    func webhookSession() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            let info = WebhookSessionInfo(
                identifier: "webhook-cookie-test",
                delegate: NoopSessionDelegate(),
                delegateQueue: .main,
                background: false
            )
            _ = try await info.session.data(from: url)
        }
    }

    @Test("The webhook reachability check sends the mirrored cookies")
    func webhookReachabilityCheck() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            let viewModel = WebhookDetailViewModel(server: .fake())
            await viewModel.checkReachability(for: WebhookEndpoint(source: .externalURL, url: url))
        }
    }

    @Test("The connection diagnostics send the mirrored cookies")
    func connectivityCheck() async throws {
        try await CookieRecordingServer.expectMirroredCookie { url in
            await ConnectivityChecker(state: ConnectivityCheckState()).runChecks(for: url)
        }
    }
}

private final class NoopSessionDelegate: NSObject, URLSessionDelegate {}
