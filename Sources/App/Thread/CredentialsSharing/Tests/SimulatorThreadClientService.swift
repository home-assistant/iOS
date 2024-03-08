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

    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        retrieveAllCredentialsCalled = true
        return [
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
    }
}
