import Foundation
import ObjectMapper
import PromiseKit

public class DiscoveredHomeAssistant: Mappable {
    public var BaseURL = URL(string: "http://example.com")!
    public var LocationName: String = ""
    public var Version: String = ""

    // If false, this class was manually constructed
    public var Discovered: Bool = true

    public init() {}

    public required init?(map: Map) {}

    public convenience init(baseURL: URL, name: String, version: String) {
        self.init()
        self.BaseURL = baseURL
        self.LocationName = name
        self.Version = version
        self.Discovered = false
    }

    public func mapping(map: Map) {
        BaseURL <- (map["base_url"], URLTransform())
        LocationName <- map["location_name"]
        Version <- map["version"]
    }
}
