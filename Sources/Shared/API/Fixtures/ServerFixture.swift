import Foundation

public enum ServerFixture {
    private static var standardInfo = ServerInfo(
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
            localAccessSecurityLevel: .undefined
        ),
        token: .init(
            accessToken: "",
            refreshToken: "",
            expiration: Date()
        ),
        version: "123"
    )
    
    private static let originalStandardInfo = standardInfo
    
    public static var standard: Server {
        Server(identifier: "123", getter: {
            standardInfo
        }, setter: { newInfo in
            standardInfo = newInfo
            return true
        })
    }
    
    /// Reset all fixtures to their original state - call this between tests
    public static func reset() {
        standardInfo = originalStandardInfo
        remoteConnectionInfo = originalRemoteConnectionInfo
        lessSecureAccessInfo = originalLessSecureAccessInfo
    }

    private static var remoteConnectionInfo = ServerInfo(
        name: "Remote Server",
        connection: .init(
            externalURL: URL(string: "https://external.example.com"),
            internalURL: URL(string: "http://internal.example.com"),
            cloudhookURL: URL(string: "https://hooks.nabu.casa/webhook-id"),
            remoteUIURL: URL(string: "https://ui.nabu.casa"),
            webhookID: "webhook-id",
            webhookSecret: "webhook-secret",
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(exceptions: []),
            localAccessSecurityLevel: .undefined
        ),
        token: .init(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiration: Date()
        ),
        version: "2023.12.0"
    )
    
    private static let originalRemoteConnectionInfo = remoteConnectionInfo

    /// Server with remote connection setup for testing remote-compatible flows
    public static var withRemoteConnection: Server {
        Server(identifier: "remote", getter: {
            remoteConnectionInfo
        }, setter: { newInfo in
            remoteConnectionInfo = newInfo
            return true
        })
    }

    private static var lessSecureAccessInfo = ServerInfo(
        name: "Less Secure Server",
        connection: .init(
            externalURL: nil,
            internalURL: URL(string: "http://internal.example.com"),
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook-id",
            webhookSecret: "webhook-secret",
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(exceptions: []),
            localAccessSecurityLevel: .lessSecure
        ),
        token: .init(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiration: Date()
        ),
        version: "2023.12.0"
    )
    
    private static let originalLessSecureAccessInfo = lessSecureAccessInfo

    /// Server with less secure local access configured
    public static var withLessSecureAccess: Server {
        Server(identifier: "less-secure", getter: {
            lessSecureAccessInfo
        }, setter: { newInfo in
            lessSecureAccessInfo = newInfo
            return true
        })
    }
}
