import Foundation

/// `unpaired_access` of `client/hello`: whether a server without a pairing record may still
/// activate roles once its operator approves this device.
struct SendspinUnpairedAccess: Codable, Equatable {
    let enabled: Bool
}
