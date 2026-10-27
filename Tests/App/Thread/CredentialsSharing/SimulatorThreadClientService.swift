import Foundation
import Shared

final class SimulatorThreadClientService: ThreadClientProtocol {
    func saveCredential(
        macExtendedAddress: String,
        operationalDataSet: String,
        completion: @escaping (Error?) -> Void
    ) {}

    func saveCredential(macExtendedAddress: String, operationalDataSet: String) {}

    var retrieveAllCredentialsCalled = false
    var credentials: [ThreadCredential] = [
        .init(
            networkName: "test",
            networkKey: "test",
            extendedPANID: "test",
            borderAgentID: "test",
            macExtendedAddress: "test2",
            activeOperationalDataSet: "test",
            pskc: "test",
            channel: 25,
            panID: "test",
            creationDate: nil,
            lastModificationDate: Date()
        ),
        .init(
            networkName: "test",
            networkKey: "test",
            extendedPANID: "test",
            borderAgentID: "test2",
            macExtendedAddress: "test2",
            activeOperationalDataSet: "test",
            pskc: "test",
            channel: 25,
            panID: "test",
            creationDate: nil,
            lastModificationDate: Date()
        ),
    ]

    var retrieveAllCredentialsError: Error?
    var suspendRetrieveAllCredentials = false

    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        retrieveAllCredentialsCalled = true
        if suspendRetrieveAllCredentials {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
        if let retrieveAllCredentialsError {
            throw retrieveAllCredentialsError
        }
        return credentials
    }

    public func deleteCredential(macExtendedAddress: String, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    var enableCredentialSharingModeExtendedPANID: String?
    var enableCredentialSharingModeError: Error?
    var enableCredentialSharingModeCallCount = 0
    var suspendEnableCredentialSharingMode = false
    private var suspendedEnableCredentialSharingModeRequests: [CheckedContinuation<Void, Never>] = []

    func enableCredentialSharingMode(extendedPANID: String) async throws {
        enableCredentialSharingModeExtendedPANID = extendedPANID
        enableCredentialSharingModeCallCount += 1
        if suspendEnableCredentialSharingMode {
            await withCheckedContinuation { continuation in
                suspendedEnableCredentialSharingModeRequests.append(continuation)
            }
        }
        if let enableCredentialSharingModeError {
            throw enableCredentialSharingModeError
        }
    }

    var hasSuspendedEnableCredentialSharingModeRequests: Bool {
        !suspendedEnableCredentialSharingModeRequests.isEmpty
    }

    func resumeSuspendedEnableCredentialSharingModeRequests() {
        let requests = suspendedEnableCredentialSharingModeRequests
        suspendedEnableCredentialSharingModeRequests.removeAll()
        requests.forEach { $0.resume() }
    }
}
