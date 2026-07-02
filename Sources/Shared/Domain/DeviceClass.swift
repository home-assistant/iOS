import Foundation

public enum DeviceClass: String, CaseIterable {
    case battery
    case cold
    case connectivity
    case door
    case garage
    case garageDoor = "garage_door"
    case gas
    case heat
    case humidity
    case illuminance
    case light
    case lock
    case moisture
    case motion
    case moving
    case occupancy
    case opening
    case plug
    case power
    case presence
    case pressure
    case problem
    case safety
    case smoke
    case sound
    case temperature
    case timestamp
    case vibration
    case window
    case gate
    case damper
    case shutter
    case curtain
    case blind
    case shade
    case restart
    case update
    case outlet
    case `switch`
    case batteryCharging = "battery_charging"
    case carbonMonoxide = "carbon_monoxide"
    case running
    case tamper
    case awning
    case water
    case doorbell
    case button
    case tv
    case speaker
    case receiver
    case projector
    case humidifier
    case dehumidifier
    case identify
    case firmware
    case date
    case `enum` = "enum"
    case uptime
    case absoluteHumidity = "absolute_humidity"
    case apparentPower = "apparent_power"
    case aqi
    case area
    case atmosphericPressure = "atmospheric_pressure"
    case bloodGlucoseConcentration = "blood_glucose_concentration"
    case carbonDioxide = "carbon_dioxide"
    case conductivity
    case current
    case dataRate = "data_rate"
    case dataSize = "data_size"
    case distance
    case duration
    case energy
    case energyDistance = "energy_distance"
    case energyStorage = "energy_storage"
    case frequency
    case irradiance
    case monetary
    case nitrogenDioxide = "nitrogen_dioxide"
    case nitrogenMonoxide = "nitrogen_monoxide"
    case nitrousOxide = "nitrous_oxide"
    case ozone
    case ph
    case pm1
    case pm10
    case pm25
    case pm4
    case powerFactor = "power_factor"
    case precipitation
    case precipitationIntensity = "precipitation_intensity"
    case reactiveEnergy = "reactive_energy"
    case reactivePower = "reactive_power"
    case signalStrength = "signal_strength"
    case soundPressure = "sound_pressure"
    case speed
    case sulphurDioxide = "sulphur_dioxide"
    case temperatureDelta = "temperature_delta"
    case volatileOrganicCompounds = "volatile_organic_compounds"
    case volatileOrganicCompoundsParts = "volatile_organic_compounds_parts"
    case voltage
    case volume
    case volumeStorage = "volume_storage"
    case volumeFlowRate = "volume_flow_rate"
    case weight
    case windDirection = "wind_direction"
    case windSpeed = "wind_speed"
    case unknown
}
