import Foundation

public protocol ThreadClientProtocol {
    func retrieveAllCredentials() async throws -> [ThreadCredential]
    func saveCredential(macExtendedAddress: String, operationalDataSet: String) async throws
    func saveCredential(macExtendedAddress: String, operationalDataSet: String, completion: @escaping (Error?) -> Void)
    func deleteCredential(macExtendedAddress: String, completion: @escaping (Error?) -> Void)
    func enableCredentialSharingMode(extendedPANID: String) async throws
}

public enum ThreadClientServiceError: LocalizedError {
    case failedToConvertToHexadecimal
    case credentialSharingModeUnavailable

    public var errorDescription: String? {
        switch self {
        case .failedToConvertToHexadecimal:
            return L10n.Thread.ClientError.hexadecimalConversion
        case .credentialSharingModeUnavailable:
            return L10n.Thread.ClientError.credentialSharingModeUnavailable
        }
    }
}
