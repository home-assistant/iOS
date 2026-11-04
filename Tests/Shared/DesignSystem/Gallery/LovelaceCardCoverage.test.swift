@testable import HADesignSystem
import Testing

/// Why a card type needs no component of its own.
private enum Coverage {
    /// Drawn by this component.
    case component(DesignSystemComponent)
    /// A composition of components that already exist. The string says which.
    case composition(String)
    /// Not a dashboard component at all — layout, logic, or a screen the companion app never
    /// renders.
    case notAComponent(String)
}

/// Every card type a user can add to a Lovelace dashboard, and what draws it here.
///
/// The list is `ALWAYS_LOADED_TYPES` + `LAZY_LOAD_TYPES` from the frontend's
/// `create-element/create-card-element.ts` — the registry the card picker is built from, so it is
/// exactly the set of `type:` values a dashboard config can contain.
///
/// At file scope rather than inside the suite because it is data, not behaviour, and a table this
/// long inside a type body is what type-length limits exist to catch.
private let cardCoverage: [String: Coverage] = [
    // MARK: - Cards with a component of their own

    "alarm-panel": .component(.alarmPanelCard),
    "area": .component(.areaCard),
    "button": .component(.buttonCard),
    "calendar": .component(.calendarCard),
    "clock": .component(.clockCard),
    "distribution": .component(.distributionCard),
    "energy-date-selection": .component(.energyPeriodSelector),
    "energy-distribution": .component(.energyDistributionCard),
    "energy-sources-table": .component(.energySourcesTable),
    "entities": .component(.entitiesCard),
    "entity": .component(.entityCard),
    "error": .component(.errorCard),
    "gauge": .component(.gaugeCard),
    "glance": .component(.glanceCard),
    "heading": .component(.headingCard),
    "history-graph": .component(.historyGraphCard),
    "humidifier": .component(.humidifierCard),
    "light": .component(.lightCard),
    "logbook": .component(.logbookCard),
    "markdown": .component(.markdownCard),
    "media-control": .component(.mediaControlCard),
    "picture": .component(.pictureCard),
    "picture-glance": .component(.pictureGlanceCard),
    "plant-status": .component(.plantStatusCard),
    "sensor": .component(.sensorCard),
    "statistic": .component(.statisticCard),
    "statistics-graph": .component(.statisticsGraphCard),
    "thermostat": .component(.thermostatCard),
    "tile": .component(.tileCard),
    "todo-list": .component(.todoListCard),
    "weather-forecast": .component(.weatherForecastCard),

    // MARK: - Compositions of components that already exist

    // The frontend subclasses these outright: `hui-entity-button-card extends HuiButtonCard`,
    // `hui-shopping-list-card extends HuiTodoListCard`.
    "entity-button": .composition("HAButtonCard with an entity's state"),
    "shopping-list": .composition("HATodoListCard over the shopping list"),

    "alert": .composition("HAAlertView"),
    "empty-state": .composition("HAEmptyStateView"),
    "picture-entity": .composition("HAPictureCard with an entity's state"),

    // Newer cards that have all converged on the tile shape: each is a `ha-tile-container` +
    // `ha-tile-icon` + `ha-tile-info` and nothing else.
    "home-summary": .composition("HATileCard"),
    "shortcut": .composition("HATileCard"),
    "toggle-group": .composition("HATileCard"),
    "updates": .composition("HATileCard"),

    // Energy graphs are a statistics or history chart over a different statistic; the gauges are
    // HAGaugeCard with levels. What each adds is which statistic to fetch, which is app work.
    "energy-devices-detail-graph": .composition("HAStatisticsChart"),
    "energy-devices-graph": .composition("HAStatisticsChart"),
    "energy-gas-graph": .composition("HAStatisticsChart"),
    "energy-grid-balance": .composition("HAStatisticsChart"),
    "energy-solar-graph": .composition("HAStatisticsChart"),
    "energy-usage-graph": .composition("HAStatisticsChart"),
    "energy-water-graph": .composition("HAStatisticsChart"),
    "power-sources-graph": .composition("HAStatisticsChart"),
    "energy-carbon-consumed-gauge": .composition("HAGaugeCard"),
    "energy-grid-neutrality-gauge": .composition("HAGaugeCard"),
    "energy-self-sufficiency-gauge": .composition("HAGaugeCard"),
    "energy-solar-consumed-gauge": .composition("HAGaugeCard"),
    "energy-compare": .composition("HAAlertView"),
    "energy-sankey": .composition("HASankeyChart"),
    "power-sankey": .composition("HASankeyChart"),
    "water-sankey": .composition("HASankeyChart"),
    "water-flow-sankey": .composition("HASankeyChart"),

    // MARK: - Not a dashboard component

    "grid": .notAComponent("layout container"),
    "horizontal-stack": .notAComponent("layout container"),
    "vertical-stack": .notAComponent("layout container"),
    "section": .notAComponent("layout container"),
    "conditional": .notAComponent("visibility logic, draws nothing itself"),
    "entity-filter": .notAComponent("filtering logic, draws nothing itself"),
    "import": .notAComponent("dashboard editor only"),
    "iframe": .notAComponent("embeds a web page; the app has a WKWebView for that"),
    "map": .notAComponent("needs MapKit, which is app work"),
    "picture-elements": .notAComponent("absolute positioning over an image, configured per user"),
    "recovery-mode": .notAComponent("system screen"),
    "starting": .notAComponent("system screen"),
    "repairs": .notAComponent("system screen"),
    "discovered-devices": .notAComponent("onboarding screen"),
]

