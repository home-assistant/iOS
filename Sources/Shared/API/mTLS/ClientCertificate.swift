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

    /// Import a PKCS#12 file into the Keychain
    /// - Parameters:
    ///   - p12Data: The raw .p12 file data
    ///   - password: The password to decrypt the .p12 file
    ///   - identifier: A unique identifier for storing in Keychain
    /// - Returns: A ClientCertificate reference
    public func importP12(data p12Data: Data, password: String, identifier: String) throws -> ClientCertificate {
        // Import options
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password,
        ]

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
        if SecIdentityCopyCertificate(identity, &leafCertificate) == errSecSuccess, let leafCertificate {
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
            .warning("Failed to copy client certificate from identity; falling back to identity-only credential")
        return URLCredential(identity: identity, certificates: nil, persistence: .forSession)
    }

    // MARK: - Intermediate Certificate Chain

    private func intermediateChainLabel(for identifier: String) -> String {
        "\(identifier).chain"
    }

    /// Persist intermediate (and/or root) certificates from the P12 chain alongside the identity.
    private func storeIntermediateCertificates(_ certs: [SecCertificate], for identifier: String) {
        let label = intermediateChainLabel(for: identifier)
        // Clear any previously stored chain for this identifier before writing the new one.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        for cert in certs {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecValueRef as String: cert,
                kSecAttrLabel as String: label,
            ]
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess, status != errSecDuplicateItem {
                Current.Log.warning("Failed to store intermediate certificate in keychain: \(status)")
            }
        }
    }

    /// Retrieve previously stored intermediate certificates for the given keychain identifier.
    private func retrieveIntermediateCertificates(for identifier: String) -> [SecCertificate] {
        let label = intermediateChainLabel(for: identifier)
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let certs = result as? [SecCertificate] else {
            return []
        }
        return certs
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
        let chainQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: intermediateChainLabel(for: certificate.keychainIdentifier),
        ]
        SecItemDelete(chainQuery as CFDictionary)
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
