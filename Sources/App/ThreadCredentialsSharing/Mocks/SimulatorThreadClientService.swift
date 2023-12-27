import Foundation

final class SimulatorThreadClientService: THClientProtocol {
    var retrieveAllCredentialsCalled = false

    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        retrieveAllCredentialsCalled = true
        return [
            .init(
                networkName: "test",
                networkKey: "test",
                extendedPANID: "test",
                borderAgentID: "test",
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
