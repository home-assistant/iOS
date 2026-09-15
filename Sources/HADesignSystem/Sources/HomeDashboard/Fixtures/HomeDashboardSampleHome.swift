import Foundation

/// A home with enough in it to exercise every branch the strategies have: two floors, an area on
/// neither, rooms with lights, heating, a lock, a camera and a speaker, a room with nothing in it at
/// all, batteries on their devices, and a couple of entities that belong to no room.
///
/// Used by the previews, the gallery and the snapshots. Every id is spelled out rather than
/// generated so a reference image only changes when somebody means it to.
public enum HomeDashboardSampleHome {
    public static let registry = HomeRegistry(
        areas: areas,
        floors: floors,
        devices: devices,
        entities: entities,
        states: states,
        panels: ["light", "climate", "security", "maintenance", "energy"],
        isAdmin: true,
        userName: "Bruno",
        hasEnergyData: true
    )

    /// The same home with no areas at all, which is what a brand-new server looks like.
    public static let emptyRegistry = HomeRegistry(
        panels: ["light"],
        isAdmin: true,
        userName: "Bruno"
    )

    // MARK: - Registries

    public static let floors: [HomeFloor] = [
        HomeFloor(id: "ground_floor", name: "Ground floor", level: 0),
        HomeFloor(id: "first_floor", name: "First floor", level: 1),
    ]

    public static let areas: [HomeArea] = [
        HomeArea(
            id: "living_room",
            name: "Living room",
            icon: "mdi:sofa",
            floorId: "ground_floor",
            temperatureEntityId: "sensor.living_room_temperature",
            humidityEntityId: "sensor.living_room_humidity"
        ),
        HomeArea(id: "kitchen", name: "Kitchen", icon: "mdi:countertop", floorId: "ground_floor"),
        HomeArea(
            id: "bedroom",
            name: "Bedroom",
            icon: "mdi:bed",
            floorId: "first_floor",
            temperatureEntityId: "sensor.bedroom_temperature"
        ),
        HomeArea(id: "bathroom", name: "Bathroom", icon: "mdi:shower", floorId: "first_floor"),
        HomeArea(id: "garage", name: "Garage", icon: "mdi:garage"),
    ]

    public static let devices: [HomeDevice] = [
        HomeDevice(id: "ceiling_lamp", name: "Ceiling lamp", areaId: "living_room"),
        HomeDevice(id: "thermostat", name: "Thermostat", nameByUser: "Living room thermostat", areaId: "living_room"),
        HomeDevice(id: "media_box", name: "Apple TV", areaId: "living_room"),
        HomeDevice(id: "air_quality", name: "Air quality sensor", areaId: "living_room"),
        HomeDevice(id: "kitchen_lights", name: "Kitchen lights", areaId: "kitchen"),
        HomeDevice(id: "dishwasher", name: "Dishwasher", areaId: "kitchen"),
        HomeDevice(id: "bedside", name: "Bedside lamp", areaId: "bedroom"),
        HomeDevice(id: "window_sensor", name: "Window sensor", areaId: "bedroom"),
        HomeDevice(id: "bathroom_light", name: "Bathroom light", areaId: "bathroom"),
        HomeDevice(id: "front_door", name: "Front door", areaId: "garage"),
        HomeDevice(id: "doorbell", name: "Doorbell", areaId: "garage"),
        HomeDevice(id: "garage_door", name: "Garage door", areaId: "garage"),
        HomeDevice(id: "printer", name: "Printer"),
    ]
}

// MARK: - Entities

