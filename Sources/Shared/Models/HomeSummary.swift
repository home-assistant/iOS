import Foundation

public enum EntityCategory: String, Codable, Sendable, CaseIterable {
    case none
    case config
    case diagnostic
}

public struct EntityFilter: Equatable, Sendable {
    public var domain: [String]?
    public var deviceClass: [String]?
    public var device: [String?]?
    public var area: [String?]?
    public var floor: [String?]?
    public var label: [String]?
    public var entityCategory: [EntityCategory]?
    public var hiddenPlatform: [String]?
    public var hiddenDomains: [String]?

    public init(
        domain: [String]? = nil,
        deviceClass: [String]? = nil,
        device: [String?]? = nil,
        area: [String?]? = nil,
        floor: [String?]? = nil,
        label: [String]? = nil,
        entityCategory: [EntityCategory]? = nil,
        hiddenPlatform: [String]? = nil,
        hiddenDomains: [String]? = nil
    ) {
        self.domain = domain
        self.deviceClass = deviceClass
        self.device = device
        self.area = area
        self.floor = floor
        self.label = label
        self.entityCategory = entityCategory
        self.hiddenPlatform = hiddenPlatform
        self.hiddenDomains = hiddenDomains
    }
}

public enum HomeSummary: String, CaseIterable, Sendable {
    case light
    case climate
    case security
    case mediaPlayers = "media_players"
    case maintenance
    case energy
    case persons

    public var iconName: String {
        switch self {
        case .light: return "lamps"
        case .climate: return "home-thermometer"
        case .security: return "security"
        case .mediaPlayers: return "multimedia"
        case .maintenance: return "wrench"
        case .energy: return "lightning-bolt"
        case .persons: return "account-multiple"
        }
    }

    public var icon: MaterialDesignIcons {
        MaterialDesignIcons(named: iconName.replacingOccurrences(of: "-", with: "_"))
    }

    public var themeColor: String {
        switch self {
        case .light: return "amber"
        case .climate: return "deep-orange"
        case .security: return "blue-grey"
        case .mediaPlayers: return "blue"
        case .maintenance: return "grey"
        case .energy: return "amber"
        case .persons: return "green"
        }
    }

    public var filters: [EntityFilter] {
        switch self {
        case .light: return Self.lightEntityFilters
        case .climate: return Self.climateEntityFilters
        case .security: return Self.securityEntityFilters
        case .mediaPlayers: return Self.mediaPlayerEntityFilters
        case .maintenance: return Self.maintenanceEntityFilters
        case .energy: return []
        case .persons: return Self.personEntityFilters
        }
    }
}

public extension HomeSummary {
    static let lightEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.light.rawValue], entityCategory: [.none]),
    ]

    static let climateEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.climate.rawValue], entityCategory: [.none]),
        EntityFilter(domain: [Domain.humidifier.rawValue], entityCategory: [.none]),
        EntityFilter(domain: [Domain.fan.rawValue], entityCategory: [.none]),
        EntityFilter(domain: [Domain.waterHeater.rawValue], entityCategory: [.none]),
        EntityFilter(
            domain: [Domain.cover.rawValue],
            deviceClass: ["awning", "blind", "curtain", "shade", "shutter", "window", "none"],
            entityCategory: [.none]
        ),
        EntityFilter(domain: [Domain.binarySensor.rawValue], deviceClass: ["window"], entityCategory: [.none]),
    ]

    static let securityEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.camera.rawValue], entityCategory: [.none]),
        EntityFilter(domain: [Domain.alarmControlPanel.rawValue], entityCategory: [.none]),
        EntityFilter(domain: [Domain.lock.rawValue], entityCategory: [.none]),
        EntityFilter(
            domain: [Domain.cover.rawValue],
            deviceClass: ["door", "garage", "gate", "window"],
            entityCategory: [.none]
        ),
        EntityFilter(
            domain: [Domain.binarySensor.rawValue],
            deviceClass: [
                "lock",
                "door",
                "window",
                "garage_door",
                "opening",
                "carbon_monoxide",
                "gas",
                "moisture",
                "safety",
                "smoke",
                "tamper",
            ],
            entityCategory: [.none]
        ),
        EntityFilter(domain: [Domain.binarySensor.rawValue], deviceClass: ["tamper"], entityCategory: [.diagnostic]),
    ]

    static let maintenanceEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.sensor.rawValue], deviceClass: ["battery"]),
        EntityFilter(domain: [Domain.binarySensor.rawValue], deviceClass: ["battery"]),
    ]

    static let mediaPlayerEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.mediaPlayer.rawValue], entityCategory: [.none]),
    ]

    static let personEntityFilters: [EntityFilter] = [
        EntityFilter(domain: [Domain.person.rawValue]),
    ]
}

public extension HomeSummary {
    static func applicableSummaries(
        evaluator: EntityFilterEvaluator,
        panelPaths: Set<String>? = nil,
        energyPreferences: EnergyPreferences? = nil
    ) -> [HomeSummary] {
        allCases.filter {
            $0.isApplicable(evaluator: evaluator, panelPaths: panelPaths, energyPreferences: energyPreferences)
        }
    }

    func isApplicable(
        evaluator: EntityFilterEvaluator,
        panelPaths: Set<String>?,
        energyPreferences: EnergyPreferences?
    ) -> Bool {
        switch self {
        case .energy:
            let hasPanel = panelPaths?.contains(rawValue) ?? true
            return hasPanel && (energyPreferences?.hasGridSource ?? false)
        case .light, .climate, .security, .maintenance:
            let hasPanel = panelPaths?.contains(rawValue) ?? true
            return hasPanel && !evaluator.findEntities(matching: filters).isEmpty
        case .mediaPlayers, .persons:
            return !evaluator.findEntities(matching: filters).isEmpty
        }
    }
}
