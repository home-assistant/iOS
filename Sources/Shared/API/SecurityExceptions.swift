import Foundation
import Security

public enum SecurityExceptionError: Error {
    case invariantFailure
}

public struct SecurityExceptions: Codable, Equatable {
    private var exceptions: [SecurityException] = []
    public var identity: SecurityIdentity?

    public init(exceptions: [SecurityException] = [], identity: SecurityIdentity? = nil) {
        self.exceptions = exceptions
        self.identity = identity
    }

    public var hasExceptions: Bool { !exceptions.isEmpty }

    public mutating func add(for secTrust: SecTrust) {
        exceptions.append(.init(secTrust: secTrust))
    }

    public func evaluate(_ secTrust: SecTrust) throws {
        var baseError: CFError?
        let isAlreadyTrusted = SecTrustEvaluateWithError(secTrust, &baseError)

        guard !isAlreadyTrusted else {
            return
        }

        let baseThrowable = baseError as Error? ?? SecurityExceptionError.invariantFailure

        for exception in exceptions {
            do {
                try exception.evaluate(secTrust)
                // we want to preserve this one modifying the sec trust
                // so if it succeeds, we immediately return
                return
            } catch {
                // this one errored, so try the next one
            }
        }

        // always throw if we don't find a successful one above
        throw baseThrowable
    }

    public func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                guard let secTrust = challenge.protectionSpace.serverTrust else {
                    return (.performDefaultHandling, nil)
                }

                do {
                    try evaluate(secTrust)
                    return (.useCredential, .init(trust: secTrust))
                } catch {
                    return (.rejectProtectionSpace, nil)
                }
            case NSURLAuthenticationMethodClientCertificate:
                if let identity = identity {
                    return (.useCredential, identity.credential)
                } else {
                    return (.performDefaultHandling, nil)
                }
            default:
                return (.performDefaultHandling, nil)
            }
    }
}

public struct SecurityIdentity: Codable, Equatable {
    private let data: Data
    private let passphrase: String
    let identity: SecIdentity

    public init(data: Data, passphrase: String) throws {
        self.data = data
        self.passphrase = passphrase
        self.identity = try Self.identity(from: data, passphrase: passphrase)
    }

    public var credential: URLCredential {
        .init(identity: identity, certificates: nil, persistence: .forSession)
    }

    public enum CodingKeys: CodingKey {
        case data
        case passphrase
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let string = try container.decode(String.self, forKey: .data)
        self.data = Data(base64Encoded: string) ?? Data()
        self.passphrase = try container.decode(String.self, forKey: .passphrase)
        self.identity = try Self.identity(from: data, passphrase: passphrase)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data.base64EncodedString(), forKey: .data)
        try container.encode(passphrase, forKey: .passphrase)
    }

    public enum IdentityError: Error, CustomNSError {
        case incorrectPassphrase
        case invalidFormat
        case invalidResponse(String)
        case missingIdentity
        case decode(OSStatus)

        public var errorCode: Int {
            switch self {
            case .incorrectPassphrase: return 0
            case .invalidFormat: return 1
            case .invalidResponse: return 2
            case .missingIdentity: return 3
            case .decode: return 4
            }
        }
    }

    private static func identity(from data: Data, passphrase: String) throws -> SecIdentity {
        var items: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            [kSecImportExportPassphrase: passphrase] as CFDictionary,
            &items
        )

        switch status {
        case errSecSuccess:
            /*
             On return, an array of CFDictionary key-value dictionaries. The function returns one dictionary for
             each item (identity or certificate) in the PKCS #12 blob.

             - kSecImportItemIdentity
             - kSecImportItemCertChain
             - kSecImportItemTrust
             - kSecImportItemKeyID
             - kSecImportItemLabel
             */
            if let items = items as? [[CFString: Any]] {
                if let identity = items.compactMap({ $0[kSecImportItemIdentity] }).first {
                    // swiftlint:disable:next force_cast
                    return identity as! SecIdentity
                } else {
                    throw IdentityError.missingIdentity
                }
            } else {
                throw IdentityError.invalidResponse(String(describing: type(of: items)))
            }

        case errSecAuthFailed:
            throw IdentityError.incorrectPassphrase
        case errSecDecode:
            throw IdentityError.invalidFormat
        default:
            throw IdentityError.decode(status)
        }
    }
}

public struct SecurityException: Codable, Equatable {
    private var data: Data

    public init(secTrust: SecTrust) {
        self.data = SecTrustCopyExceptions(secTrust) as Data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.data = Data(base64Encoded: string) ?? Data()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }

    public func evaluate(_ secTrust: SecTrust) throws {
        SecTrustSetExceptions(secTrust, data as CFData)

        var error: CFError?

        if SecTrustEvaluateWithError(secTrust, &error) {
            return
        } else {
            throw error as Error? ?? SecurityExceptionError.invariantFailure
        }
    }
}
