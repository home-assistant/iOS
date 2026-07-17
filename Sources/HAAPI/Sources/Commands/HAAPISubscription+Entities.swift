public extension HAAPISubscription where Event == HAAPICompressedStatesUpdate {
    static func subscribeEntities(entityIds: [String]? = nil) -> Self {
        var data: [String: HAAPIJSONValue] = [:]
        if let entityIds {
            data["entity_ids"] = .array(entityIds.map { .string($0) })
        }
        return .init(command: "subscribe_entities", data: data)
    }
}
