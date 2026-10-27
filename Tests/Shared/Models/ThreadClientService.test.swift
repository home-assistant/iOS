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
