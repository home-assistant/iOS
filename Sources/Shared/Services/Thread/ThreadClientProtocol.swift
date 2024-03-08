import Foundation

public protocol ThreadClientProtocol {
    func retrieveAllCredentials() async throws -> [ThreadCredential]
    func saveCredential(macExtendedAddress: String, operationalDataSet: String) async throws
    func saveCredential(macExtendedAddress: String, operationalDataSet: String, completion: @escaping (Error?) -> Void)
}

public enum ThreadClientServiceError: Error {
    case failedToConvertToHexadecimal
}
