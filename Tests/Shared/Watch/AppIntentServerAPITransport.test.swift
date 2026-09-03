import Foundation
@testable import Shared
import Testing

/// Which transport `AppIntentServerAPI` picks for a server. The iOS test host never runs the
/// watchOS branch, so these cover the WebSocket-first decision and its mTLS exception.
struct AppIntentServerAPITransportTests {
    private static let certificate = ClientCertificate(
        keychainIdentifier: "com.ha-ios.mtls.identity.transport-test",
        displayName: "Transport Test"
    )

    @Test func serverWithoutClientCertificateUsesWebSocket() {
        let server = makeServer(externalURL: "https://external.example.com", clientCertificate: nil)

        let transport = AppIntentServerAPI.transport(for: server, hasIntermediateCertificates: { _ in true })

        #expect(transport == .webSocket)
    }

    @Test func clientCertificateWithoutIntermediatesUsesWebSocket() {
        // A leaf the server trusts directly is presented fine by the WebSocket engine.
        let server = makeServer(externalURL: "https://external.example.com", clientCertificate: Self.certificate)

        let transport = AppIntentServerAPI.transport(for: server, hasIntermediateCertificates: { _ in false })

        #expect(transport == .webSocket)
    }

    @Test func clientCertificateChainOverHTTPSUsesREST() {
        let server = makeServer(externalURL: "https://external.example.com", clientCertificate: Self.certificate)
        var queried: [ClientCertificate] = []

        let transport = AppIntentServerAPI.transport(for: server, hasIntermediateCertificates: { certificate in
            queried.append(certificate)
            return true
        })

        #expect(transport == .rest)
        #expect(queried == [Self.certificate])
    }

    @Test func clientCertificateChainOverHTTPUsesWebSocket() {
        // Plain HTTP never presents a client certificate, so the chain can't be what breaks it.
        let server = makeServer(externalURL: "http://192.168.1.10:8123", clientCertificate: Self.certificate)

        let transport = AppIntentServerAPI.transport(for: server, hasIntermediateCertificates: { _ in true })

        #expect(transport == .webSocket)
    }

    private func makeServer(externalURL: String, clientCertificate: ClientCertificate?) -> Server {
        var info = ServerInfo(
            name: "Transport Server",
            connection: .init(
                externalURL: URL(string: externalURL),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: []),
                connectionAccessSecurityLevel: .undefined,
                clientCertificate: clientCertificate
            ),
            token: .init(accessToken: "access-token", refreshToken: "refresh-token", expiration: Date()),
            version: "2026.9.0"
        )
        return Server(identifier: "transport-test", getter: { info }, setter: { newInfo in
            info = newInfo
            return true
        })
    }
}
