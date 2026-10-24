import Foundation

/// A client identity taken apart so it can cross into another app's keychain: the private key as
/// its external representation, the leaf certificate and any intermediates as DER. Only ever moves
/// inside an encrypted payload.
public struct ClientIdentityExport: Codable, Equatable {
    public let keychainIdentifier: String
    public let privateKey: Data
    public let keyType: String
    public let keySizeInBits: Int
    public let leafCertificate: Data
    public let intermediateCertificates: [Data]

    public init(
        keychainIdentifier: String,
        privateKey: Data,
        keyType: String,
        keySizeInBits: Int,
        leafCertificate: Data,
        intermediateCertificates: [Data]
    ) {
        self.keychainIdentifier = keychainIdentifier
        self.privateKey = privateKey
        self.keyType = keyType
        self.keySizeInBits = keySizeInBits
        self.leafCertificate = leafCertificate
        self.intermediateCertificates = intermediateCertificates
    }
}
