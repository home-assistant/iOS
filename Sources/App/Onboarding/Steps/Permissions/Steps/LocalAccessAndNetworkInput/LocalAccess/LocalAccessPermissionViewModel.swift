import Foundation
import Shared

final class LocalAccessPermissionViewModel: ObservableObject {
    @Published var selection: ConnectionSecurityLevel

    init(initialSelection: ConnectionSecurityLevel? = nil) {
        self.selection = initialSelection ?? .mostSecure
    }
}
