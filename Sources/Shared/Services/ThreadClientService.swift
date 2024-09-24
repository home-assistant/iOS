import Foundation

#if canImport(ThreadNetwork)
import ThreadNetwork

@available(iOS 15, *)
public final class ThreadClientService: ThreadClientProtocol {
    public init() {}

    private var client: THClient?

    public func retrieveAllCredentials() async throws -> [ThreadCredential] {
        client = THClient()
        guard let client else { return [] }
        let placeholder = "Unknown"

        // Thre preferred credential call is necessary as it triggers a permission dialog
        let preferredCredential = try await client.preferredCredentials()

        // All credentials retrieve the rest of the credentials after user acceps permission dialog
        // This call may fail, but we don't want to throw error since preferredCredential succeeded
        var allCredentials: Set<THCredentials> = await (try? client.allCredentials()) ?? []
        allCredentials = allCredentials.filter { $0.borderAgentID != preferredCredential.borderAgentID }
        allCredentials.insert(preferredCredential)

        self.client = nil
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
        client = THClient()
        try await client?.storeCredentials(
            forBorderAgent: borderAgent,
            activeOperationalDataSet: activeOperationalDataSet
        )
        client = nil
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
        client = THClient()
        client?.storeCredentials(
            forBorderAgent: borderAgent,
            activeOperationalDataSet: activeOperationalDataSet,
            completion: { [weak self] error in
                completion(error)
                self?.client = nil
            }
        )
    }

    public func deleteCredential(macExtendedAddress: String, completion: @escaping (Error?) -> Void) {
        guard let data = macExtendedAddress.hexadecimal else {
            Current.Log.error("Thread operation, failed to convert to macExtendedAddress to hexadecimal")
            completion(nil)
            return
        }

        client = THClient()
        client?.deleteCredentials(forBorderAgent: data, completion: { [weak self] error in
            completion(error)
            self?.client = nil
        })
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

    public func deleteCredential(macExtendedAddress: String, completion: @escaping (Error?) -> Void) {
        /* no-op */
    }
}
#endif
