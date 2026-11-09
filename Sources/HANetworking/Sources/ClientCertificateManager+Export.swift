import Foundation
import Security

public extension ClientCertificateManager {
    /// Takes the identity stored under `identifier` apart for transfer, for certificates imported
    /// before the original bundle was retained.
    func exportIdentity(for identifier: String) throws -> ClientIdentityExport {
        let identity = try retrieveIdentity(for: ClientCertificate(keychainIdentifier: identifier, displayName: ""))
        var privateKey: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess, let privateKey else {
            throw ClientCertificateError.identityNotFound
        }
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            throw ClientCertificateError.certificateNotFound
        }
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            throw ClientCertificateError.keychainError(errSecDecode)
        }
        let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any] ?? [:]
        return ClientIdentityExport(
            keychainIdentifier: identifier,
            privateKey: keyData,
            keyType: attributes[kSecAttrKeyType as String] as? String ?? kSecAttrKeyTypeRSA as String,
            keySizeInBits: attributes[kSecAttrKeySizeInBits as String] as? Int ?? 0,
            leafCertificate: SecCertificateCopyData(certificate) as Data,
            intermediateCertificates: retrieveIntermediateCertificates(for: identifier)
                .map { SecCertificateCopyData($0) as Data }
        )
    }

    /// Puts an exported identity back together in this app's keychain under its original label, so
    /// the `ClientCertificate` reference that travelled with the server resolves again.
    func importIdentity(_ export: ClientIdentityExport) throws {
        var keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: export.keyType,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        ]
        if export.keySizeInBits > 0 {
            keyAttributes[kSecAttrKeySizeInBits as String] = export.keySizeInBits
        }
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(export.privateKey as CFData, keyAttributes as CFDictionary, &error) else {
            throw ClientCertificateError.keychainError(errSecDecode)
        }
        guard let certificate = SecCertificateCreateWithData(nil, export.leafCertificate as CFData) else {
            throw ClientCertificateError.invalidP12Data
        }

        SecItemDelete([
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: export.keychainIdentifier,
        ] as CFDictionary)

        let keyStatus = SecItemAdd([
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: privateKey,
            kSecAttrLabel as String: export.keychainIdentifier,
            kSecAttrIsPermanent as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary, nil)
        guard keyStatus == errSecSuccess || keyStatus == errSecDuplicateItem else {
            throw ClientCertificateError.keychainError(keyStatus)
        }
        let certificateStatus = SecItemAdd([
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: export.keychainIdentifier,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary, nil)
        guard certificateStatus == errSecSuccess || certificateStatus == errSecDuplicateItem else {
            throw ClientCertificateError.keychainError(certificateStatus)
        }

        let reference = ClientCertificate(keychainIdentifier: export.keychainIdentifier, displayName: "")
        guard hasIdentity(for: reference) else {
            throw ClientCertificateError.identityNotFound
        }
        storeIntermediateCertificates(
            export.intermediateCertificates.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) },
            for: export.keychainIdentifier
        )
    }
}
