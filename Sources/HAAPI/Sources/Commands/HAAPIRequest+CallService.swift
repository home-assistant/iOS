public extension HAAPIRequest where Response == HAAPIResponseVoid {
    static func callService(
        domain: String,
        service: String,
        serviceData: [String: HAAPIJSONValue]? = nil,
        target: [String: HAAPIJSONValue]? = nil
    ) -> Self {
        var data: [String: HAAPIJSONValue] = [
            "domain": .string(domain),
            "service": .string(service),
        ]
        if let serviceData {
            data["service_data"] = .object(serviceData)
        }
        if let target {
            data["target"] = .object(target)
        }
        return .init(command: "call_service", data: data)
    }
}