public extension HomeDashboardSampleHome {
    static let entities: [HomeEntityRegistration] = [
        HomeEntityRegistration(id: "light.living_room_ceiling", platform: "hue", deviceId: "ceiling_lamp"),
        HomeEntityRegistration(id: "climate.living_room", platform: "tado", deviceId: "thermostat"),
        HomeEntityRegistration(id: "media_player.living_room", platform: "cast", deviceId: "media_box"),
        HomeEntityRegistration(id: "sensor.living_room_temperature", platform: "tado", deviceId: "thermostat"),
        HomeEntityRegistration(id: "sensor.living_room_humidity", platform: "tado", deviceId: "thermostat"),
        HomeEntityRegistration(id: "sensor.living_room_air_quality", platform: "awair", deviceId: "air_quality"),
        HomeEntityRegistration(
            id: "sensor.living_room_air_quality_battery",
            platform: "awair",
            deviceId: "air_quality",
            entityCategory: .diagnostic
        ),
        HomeEntityRegistration(id: "scene.movie_night", platform: "homeassistant", areaId: "living_room"),
        HomeEntityRegistration(id: "automation.evening_lights", platform: "automation", areaId: "living_room"),

        HomeEntityRegistration(id: "light.kitchen_counter", platform: "hue", deviceId: "kitchen_lights"),
        HomeEntityRegistration(id: "light.kitchen_ceiling", platform: "hue", deviceId: "kitchen_lights"),
        HomeEntityRegistration(id: "switch.kitchen_dishwasher", platform: "bosch", deviceId: "dishwasher"),
        HomeEntityRegistration(
            id: "sensor.kitchen_dishwasher_programme",
            platform: "bosch",
            deviceId: "dishwasher",
            entityCategory: .diagnostic
        ),

        HomeEntityRegistration(id: "light.bedroom_bedside", platform: "hue", deviceId: "bedside"),
        HomeEntityRegistration(id: "sensor.bedroom_temperature", platform: "aqara", deviceId: "window_sensor"),
        HomeEntityRegistration(id: "binary_sensor.bedroom_window", platform: "aqara", deviceId: "window_sensor"),
        HomeEntityRegistration(id: "sensor.bedroom_window_battery", platform: "aqara", deviceId: "window_sensor"),

        HomeEntityRegistration(id: "light.bathroom_ceiling", platform: "hue", deviceId: "bathroom_light"),

        HomeEntityRegistration(id: "lock.front_door", platform: "nuki", deviceId: "front_door"),
        HomeEntityRegistration(id: "camera.doorbell", platform: "unifi", deviceId: "doorbell"),
        HomeEntityRegistration(id: "cover.garage_door", platform: "somfy", deviceId: "garage_door"),

        HomeEntityRegistration(id: "sensor.printer_ink", platform: "ipp", deviceId: "printer"),
        HomeEntityRegistration(id: "weather.home", platform: "met"),
        HomeEntityRegistration(id: "person.bruno", platform: "person"),
        HomeEntityRegistration(id: "zone.home", platform: "zone"),
    ]

