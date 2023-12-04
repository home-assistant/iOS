import Foundation
import Shared

@available(iOS 16.4, *)
extension ThreadCredentialsSharingView {
    static func build(server: Server) -> ThreadCredentialsSharingView {
        .init(
            viewModel: .init(
                server: server,
                threadClient: ThreadClientService()
            )
        )
    }
}
