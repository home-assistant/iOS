import Foundation

public enum HomeSummaryState: Equatable, Sendable {
    case lights(onCount: Int)
    case climate(minTemperature: Double, maxTemperature: Double)
    case climateUnavailable
    case security(SecuritySummary)
    case mediaPlayers(playingCount: Int)
    case maintenance(lowBattery: Int, unavailableBattery: Int)
    case energy(totalConsumption: Double?)
    case persons(homeCount: Int)
}

public struct SecuritySummary: Equatable, Sendable {
    public let hasSecurityEntities: Bool
    public let unlockedLocks: Int
    public let disarmedAlarms: Int

    public init(hasSecurityEntities: Bool, unlockedLocks: Int, disarmedAlarms: Int) {
        self.hasSecurityEntities = hasSecurityEntities
        self.unlockedLocks = unlockedLocks
        self.disarmedAlarms = disarmedAlarms
    }
}

public extension HomeSummary {
    func state(using evaluator: EntityFilterEvaluator, areas: [HAAreasRegistryResponse]) -> HomeSummaryState {
        switch self {
        case .light:
            let matched = evaluator.findEntities(matching: filters)
            return .lights(onCount: matched.filter { evaluator.states[$0]?.state == "on" }.count)
        case .climate:
            let temperatures = areas
                .compactMap(\.temperatureEntityId)
                .compactMap { evaluator.states[$0]?.state }
                .compactMap(Double.init)
            guard let minimum = temperatures.min(), let maximum = temperatures.max() else {
                return .climateUnavailable
            }
            return .climate(minTemperature: minimum, maxTemperature: maximum)
        case .security:
            let matched = evaluator.findEntities(matching: filters)
            let locks = matched.filter { $0.hasPrefix("\(Domain.lock.rawValue).") }
            let alarms = matched.filter { $0.hasPrefix("\(Domain.alarmControlPanel.rawValue).") }
            guard !locks.isEmpty || !alarms.isEmpty else {
                return .security(SecuritySummary(hasSecurityEntities: false, unlockedLocks: 0, disarmedAlarms: 0))
            }
            let unlockedStates: Set<String> = ["unlocked", "jammed", "open"]
            return .security(SecuritySummary(
                hasSecurityEntities: true,
                unlockedLocks: locks.filter { unlockedStates.contains(evaluator.states[$0]?.state ?? "") }.count,
                disarmedAlarms: alarms.filter { evaluator.states[$0]?.state == "disarmed" }.count
            ))
        case .mediaPlayers:
            let matched = evaluator.findEntities(matching: filters)
            return .mediaPlayers(playingCount: matched.filter { evaluator.states[$0]?.state == "playing" }.count)
        case .maintenance:
            let matched = evaluator.findEntities(matching: filters)
            return .maintenance(
                lowBattery: matched.filter { evaluator.isLowBattery(entityId: $0) }.count,
                unavailableBattery: matched.filter { evaluator.states[$0]?.state == "unavailable" }.count
            )
        case .energy:
            return .energy(totalConsumption: nil)
        case .persons:
            let matched = evaluator.findEntities(matching: filters)
            return .persons(homeCount: matched.filter { evaluator.states[$0]?.state == "home" }.count)
        }
    }
}
