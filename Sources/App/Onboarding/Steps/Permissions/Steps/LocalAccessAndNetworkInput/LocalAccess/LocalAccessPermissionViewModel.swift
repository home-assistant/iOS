import Foundation
import Shared

final class LocalAccessPermissionViewModel: ObservableObject {
    @Published var selection: LocalAccessSecurityLevel

    init(initialSelection: LocalAccessSecurityLevel? = nil) {
        self.selection = initialSelection ?? .mostSecure
    }
}
