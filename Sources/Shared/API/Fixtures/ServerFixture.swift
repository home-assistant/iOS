import Foundation

public enum ServerFixture {
    public static let standard = Server(identifier: "123", getter: {
        .init(
            name: "A Name",
            connection: .init(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: []),
                alwaysFallbackToInternalURL: false
            ),
            token: .init(
                accessToken: "",
                refreshToken: "",
                expiration: Date()
            ),
            version: "123"
        )
    }, setter: { _ in
        true
    })
}
