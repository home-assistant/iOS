import Alamofire
import Foundation
@testable import Shared
import Testing

@Suite("MJPEGStreamerSessionDelegate Tests")
struct MJPEGStreamerSessionDelegateTests {
    /// The camera long look on Apple Watch (and the iOS notification content extension) streams
    /// `camera_proxy_stream`, which an mTLS server refuses unless the session presents the client
    /// certificate. The delegate resolves the certificate at challenge time, so it has to be
    /// attached even when the server config carried none when the streamer was built — the watch
    /// restores its servers from sources that don't carry Keychain material, and a snapshot taken
    /// at that moment would leave the stream without a certificate for the process's lifetime.
    @Test("Given no client certificate when building the video streamer then it still handles mTLS")
    func videoStreamerAlwaysHandlesClientCertificateChallenges() {
        var info = ServerInfo(
            name: "mTLS Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: []),
                connectionAccessSecurityLevel: .undefined
            ),
            token: .init(accessToken: "access-token", refreshToken: "refresh-token", expiration: Date()),
            version: "2026.8.0"
        )
        #expect(info.connection.clientCertificate == nil)

        let server = Server(identifier: "mjpeg-mtls", getter: { info }, setter: { newInfo in
            info = newInfo
            return true
        })
        let streamer = HomeAssistantAPI(server: server).VideoStreamer()

        let delegate: SessionDelegate = streamer.manager.delegate
        #expect(delegate is ClientCertificateSessionDelegate)
    }
}