    static let states: [HomeEntityState] = [
        HomeEntityState(
            id: "light.living_room_ceiling",
            state: "on",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room ceiling",
                brightness: 204,
                supportedColorModes: ["color_temp", "hs"]
            )
        ),
        HomeEntityState(
            id: "climate.living_room",
            state: "heat",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room thermostat",
                supportedFeatures: 1,
                currentTemperature: 21.4,
                targetTemperature: 22,
                hvacAction: "heating"
            )
        ),
        HomeEntityState(
            id: "media_player.living_room",
            state: "playing",
            attributes: HomeEntityAttributes(friendlyName: "Living room Apple TV", mediaTitle: "Blade Runner 2049")
        ),
        HomeEntityState(
            id: "sensor.living_room_temperature",
            state: "21.4",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room temperature",
                deviceClass: "temperature",
                unitOfMeasurement: "°C"
            )
        ),
        HomeEntityState(
            id: "sensor.living_room_humidity",
            state: "48",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room humidity",
                deviceClass: "humidity",
                unitOfMeasurement: "%"
            )
        ),
        HomeEntityState(
            id: "sensor.living_room_air_quality",
            state: "12",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room air quality",
                deviceClass: "pm25",
                unitOfMeasurement: "µg/m³"
            )
        ),
        HomeEntityState(
            id: "sensor.living_room_air_quality_battery",
            state: "68",
            attributes: HomeEntityAttributes(
                friendlyName: "Living room air quality battery",
                deviceClass: "battery",
                unitOfMeasurement: "%"
            )
        ),
        HomeEntityState(
            id: "scene.movie_night",
            state: "unknown",
            attributes: HomeEntityAttributes(friendlyName: "Movie night")
        ),
        HomeEntityState(
            id: "automation.evening_lights",
            state: "on",
            attributes: HomeEntityAttributes(friendlyName: "Evening lights")
        ),

        HomeEntityState(
            id: "light.kitchen_counter",
            state: "on",
            attributes: HomeEntityAttributes(
                friendlyName: "Kitchen counter",
                brightness: 255,
                supportedColorModes: ["brightness"]
            )
        ),
        HomeEntityState(
            id: "light.kitchen_ceiling",
            state: "off",
            attributes: HomeEntityAttributes(friendlyName: "Kitchen ceiling", supportedColorModes: ["brightness"])
        ),
        HomeEntityState(
            id: "switch.kitchen_dishwasher",
            state: "on",
            attributes: HomeEntityAttributes(friendlyName: "Kitchen dishwasher")
        ),
        HomeEntityState(
            id: "sensor.kitchen_dishwasher_programme",
            state: "Eco 50",
            attributes: HomeEntityAttributes(friendlyName: "Kitchen dishwasher programme")
        ),

        HomeEntityState(
            id: "light.bedroom_bedside",
            state: "off",
            attributes: HomeEntityAttributes(friendlyName: "Bedroom bedside", supportedColorModes: ["color_temp"])
        ),
        HomeEntityState(
            id: "sensor.bedroom_temperature",
            state: "18.9",
            attributes: HomeEntityAttributes(
                friendlyName: "Bedroom temperature",
                deviceClass: "temperature",
                unitOfMeasurement: "°C"
            )
        ),
        HomeEntityState(
            id: "binary_sensor.bedroom_window",
            state: "off",
            attributes: HomeEntityAttributes(friendlyName: "Bedroom window", deviceClass: "window")
        ),
        HomeEntityState(
            id: "sensor.bedroom_window_battery",
            state: "12",
            attributes: HomeEntityAttributes(
                friendlyName: "Bedroom window battery",
                deviceClass: "battery",
                unitOfMeasurement: "%"
            )
        ),

        HomeEntityState(
            id: "light.bathroom_ceiling",
            state: "off",
            attributes: HomeEntityAttributes(friendlyName: "Bathroom ceiling", supportedColorModes: ["brightness"])
        ),

        HomeEntityState(
            id: "lock.front_door",
            state: "locked",
            attributes: HomeEntityAttributes(friendlyName: "Front door")
        ),
        HomeEntityState(
            id: "camera.doorbell",
            state: "idle",
            attributes: HomeEntityAttributes(friendlyName: "Doorbell")
        ),
        HomeEntityState(
            id: "cover.garage_door",
            state: "closed",
            attributes: HomeEntityAttributes(friendlyName: "Garage door", deviceClass: "garage", supportedFeatures: 3)
        ),

        HomeEntityState(
            id: "sensor.printer_ink",
            state: "42",
            attributes: HomeEntityAttributes(friendlyName: "Printer ink", unitOfMeasurement: "%")
        ),
        HomeEntityState(
            id: "weather.home",
            state: "partlycloudy",
            attributes: HomeEntityAttributes(friendlyName: "Home", currentTemperature: 17.2)
        ),
        HomeEntityState(id: "person.bruno", state: "home", attributes: HomeEntityAttributes(friendlyName: "Bruno")),
        HomeEntityState(id: "zone.home", state: "1", attributes: HomeEntityAttributes(friendlyName: "Home")),
    ]

    /// The options a home like this one would be generated with: two favourites, and a name to greet.
    static let strategyConfig = HomeDashboardStrategyConfig(
        favoriteEntityIds: ["light.kitchen_counter", "climate.living_room"]
    )
}
