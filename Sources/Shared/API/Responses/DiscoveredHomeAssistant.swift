import Foundation
import ObjectMapper
import PromiseKit
import Version

public struct DiscoveredHomeAssistant: ImmutableMappable {
    public var uuid: String?
    public var version: Version
    public var internalOrExternalURL: URL
    public var externalURL: URL?
    public var internalURL: URL?
    public var locationName: String
    public var bonjourName: String?

    public init(manualURL: URL, name: String = "Home") {
        self.version = Version(major: 2022, minor: 4)
        self.uuid = nil
        self.internalOrExternalURL = manualURL
        self.internalURL = nil
        self.externalURL = manualURL
        self.locationName = name
    }

    private enum TransformError: Error {
        case missingUsableURL
    }

    public init(map: Map) throws {
        self.uuid = try map.value("uuid")
        self.version = try map.value("version", using: VersionTransform())
        self.externalURL = try? map.value("external_url", using: URLTransform())
        self.internalURL = try? map.value("internal_url", using: URLTransform())

        if externalURL == nil, internalURL == nil {
            // compatibility with HA <0.110
            self.externalURL = try? map.value("base_url", using: URLTransform())
        }

        self.locationName = (try? map.value("location_name")) ?? "Home"

        if let url = internalURL ?? externalURL {
            self.internalOrExternalURL = url
        } else {
            throw TransformError.missingUsableURL
        }
    }
}
