import Foundation

final class CustomURLCredentialStorage: URLCredentialStorage {
    let exceptions: () -> SecurityExceptions

    init(server: Server) {
        self.exceptions = { server.info.connection.securityExceptions }
        super.init()
    }

    init(exceptions: SecurityExceptions) {
        self.exceptions = { exceptions }
        super.init()
    }

    override func defaultCredential(for space: URLProtectionSpace) -> URLCredential? {
        exceptions().identity?.credential
    }
}
