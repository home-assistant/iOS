import Foundation
import Security

/// Represents a client certificate stored in the Keychain for mTLS authentication
public struct ClientCertificate: Codable, Equatable {
    /// Unique identifier for the certificate in Keychain
    public let keychainIdentifier: String
    /// Display name for the certificate (extracted from CN or user-provided)
    public let displayName: String
    /// Date when the certificate was imported
    public let importedAt: Date
    /// Certificate expiration date (if available)
    public let expiresAt: Date?

    public init(keychainIdentifier: String, displayName: String, importedAt: Date = Date(), expiresAt: Date? = nil) {
        self.keychainIdentifier = keychainIdentifier
        self.displayName = displayName
        self.importedAt = importedAt
        self.expiresAt = expiresAt
    }

    /// Check if the certificate is expired
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}

#if !os(watchOS)

// MARK: - Keychain Operations

public enum ClientCertificateError: LocalizedError {
    case invalidP12Data
    case invalidPassword
    case keychainError(OSStatus)
    case identityNotFound
    case certificateNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidP12Data:
            return "The certificate file is invalid or corrupted"
        case .invalidPassword:
            return "The password is incorrect"
        case let .keychainError(status):
            return "Keychain error: \(status)"
        case .identityNotFound:
            return "No identity found in the certificate"
        case .certificateNotFound:
            return "Certificate not found in Keychain"
        }
    }
}

public final class ClientCertificateManager {
    public static let shared = ClientCertificateManager()

    private init() {}

    static func pkcs12ImportOptions(password: String) -> [String: Any] {
        // On macOS, passwordless PKCS#12 imports fail when an explicit empty-string passphrase
        // is supplied. Omitting the option lets Security treat the bundle as unprotected.
        guard !password.isEmpty else {
            return [:]
        }

        return [
            kSecImportExportPassphrase as String: password,
        ]
    }

