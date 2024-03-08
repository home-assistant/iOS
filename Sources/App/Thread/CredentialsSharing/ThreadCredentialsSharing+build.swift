import Foundation
import Shared

// swiftlint:disable force_cast
@available(iOS 16.4, *)
extension ThreadCredentialsSharingView {
    static func buildTransferToHomeAssistant(server: Server) -> ThreadCredentialsSharingView {
        let viewModel = ThreadTransferCredentialToHAViewModel(server: server, threadClient: ThreadClientService())
        return ThreadCredentialsSharingView(viewModel: viewModel as! Model)
    }

    static func buildTransferToAppleKeychain(
        macExtendedAddress: String,
        activeOperationalDataset: String
    ) -> ThreadCredentialsSharingView {
        let viewModel = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: macExtendedAddress,
            activeOperationalDataset: activeOperationalDataset
        )
        return ThreadCredentialsSharingView(viewModel: viewModel as! Model)
    }
}
