import Foundation
@testable import Shared
import Testing

@Suite("ClientCertificate Tests")
struct ClientCertificateTests {
    // MARK: - Initialization Tests

    @Test("Given valid parameters when initializing ClientCertificate then properties are set correctly")
    func initializationSetsProperties() {
        let identifier = "com.ha-ios.mtls.test"
        let displayName = "Test Certificate"
        let importedAt = Date()
        let expiresAt = Date().addingTimeInterval(86400 * 365) // 1 year from now

        let cert = ClientCertificate(
            keychainIdentifier: identifier,
            displayName: displayName,
            importedAt: importedAt,
            expiresAt: expiresAt
        )

        #expect(cert.keychainIdentifier == identifier)
        #expect(cert.displayName == displayName)
        #expect(cert.importedAt == importedAt)
        #expect(cert.expiresAt == expiresAt)
    }

    @Test("Given no expiration date when initializing ClientCertificate then expiresAt is nil")
    func initializationWithoutExpiration() {
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert"
        )

        #expect(cert.expiresAt == nil)
    }

    @Test("Given default parameters when initializing ClientCertificate then importedAt defaults to current date")
    func initializationDefaultsImportedAt() {
        let beforeInit = Date()
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert"
        )
        let afterInit = Date()

        #expect(cert.importedAt >= beforeInit)
        #expect(cert.importedAt <= afterInit)
    }

    // MARK: - Expiration Tests

    @Test("Given certificate with future expiration when checking isExpired then returns false")
    func notExpiredCertificate() {
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            expiresAt: Date().addingTimeInterval(86400) // 1 day from now
        )

        #expect(cert.isExpired == false)
    }

    @Test("Given certificate with past expiration when checking isExpired then returns true")
    func expiredCertificate() {
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            expiresAt: Date().addingTimeInterval(-86400) // 1 day ago
        )

        #expect(cert.isExpired == true)
    }

    @Test("Given certificate with no expiration when checking isExpired then returns false")
    func noExpirationCertificate() {
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            expiresAt: nil
        )

        #expect(cert.isExpired == false)
    }

    @Test("Given certificate that just expired when checking isExpired then returns true")
    func justExpiredCertificate() {
        let cert = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            expiresAt: Date().addingTimeInterval(-1) // 1 second ago
        )

        #expect(cert.isExpired == true)
    }

    // MARK: - Equatable Tests

    @Test("Given two certificates with same properties when comparing then returns true")
    func equalCertificates() {
        let date = Date()
        let expiresAt = Date().addingTimeInterval(86400)

        let cert1 = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            importedAt: date,
            expiresAt: expiresAt
        )
        let cert2 = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Test Cert",
            importedAt: date,
            expiresAt: expiresAt
        )

        #expect(cert1 == cert2)
    }

    @Test("Given two certificates with different identifiers when comparing then returns false")
    func differentIdentifiers() {
        let date = Date()

        let cert1 = ClientCertificate(
            keychainIdentifier: "test-id-1",
            displayName: "Test Cert",
            importedAt: date
        )
        let cert2 = ClientCertificate(
            keychainIdentifier: "test-id-2",
            displayName: "Test Cert",
            importedAt: date
        )

        #expect(cert1 != cert2)
    }

    @Test("Given two certificates with different display names when comparing then returns false")
    func differentDisplayNames() {
        let date = Date()

        let cert1 = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Cert A",
            importedAt: date
        )
        let cert2 = ClientCertificate(
            keychainIdentifier: "test-id",
            displayName: "Cert B",
            importedAt: date
        )

        #expect(cert1 != cert2)
    }

    // MARK: - Codable Tests

    @Test("Given ClientCertificate when encoding and decoding then preserves all properties")
    func codableRoundTrip() throws {
        let original = ClientCertificate(
            keychainIdentifier: "com.ha-ios.mtls.roundtrip",
            displayName: "Round Trip Test",
            importedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClientCertificate.self, from: data)

        #expect(decoded == original)
        #expect(decoded.keychainIdentifier == original.keychainIdentifier)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.importedAt == original.importedAt)
        #expect(decoded.expiresAt == original.expiresAt)
    }

    @Test("Given ClientCertificate with nil expiresAt when encoding and decoding then preserves nil")
    func codableWithNilExpiration() throws {
        let original = ClientCertificate(
            keychainIdentifier: "com.ha-ios.mtls.nilexpiry",
            displayName: "No Expiry Test",
            importedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClientCertificate.self, from: data)

        #expect(decoded == original)
        #expect(decoded.expiresAt == nil)
    }
}

#if !os(watchOS)
@Suite("ClientCertificateError Tests")
struct ClientCertificateErrorTests {
    @Test("Given invalidP12Data error when getting errorDescription then returns appropriate message")
    func invalidP12DataDescription() {
        let error = ClientCertificateError.invalidP12Data
        #expect(error.errorDescription == "The certificate file is invalid or corrupted")
    }

    @Test("Given invalidPassword error when getting errorDescription then returns appropriate message")
    func invalidPasswordDescription() {
        let error = ClientCertificateError.invalidPassword
        #expect(error.errorDescription == "The password is incorrect")
    }

    @Test("Given keychainError when getting errorDescription then includes status code")
    func keychainErrorDescription() {
        let error = ClientCertificateError.keychainError(-25300)
        #expect(error.errorDescription?.contains("-25300") == true)
        #expect(error.errorDescription?.contains("Keychain error") == true)
    }

    @Test("Given identityNotFound error when getting errorDescription then returns appropriate message")
    func identityNotFoundDescription() {
        let error = ClientCertificateError.identityNotFound
        #expect(error.errorDescription == "No identity found in the certificate")
    }

    @Test("Given certificateNotFound error when getting errorDescription then returns appropriate message")
    func certificateNotFoundDescription() {
        let error = ClientCertificateError.certificateNotFound
        #expect(error.errorDescription == "Certificate not found in Keychain")
    }

    @Test(
        "Given various keychain status codes when creating keychainError then formats correctly",
        arguments: [
            (-25291, "Keychain error: -25291"), // errSecNoSuchKeychain
            (-25293, "Keychain error: -25293"), // errSecInvalidKeychain
            (-25299, "Keychain error: -25299"), // errSecDuplicateItem
            (-25300, "Keychain error: -25300"), // errSecItemNotFound
        ]
    )
    func keychainErrorStatusCodes(status: Int32, expectedDescription: String) {
        let error = ClientCertificateError.keychainError(OSStatus(status))
        #expect(error.errorDescription == expectedDescription)
    }
}
#endif
