import Foundation

/// The optional `device_info` object of `client/hello`.
struct SendspinDeviceInfo: Codable, Equatable {
    let productName: String?
    let manufacturer: String?
    let softwareVersion: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case manufacturer
        case softwareVersion = "software_version"
    }
}
