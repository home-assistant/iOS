import Foundation
import Shared

final class LocalAccessPermissionViewModel: ObservableObject {
    @Published var selection: String? = LocalAccessPermissionOptions.secure.rawValue
}
