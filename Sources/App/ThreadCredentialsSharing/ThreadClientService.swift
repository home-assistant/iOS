import Foundation
import Shared

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

        // Thre preferred credential call is necessary as it triggers a permission dialog
        let preferredCredential = try await client.preferredCredentials()

        // All credentials retrieve the rest of the credentials after user acceps permission dialog
        // This call may fail, but we don't want to throw error since preferredCredential succeeded
        var allCredentials: Set<THCredentials> = (try? await client.allCredentials()) ?? []
        allCredentials = allCredentials.filter { $0.borderAgentID != preferredCredential.borderAgentID }
        allCredentials.insert(preferredCredential)

        return allCredentials.map { credential in
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
#else
/// For SwiftUI Preview
@available(iOS 15, *)
final class ThreadClientService: THClientProtocol {
    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        []
    }
}
#endif