    /// Import a PKCS#12 file into the Keychain
    /// - Parameters:
    ///   - p12Data: The raw .p12 file data
    ///   - password: The password to decrypt the .p12 file
    ///   - identifier: A unique identifier for storing in Keychain
    /// - Returns: A ClientCertificate reference
    public func importP12(data p12Data: Data, password: String, identifier: String) throws -> ClientCertificate {
        let options = Self.pkcs12ImportOptions(password: password)

        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            if status == errSecAuthFailed {
                throw ClientCertificateError.invalidPassword
            }
            throw ClientCertificateError.keychainError(status)
        }

        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw ClientCertificateError.identityNotFound
        }

        // Extract certificate from identity to get info
        // swiftlint:disable:next force_cast
        let secIdentity = identity as! SecIdentity
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(secIdentity, &certificate)

        // Get certificate details
        var displayName = "Client Certificate"
        var expiresAt: Date?

        if let cert = certificate {
            if let summary = SecCertificateCopySubjectSummary(cert) as String? {
                displayName = summary
            }

            // Try to get expiration date
            if let certData = SecCertificateCopyData(cert) as Data? {
                expiresAt = extractExpirationDate(from: certData)
            }
        }

        // Extract intermediate certificates from the chain returned by SecPKCS12Import.
        // kSecImportItemCertChain contains all certs in the P12 ordered leaf-first; everything
        // after the leaf (index > 0) is an intermediate (or root) that must be sent during the
        // TLS handshake so the server can build the trust chain when an intermediate CA is used.
        let certChain = firstItem[kSecImportItemCertChain as String] as? [SecCertificate] ?? []
        let intermediateCerts = Array(certChain.dropFirst())

        // Store identity in Keychain
        let keychainIdentifier = "com.ha-ios.mtls.\(identifier)"
        try storeIdentity(secIdentity, identifier: keychainIdentifier)
        storeIntermediateCertificates(intermediateCerts, for: keychainIdentifier)

        return ClientCertificate(
            keychainIdentifier: keychainIdentifier,
            displayName: displayName,
            importedAt: Date(),
            expiresAt: expiresAt
        )
    }

    /// Store a SecIdentity in the Keychain
    private func storeIdentity(_ identity: SecIdentity, identifier: String) throws {
        // First, delete any existing identity with this identifier
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identifier,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new identity
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: identifier,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        // Handle duplicate - the identity might already exist with different label
        if status == errSecDuplicateItem {
            // Try to update instead
            let updateQuery: [String: Any] = [
                kSecValueRef as String: identity,
            ]
            let updateAttrs: [String: Any] = [
                kSecAttrLabel as String: identifier,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
            // If update also fails, the item exists which is fine for our purposes
            if updateStatus != errSecSuccess, updateStatus != errSecItemNotFound {
                Current.Log.warning("Keychain update returned \(updateStatus), but certificate may still work")
            }
            return
        }

        guard status == errSecSuccess else {
            throw ClientCertificateError.keychainError(status)
        }
    }

    /// Retrieve a SecIdentity from the Keychain
    public func retrieveIdentity(for certificate: ClientCertificate) throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certificate.keychainIdentifier,
            kSecReturnRef as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let identity = result else {
            throw ClientCertificateError.certificateNotFound
        }

        // swiftlint:disable:next force_cast
        return identity as! SecIdentity
    }

    /// Create a URLCredential from a stored certificate
    public func urlCredential(for certificate: ClientCertificate) throws -> URLCredential {
        let identity = try retrieveIdentity(for: certificate)

        var certChain: [SecCertificate] = []

        // Include the leaf certificate.
        var leafCertificate: SecCertificate?
        let leafStatus = SecIdentityCopyCertificate(identity, &leafCertificate)
        if leafStatus == errSecSuccess, let leafCertificate {
            certChain.append(leafCertificate)
        }

        // Include intermediate certificates so the server can verify the full chain when the
        // client certificate was signed by an intermediate CA rather than the root directly.
        let intermediates = retrieveIntermediateCertificates(for: certificate.keychainIdentifier)
        certChain.append(contentsOf: intermediates)

        if !certChain.isEmpty {
            return URLCredential(identity: identity, certificates: certChain, persistence: .forSession)
        }

        Current.Log
            .warning(
                "Failed to copy client certificate from identity (SecIdentityCopyCertificate status: \(leafStatus)); falling back to identity-only credential"
            )
        return URLCredential(identity: identity, certificates: nil, persistence: .forSession)
    }

    // MARK: - Intermediate Certificate Chain

    // Service key used to store the ordered intermediate chain as a single generic-password blob.
    // Storing as kSecClassGenericPassword (rather than individual kSecClassCertificate items) avoids
    // two pitfalls: (1) errSecDuplicateItem when the same intermediate is already in the keychain
    // under a different label, and (2) non-deterministic ordering from kSecMatchLimitAll queries.
    private static let chainServiceKey = "com.ha-ios.mtls.chain"

    /// Persist intermediate (and/or root) certificates from the P12 chain as an ordered DER blob.
    ///
    /// Certs are serialized in their original order so the chain can be reconstructed identically
    /// on retrieval, regardless of keychain internals.
    private func storeIntermediateCertificates(_ certs: [SecCertificate], for identifier: String) {
        // Always delete the existing entry first so re-imports start clean.
        deleteIntermediateCertificates(for: identifier)

        guard !certs.isEmpty else { return }

        let derArray = certs.compactMap { SecCertificateCopyData($0) as Data? }
        guard let serialized = try? PropertyListSerialization.data(
            fromPropertyList: derArray,
            format: .binary,
            options: 0
        ) else {
            Current.Log.warning("Failed to serialize intermediate certificate chain")
            return
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.chainServiceKey,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: serialized,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Current.Log.warning("Failed to store intermediate certificate chain in keychain: \(status)")
        }
    }

    /// Retrieve the ordered intermediate certificates previously stored for this identity.
    private func retrieveIntermediateCertificates(for identifier: String) -> [SecCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.chainServiceKey,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let derArray = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [Data] else {
            return []
        }
        return derArray.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
    }

    private func deleteIntermediateCertificates(for identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.chainServiceKey,
            kSecAttrAccount as String: identifier,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Delete a certificate from the Keychain
    public func delete(certificate: ClientCertificate) throws {
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certificate.keychainIdentifier,
        ]

        let status = SecItemDelete(identityQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ClientCertificateError.keychainError(status)
        }

        // Also delete any stored intermediate certificates for this identity.
        deleteIntermediateCertificates(for: certificate.keychainIdentifier)
    }

    /// Extract expiration date from certificate data (simplified)
    private func extractExpirationDate(from data: Data) -> Date? {
        // This is a simplified implementation
        // In production, you might want to use a proper ASN.1 parser
        // For now, we'll return nil and handle expiration checking differently
        nil
    }
}

// MARK: - URLSessionDelegate Extension

public extension ClientCertificateManager {
    /// Handle client certificate authentication challenge
    func handleClientCertificateChallenge(
        _ challenge: URLAuthenticationChallenge,
        certificate: ClientCertificate?
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate,
              let certificate else {
            return (.performDefaultHandling, nil)
        }

        do {
            let credential = try urlCredential(for: certificate)
            return (.useCredential, credential)
        } catch {
            Current.Log.error("Failed to get credential for client certificate: \(error)")
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}
#endif
