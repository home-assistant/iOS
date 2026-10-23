import Foundation
import HANetworking
@testable import HomeAssistant
import Security
import Testing

/// Round trip of an mTLS identity through its export form, the way the app migration carries one.
struct ClientIdentityExportTests {
    @Test func exportedIdentityImportsBackUnderTheSameLabel() throws {
        let manager = ClientCertificateManager.shared
        let imported = try manager.importP12(
            data: TestClientCertificateBundle.data,
            password: TestClientCertificateBundle.password,
            identifier: "export-test"
        )
        let export = try manager.exportIdentity(for: imported.keychainIdentifier)
        #expect(export.intermediateCertificates.count == 1)
        #expect(export.keySizeInBits == 2048)

        SecItemDelete([
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: imported.keychainIdentifier,
        ] as CFDictionary)
        #expect(!manager.hasIdentity(for: imported))

        try manager.importIdentity(export)
        #expect(manager.hasIdentity(for: imported))
        let reExported = try manager.exportIdentity(for: imported.keychainIdentifier)
        #expect(reExported == export)
        _ = try manager.urlCredential(for: imported)
    }
}
