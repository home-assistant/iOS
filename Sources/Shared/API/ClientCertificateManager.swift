import Foundation
import Security

public enum ClientCertificateError: LocalizedError {
    case wrongPassword
    case noIdentity
    case importFailed(OSStatus)
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case readFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .wrongPassword:
            return "The password is incorrect."
        case .noIdentity:
            return "The file does not contain a valid identity."
        case .importFailed(let status):
            return "Failed to import certificate (error \(status))."
        case .saveFailed(let status):
            return "Failed to save certificate (error \(status))."
        case .deleteFailed(let status):
            return "Failed to delete certificate (error \(status))."
        case .readFailed(let status):
            return "Failed to read certificates (error \(status))."
        }
    }
}

public final class ClientCertificateManager {
    public static let shared = ClientCertificateManager()

    /// Keychain access group for sharing certificates across app extensions (Watch, Widgets)
    /// Uses the app's bundle ID to match entitlements configuration
    private var accessGroup: String {
        AppConstants.BundleID
    }

    private init() {}

    public func importP12(data: Data, password: String, name: String) throws {
        let options: NSDictionary = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let status = SecPKCS12Import(data as NSData, options, &items)

        guard status == errSecSuccess else {
            if status == errSecAuthFailed {
                throw ClientCertificateError.wrongPassword
            }
            throw ClientCertificateError.importFailed(status)
        }

        guard let itemsArray = items as? [[String: Any]],
              let identityDict = itemsArray.first,
              let identityRef = identityDict[kSecImportItemIdentity as String],
              CFGetTypeID(identityRef as CFTypeRef) == SecIdentityGetTypeID(),
              let identity = (identityRef as CFTypeRef) as? SecIdentity else {
            throw ClientCertificateError.noIdentity
        }

        try saveIdentity(identity, name: name)
    }

    public func validateP12(data: Data, password: String) -> Bool {
        let options: NSDictionary = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let status = SecPKCS12Import(data as NSData, options, &items)
        return status == errSecSuccess
    }

    private func saveIdentity(_ identity: SecIdentity, name: String) throws {
        let existingIdentity = readIdentity(name: name)
        if existingIdentity != nil {
            try deleteIdentity(name: name)
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: name,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ClientCertificateError.saveFailed(status)
        }
    }

    public func availableCertificates() -> [ClientCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnRef as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> ClientCertificate? in
            guard let name = item[kSecAttrLabel as String] as? String else {
                return nil
            }
            return ClientCertificate(name: name)
        }
    }

    public func readIdentity(name: String) -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: name,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? SecIdentity
    }

    public func credential(for certificate: ClientCertificate) -> URLCredential? {
        Current.Log.verbose("Looking up identity for certificate: \(certificate.name)")
        guard let identity = readIdentity(name: certificate.name) else {
            Current.Log.error("Identity not found in keychain for: \(certificate.name)")
            return nil
        }
        Current.Log.info("Successfully found identity for: \(certificate.name)")
        return URLCredential(identity: identity, certificates: nil, persistence: .forSession)
    }

    public func deleteIdentity(name: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: name,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ClientCertificateError.deleteFailed(status)
        }
    }
}
