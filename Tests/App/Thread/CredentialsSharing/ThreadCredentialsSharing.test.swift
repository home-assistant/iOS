@testable import HomeAssistant
@testable import Shared
import XCTest

@available(iOS 16.4, *)
final class ThreadCredentialsSharing: XCTestCase {
    func testBuildSucceed() {
        _ = ThreadCredentialsSharingView<ThreadTransferCredentialToHAViewModel>
            .buildTransferToHomeAssistant(server: ServerFixture.standard)
        _ = ThreadCredentialsSharingView<ThreadTransferCredentialToKeychainViewModel>.buildTransferToAppleKeychain(
            macExtendedAddress: "",
            activeOperationalDataset: ""
        )
    }
}
