public extension HAAPIRequest where Response == HAAPIJSONValue {
    /// The display registry response uses its own compressed key scheme and an
    /// `entity_categories` lookup table, so it is exposed untyped — consumers decode it with
    /// their existing model (the apps reuse `EntityRegistryListForDisplay`).
    static func entityRegistryListForDisplay() -> Self {
        .init(command: "config/entity_registry/list_for_display")
    }
}

public extension HAAPIRequest where Response == [HAAPIArea] {
    static func areaRegistryList() -> Self {
        .init(command: "config/area_registry/list")
    }
}

public extension HAAPIRequest where Response == [HAAPIFloor] {
    static func floorRegistryList() -> Self {
        .init(command: "config/floor_registry/list")
    }
}

public extension HAAPIRequest where Response == [HAAPIDeviceRegistryEntry] {
    static func deviceRegistryList() -> Self {
        .init(command: "config/device_registry/list")
    }
}
