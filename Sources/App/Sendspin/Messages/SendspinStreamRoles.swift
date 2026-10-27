import Foundation

/// The payload of `stream/clear` and `stream/end`: which roles they apply to, or every active one
/// when `roles` is left out.
struct SendspinStreamRoles: Codable, Equatable {
    let roles: [String]?

    func includes(_ role: String) -> Bool {
        roles?.contains(role) ?? true
    }
}
