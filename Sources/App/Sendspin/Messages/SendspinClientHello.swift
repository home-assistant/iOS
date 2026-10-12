import Foundation

/// `client/hello`: what this device is and the roles it can take on.
struct SendspinClientHello: Codable, Equatable {
    let name: String
    let deviceInfo: SendspinDeviceInfo?
    let supportedRoles: [String]
    let playerSupport: SendspinPlayerSupport
    let supportedPairMethods: SendspinSupportedPairMethods
    let unpairedAccess: SendspinUnpairedAccess

    enum CodingKeys: String, CodingKey {
        case name
        case deviceInfo = "device_info"
        case supportedRoles = "supported_roles"
        case playerSupport = "player@v1_support"
        case supportedPairMethods = "supported_pair_methods"
        case unpairedAccess = "unpaired_access"
    }
}
