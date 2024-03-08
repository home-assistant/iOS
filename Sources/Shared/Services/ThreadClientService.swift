import Foundation

#if canImport(ThreadNetwork)
import ThreadNetwork

@available(iOS 15, *)
public final class ThreadClientService: ThreadClientProtocol {
    public init() {}

    public func retrieveAllCredentials() async throws -> [ThreadCredential] {
        let client = THClient()
        let placeholder = "Unknown"

        // Thre preferred credential call is necessary as it triggers a permission dialog
        let preferredCredential = try await client.preferredCredentials()

        // All credentials retrieve the rest of the credentials after user acceps permission dialog
        // This call may fail, but we don't want to throw error since preferredCredential succeeded
        var allCredentials: Set<THCredentials> = await (try? client.allCredentials()) ?? []
        allCredentials = allCredentials.filter { $0.borderAgentID != preferredCredential.borderAgentID }
        allCredentials.insert(preferredCredential)

        return allCredentials.map { credential in
            ThreadCredential(
                networkName: credential.networkName ?? placeholder,
                networkKey: credential.networkKey?.hexadecimal ?? placeholder,
                extendedPANID: credential.extendedPANID?.hexadecimal ?? placeholder,
                borderAgentID: credential.borderAgentID?.hexadecimal ?? placeholder,
                // Apple uses mac extended address as border agent ID
                macExtendedAddress: credential.borderAgentID?.hexadecimal ?? placeholder,
                activeOperationalDataSet: credential.activeOperationalDataSet?.hexadecimal ?? placeholder,
                pskc: credential.pskc?.hexadecimal ?? placeholder,
                channel: credential.channel,
                panID: credential.panID?.hexadecimal ?? placeholder,
                creationDate: credential.creationDate,
                lastModificationDate: credential.lastModificationDate
            )
        }
    }

    public func saveCredential(macExtendedAddress: String, operationalDataSet: String) async throws {
        guard let borderAgent = macExtendedAddress.hexadecimal,
              let activeOperationalDataSet = operationalDataSet.hexadecimal else {
            throw ThreadClientServiceError.failedToConvertToHexadecimal
        }

        try await THClient().storeCredentials(
            forBorderAgent: borderAgent,
            activeOperationalDataSet: activeOperationalDataSet
        )
    }

    public func saveCredential(
        macExtendedAddress: String,
        operationalDataSet: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard let borderAgent = macExtendedAddress.hexadecimal,
              let activeOperationalDataSet = operationalDataSet.hexadecimal else {
            completion(ThreadClientServiceError.failedToConvertToHexadecimal)
            return
        }
        THClient().storeCredentials(
            forBorderAgent: borderAgent,
            activeOperationalDataSet: activeOperationalDataSet,
            completion: completion
        )
    }
}
#else
/// For SwiftUI Preview
@available(iOS 15, *)
public final class ThreadClientService: ThreadClientProtocol {
    public init() {}
    public func retrieveAllCredentials() async throws -> [ThreadCredential] {
        []
    }

    public func saveCredential(macExtendedAddress: String, operationalDataSet: String) {}

    public func saveCredential(
        macExtendedAddress: String,
        operationalDataSet: String,
        completion: @escaping (Error?) -> Void
    ) {}
}
#endif