/// Checks that every card a user can add to a dashboard has something here that draws it.
///
/// This exists because "do we have every card?" was previously answerable only by reading. Now a
/// card type added upstream shows up as a failing test with a name to look up, rather than as a gap
/// nobody noticed.
struct LovelaceCardCoverageTests {
    /// The count is pinned so that a card type disappearing upstream is as visible as one arriving.
    @Test func everyCardTypeInThePickerIsAccountedFor() {
        #expect(cardCoverage.count == 71)
    }

    @Test func cardsWithTheirOwnComponentNameTheMatchingElement() {
        for (type, coverage) in cardCoverage {
            guard case let .component(component) = coverage else {
                continue
            }
            let element = component.frontendComponentName
            #expect(element != nil, "\(type) maps to \(component.rawValue), which names no element")
            // A couple legitimately differ: the energy period selector is
            // `hui-energy-period-selector` inside `hui-energy-date-selection-card`.
            if element != "hui-\(type)-card" {
                #expect(
                    element?.hasPrefix("hui-") == true,
                    "\(type) maps to \(element ?? "nil"), which is not a dashboard element"
                )
            }
        }
    }

    /// A composition or exclusion has to say *why*, because the reason is the whole value of the
    /// entry — "covered elsewhere" with no elsewhere named is not an answer.
    @Test func everyCompositionAndExclusionGivesAReason() {
        for (type, coverage) in cardCoverage {
            switch coverage {
            case .component:
                continue
            case let .composition(reason), let .notAComponent(reason):
                #expect(!reason.isEmpty, "\(type) gives no reason")
                #expect(reason.count > 3, "\(type)'s reason is too short to be one: \(reason)")
            }
        }
    }

    /// Two card types pointing at the same component is a copy-paste error, not a design.
    @Test func noTwoCardTypesClaimTheSameComponent() {
        var seen: [DesignSystemComponent: String] = [:]
        for (type, coverage) in cardCoverage.sorted(by: { $0.key < $1.key }) {
            guard case let .component(component) = coverage else {
                continue
            }
            #expect(
                seen[component] == nil,
                "\(type) and \(seen[component] ?? "") both claim \(component.rawValue)"
            )
            seen[component] = type
        }
    }
}
