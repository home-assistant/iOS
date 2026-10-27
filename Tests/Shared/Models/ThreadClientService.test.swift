@testable import Shared
import Testing

struct ThreadClientServiceTests {
    @Test func enableCredentialSharingModeRejectsNonHexadecimalInput() async {
        await #expect(throws: ThreadClientServiceError.failedToConvertToHexadecimal) {
            try await ThreadClientService().enableCredentialSharingMode(extendedPANID: "zz")
        }
    }

    @Test func enableCredentialSharingModeRejectsEmptyInput() async {
        await #expect(throws: ThreadClientServiceError.failedToConvertToHexadecimal) {
            try await ThreadClientService().enableCredentialSharingMode(extendedPANID: "")
        }
    }

    #if !canImport(ThreadNetwork)
    @Test func enableCredentialSharingModeIsUnavailableWithoutThreadNetwork() async {
        await #expect(throws: ThreadClientServiceError.credentialSharingModeUnavailable) {
            try await ThreadClientService().enableCredentialSharingMode(extendedPANID: "deadbeef00112233")
        }
    }
    #endif

    @Test func errorDescriptionsAreLocalized() {
        #expect(
            ThreadClientServiceError.failedToConvertToHexadecimal.errorDescription
                == L10n.Thread.ClientError.hexadecimalConversion
        )
        #expect(
            ThreadClientServiceError.credentialSharingModeUnavailable.errorDescription
                == L10n.Thread.ClientError.credentialSharingModeUnavailable
        )
    }
}
