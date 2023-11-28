import Foundation

@available(iOS 13, *)
protocol THClientProtocol {
    func retrieveAllCredentials() async throws -> [ThreadCredential]
}

struct ThreadCredential {
    let networkName: String
    let networkKey: String
    let extendedPANID: String
    let borderAgentID: String
    let activeOperationalDataSet: String
    let pskc: String
    let channel: UInt8
    let panID: String
    let creationDate: Date?
    let lastModificationDate: Date?
}

#if canImport(ThreadNetwork)
import ThreadNetwork

@available(iOS 15, *)
final class ThreadClientService: THClientProtocol {
    private let client = THClient()

    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        let placeholder = "Unknown"
        return try await client.allCredentials().map { credential in
            ThreadCredential(
                networkName: credential.networkName ?? placeholder,
                networkKey: credential.networkKey?.hexadecimal ?? placeholder,
                extendedPANID: credential.extendedPANID?.hexadecimal ?? placeholder,
                borderAgentID: credential.borderAgentID?.hexadecimal ?? placeholder,
                activeOperationalDataSet: credential.activeOperationalDataSet?.hexadecimal ?? placeholder,
                pskc: credential.pskc?.hexadecimal ?? placeholder,
                channel: credential.channel,
                panID: credential.panID?.hexadecimal ?? placeholder,
                creationDate: credential.creationDate,
                lastModificationDate: credential.lastModificationDate
            )
        }
    }
}

extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }
}
#else
/// For SwiftUI Preview
@available(iOS 15, *)
final class ThreadClientService: THClientProtocol {
    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        []
    }
}
#endif
