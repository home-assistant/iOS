@testable import Shared
import Security
import XCTest

class ClientCertificateManagerTests: XCTestCase {
    private let testCertName = "unit_test_cert_\(UUID().uuidString)"

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up test certificate if it exists
        try? ClientCertificateManager.shared.deleteIdentity(name: testCertName)
    }

    // MARK: - P12 Validation Tests

    func testValidateP12WithCorrectPassword() {
        // Given a valid P12 file and correct password
        guard let p12Data = loadTestP12() else {
            // Skip test if no test certificate available
            throw XCTSkip("No test P12 certificate available")
        }

        // When validating with correct password
        let isValid = ClientCertificateManager.shared.validateP12(data: p12Data, password: "test")

        // Then validation should succeed
        XCTAssertTrue(isValid)
    }

    func testValidateP12WithWrongPassword() {
        // Given a valid P12 file
        guard let p12Data = loadTestP12() else {
            throw XCTSkip("No test P12 certificate available")
        }

        // When validating with wrong password
        let isValid = ClientCertificateManager.shared.validateP12(data: p12Data, password: "wrong_password")

        // Then validation should fail
        XCTAssertFalse(isValid)
    }

    func testValidateP12WithInvalidData() {
        // Given invalid data
        let invalidData = Data("not a p12 file".utf8)

        // When validating
        let isValid = ClientCertificateManager.shared.validateP12(data: invalidData, password: "any")

        // Then validation should fail
        XCTAssertFalse(isValid)
    }

    // MARK: - Certificate Lifecycle Tests

    func testAvailableCertificatesReturnsArray() {
        // When querying available certificates
        let certificates = ClientCertificateManager.shared.availableCertificates()

        // Then should return an array (may be empty)
        XCTAssertNotNil(certificates)
    }

    func testReadIdentityForNonExistentCertificateReturnsNil() {
        // Given a name that doesn't exist
        let nonExistentName = "non_existent_cert_\(UUID().uuidString)"

        // When reading identity
        let identity = ClientCertificateManager.shared.readIdentity(name: nonExistentName)

        // Then should return nil
        XCTAssertNil(identity)
    }

    func testCredentialForNonExistentCertificateReturnsNil() {
        // Given a certificate reference that doesn't exist
        let cert = ClientCertificate(name: "non_existent_\(UUID().uuidString)")

        // When getting credential
        let credential = ClientCertificateManager.shared.credential(for: cert)

        // Then should return nil
        XCTAssertNil(credential)
    }

    func testDeleteNonExistentCertificateSucceeds() {
        // Given a name that doesn't exist
        let nonExistentName = "non_existent_cert_\(UUID().uuidString)"

        // When deleting (should not throw - errSecItemNotFound is acceptable)
        XCTAssertNoThrow(try ClientCertificateManager.shared.deleteIdentity(name: nonExistentName))
    }

    // MARK: - Error Cases

    func testImportP12WithWrongPasswordThrowsError() {
        guard let p12Data = loadTestP12() else {
            throw XCTSkip("No test P12 certificate available")
        }

        // When importing with wrong password
        // Then should throw wrongPassword error
        XCTAssertThrowsError(
            try ClientCertificateManager.shared.importP12(data: p12Data, password: "wrong", name: testCertName)
        ) { error in
            guard let certError = error as? ClientCertificateError else {
                XCTFail("Expected ClientCertificateError")
                return
            }
            if case .wrongPassword = certError {
                // Expected error
            } else {
                XCTFail("Expected wrongPassword error, got: \(certError)")
            }
        }
    }

    func testImportInvalidDataThrowsError() {
        // Given invalid data
        let invalidData = Data("not a p12 file".utf8)

        // When importing
        // Then should throw importFailed error
        XCTAssertThrowsError(
            try ClientCertificateManager.shared.importP12(data: invalidData, password: "any", name: testCertName)
        )
    }

    // MARK: - Helper Methods

    private func loadTestP12() -> Data? {
        // Look for test certificate in test bundle
        guard let url = Bundle(for: type(of: self)).url(forResource: "test_cert", withExtension: "p12") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}

// MARK: - ClientCertificateError Tests

class ClientCertificateErrorTests: XCTestCase {
    func testErrorDescriptions() {
        // Verify all error cases have descriptions
        let errors: [ClientCertificateError] = [
            .wrongPassword,
            .noIdentity,
            .importFailed(-25291),
            .saveFailed(-25299),
            .deleteFailed(-25300),
            .readFailed(-25301)
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func testWrongPasswordDescription() {
        let error = ClientCertificateError.wrongPassword
        XCTAssertEqual(error.errorDescription, "The password is incorrect.")
    }

    func testNoIdentityDescription() {
        let error = ClientCertificateError.noIdentity
        XCTAssertEqual(error.errorDescription, "The file does not contain a valid identity.")
    }
}
