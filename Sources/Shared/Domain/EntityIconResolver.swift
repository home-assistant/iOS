import Foundation

/// Resolves an entity's icon the way `home-assistant/frontend` does (`src/data/icons.ts`
/// `getEntityIcon` plus the `stateIcon` special-cases in `src/common/entity/state_icon.ts`), from the
/// backend `entity_component` icon map. The user/registry `icon` override is applied by callers.
/// Integration `translation_key` platform icons (the frontend's step before `stateIcon`) are not yet
/// resolved: a known gap, so entities that rely on them fall through to the component map. This covers
/// the `stateIcon` special-cases and the state / range / default component resolution.
public enum EntityIconResolver {
    /// The stateless default icon for a domain + device class (the `default` of the matching entry,
    /// or the domain's `_` entry). Used for the picker's saved icon, which has no live state.
    public static func componentDefaultIcon(
        domain: String,
        deviceClass: String?,
        map: EntityComponentIconsMap
    ) -> String? {
        translations(domain: domain, deviceClass: deviceClass, map: map)?.defaultIcon
    }

    /// The full, state-aware resolution: the hardcoded `stateIcon` special-cases first, then the
    /// component `state` → `range` → `default` chain. Returns `nil` when nothing matches so the
    /// caller can fall back to its own default.
    public static func icon(
        domain: String,
        deviceClass: String?,
        state: String?,
        attributes: [String: Any],
        map: EntityComponentIconsMap?
    ) -> String? {
        if let stateIcon = stateIcon(domain: domain, state: state, attributes: attributes) {
            return stateIcon
        }
        guard let map,
              let translations = translations(domain: domain, deviceClass: deviceClass, map: map) else {
            return nil
        }
        return iconFromTranslations(state: state, translations: translations)
    }

    static func translations(
        domain: String,
        deviceClass: String?,
        map: EntityComponentIconsMap
    ) -> EntityComponentIcon? {
        guard let domainIcons = map[domain] else { return nil }
        if let deviceClass, let match = domainIcons[deviceClass] {
            return match
        }
        return domainIcons["_"]
    }

    static func iconFromTranslations(state: String?, translations: EntityComponentIcon) -> String? {
        if let state, let match = translations.state?[state] {
            return match
        }
        if let state, let range = translations.range, let value = Double(state) {
            return iconFromRange(value: value, range: range) ?? translations.defaultIcon
        }
        return translations.defaultIcon
    }

    static func iconFromRange(value: Double, range: [String: String]) -> String? {
        let sorted = range
            .compactMap { key, _ -> (threshold: Double, key: String)? in
                guard let threshold = Double(key) else { return nil }
                return (threshold, key)
            }
            .sorted { $0.threshold < $1.threshold }
        guard let first = sorted.first, value >= first.threshold else { return nil }
        var selectedKey = first.key
        for entry in sorted {
            if value >= entry.threshold {
                selectedKey = entry.key
            } else {
                break
            }
        }
        return range[selectedKey]
    }

    static func stateIcon(domain: String, state: String?, attributes: [String: Any]) -> String? {
        switch domain {
        case Domain.update.rawValue:
            if updateIsInstalling(attributes) {
                return "mdi:package-down"
            }
            return state == "on" ? "mdi:package-up" : "mdi:package"
        case Domain.deviceTracker.rawValue:
            let sourceType = attributes["source_type"] as? String
            if sourceType == "router" {
                return state == "home" ? "mdi:lan-connect" : "mdi:lan-disconnect"
            }
            if sourceType == "bluetooth" || sourceType == "bluetooth_le" {
                return state == "home" ? "mdi:bluetooth-connect" : "mdi:bluetooth"
            }
            return state == "not_home" ? "mdi:account-arrow-right" : "mdi:account"
        case Domain.sun.rawValue:
            guard let state else { return nil }
            return state == "above_horizon" ? "mdi:white-balance-sunny" : "mdi:weather-night"
        case Domain.inputDatetime.rawValue:
            if (attributes["has_date"] as? Bool) != true {
                return "mdi:clock"
            }
            if (attributes["has_time"] as? Bool) != true {
                return "mdi:calendar"
            }
            return nil
        default:
            return nil
        }
    }

    private static func updateIsInstalling(_ attributes: [String: Any]) -> Bool {
        if let inProgress = attributes["in_progress"] as? Bool {
            return inProgress
        }
        if let inProgress = attributes["in_progress"] as? NSNumber {
            return inProgress != 0
        }
        return false
    }
}
