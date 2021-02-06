import Foundation
import ObjectMapper

public class ServicesResponse: Mappable {
    public var Domain: String = ""
    public var Services: [String: ServiceDefinition] = [:]

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Domain <- map["domain"]
        Services <- map["services"]
    }
}

public class ServiceDefinition: Mappable {
    public var Description: String?
    public var Fields: [String: ServiceField] = [:]

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Description <- map["description"]
        Fields <- map["fields"]
    }
}

public class ServiceField: Mappable {
    public var Description: String?
    public var Example: Any?
    public var Default: Any?
    public var Values: [Any]?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Description <- map["description"]
        Example <- map["example"]
        Default <- map["default"]
        Values <- map["values"]
    }
}
