import Foundation

/// The `client/hello` payload: who this device is, what it can do, and how a server may pair with
/// it. Sent once per session, immediately after `server/hello`.
struct SendspinClientHello: Encodable {
    struct DeviceInfo: Encodable {
        let productName: String
        let manufacturer: String
        let softwareVersion: String

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case manufacturer
            case softwareVersion = "software_version"
        }
    }

    struct PlayerSupport: Encodable {
        /// Formats in priority order; the server picks the first one it can produce.
        let supportedFormats: [SendspinAudioFormat]
        /// Hard byte cap on the compressed audio the server may leave queued here.
        let bufferCapacity: Int

        enum CodingKeys: String, CodingKey {
            case supportedFormats = "supported_formats"
            case bufferCapacity = "buffer_capacity"
        }
    }

    struct PairMethods: Encodable {
        struct Descriptor: Encodable {
            let locations: [String]
        }

        /// Every client offers at least the Pairing PSK method. This one is shown in the app, so
        /// the operator finds it on the device itself.
        let pairingPsk = Descriptor(locations: ["device"])

        enum CodingKeys: String, CodingKey {
            case pairingPsk = "pairing_psk"
        }
    }

    struct UnpairedAccess: Encodable {
        let enabled: Bool
    }

    let name: String
    let deviceInfo: DeviceInfo
    let supportedRoles: [SendspinRole]
    let playerSupport: PlayerSupport
    let supportedPairMethods = PairMethods()
    let unpairedAccess: UnpairedAccess

    enum CodingKeys: String, CodingKey {
        case name
        case deviceInfo = "device_info"
        case supportedRoles = "supported_roles"
        case playerSupport = "player@v1_support"
        case supportedPairMethods = "supported_pair_methods"
        case unpairedAccess = "unpaired_access"
    }
}
