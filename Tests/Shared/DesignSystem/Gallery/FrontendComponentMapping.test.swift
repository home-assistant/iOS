import Foundation
@testable import HADesignSystem
import Testing

/// The mapping from each design-system component to the `home-assistant/frontend` element it was
/// ported from. It used to live only in doc comments, where nothing could check it; the
/// ``FrontendComponent`` conformances make it data, and this is what keeps that data honest.
struct FrontendComponentMappingTests {
    /// Components with no frontend counterpart. Each is the companion app's own — its doc comment
    /// says "Frontend counterpart: none" and why.
    ///
    /// Listing them here rather than allowing any `nil` is the point: adding a component without a
    /// mapping fails this test, so a genuinely new port cannot quietly arrive unmapped.
    private static let appNative: Set<DesignSystemComponent> = [
        .card,
        .floatingPanel,
        .fullScreenLoader,
        .pill,
        // The companion app's own Assist orb. The web frontend animates its assist dialog
        // differently and has no equivalent element.
        .assistVoiceOrb,
    ]

    @Test(arguments: DesignSystemComponent.allCases)
    func everyComponentIsEitherMappedOrKnownToBeAppNative(component: DesignSystemComponent) {
        if Self.appNative.contains(component) {
            #expect(
                component.frontendComponentName == nil,
                "\(component.rawValue) is listed as app-native but names a frontend element"
            )
        } else {
            #expect(
                component.frontendComponentName != nil,
                "\(component.rawValue) has no frontend element; add it to `appNative` if it has none"
            )
        }
    }

    /// Element names are tags, not prose. A typo here would be invisible in the gallery and wrong
    /// in the parity audit, which greps for exactly these strings.
    @Test(arguments: DesignSystemComponent.allCases)
    func mappedNamesAreWellFormedTags(component: DesignSystemComponent) {
        guard let name = component.frontendComponentName else {
            return
        }
        #expect(name == name.lowercased(), "\(name) is not lowercase")
        #expect(!name.hasSuffix("-"), "\(name) ends in a separator")
        #expect(
            name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" || $0 == "_" },
            "\(name) contains something other than a tag character"
        )
        // `ha-` and `hui-` are the frontend's two element prefixes; the chart modules under
        // `src/components/chart/` are imported directly and so have neither.
        let isElement = name.hasPrefix("ha-") || name.hasPrefix("hui-")
        let isChartModule = name.hasPrefix("state-history-chart-") || name == "statistics-chart"
        #expect(isElement || isChartModule, "\(name) is neither an ha-/hui- element nor a chart module")
    }

    /// A port is only correct as of some frontend state, so every mapped component records which.
    /// A component that names an element but no date would claim a fidelity nobody can check.
    @Test(arguments: DesignSystemComponent.allCases)
    func everyMappedComponentRecordsWhenItWasLastReconciled(component: DesignSystemComponent) {
        #expect(
            (component.frontendComponentName == nil) == (component.frontendComponentVersion == nil),
            "\(component.rawValue) has one of name/version but not the other"
        )
    }

    /// Dates are compared and sorted, not just displayed, so the format has to hold. An unparseable
    /// or future date would make "is this port stale?" unanswerable in the one place that answers it.
    @Test(arguments: DesignSystemComponent.allCases)
    func reconciliationDatesAreRealAndNotInTheFuture(component: DesignSystemComponent) {
        guard let version = component.frontendComponentVersion else {
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        let date = formatter.date(from: version)
        #expect(date != nil, "\(component.rawValue) has \(version), which is not a yyyy-MM-dd date")
        // A day's slack, because the recording machine and the frontend checkout need not agree on
        // the current date to the hour.
        if let date {
            #expect(
                date < Date().addingTimeInterval(86400),
                "\(component.rawValue) claims to have been reconciled in the future: \(version)"
            )
        }
    }

    /// Several components legitimately share an element — a card and the model it renders, a control
    /// and the maths behind it. What would be a mistake is *every* component sharing one, which is
    /// what a copy-paste error in the table looks like.
    @Test func theMappingCoversManyDistinctElements() {
        let names = Set(DesignSystemComponent.allCases.compactMap(\.frontendComponentName))
        #expect(names.count > 80, "only \(names.count) distinct elements; the table looks collapsed")
    }

    /// The conformance is what the gallery reads, so a type declaring one name while the gallery
    /// shows another is impossible by construction. This pins a few by hand anyway, so that a
    /// wholesale rewrite of the table has to be deliberate.
    @Test func knownComponentsMapToTheirKnownElements() {
        #expect(DesignSystemComponent.tip.frontendComponentName == "ha-tip")
        #expect(DesignSystemComponent.tileCard.frontendComponentName == "hui-tile-card")
        #expect(DesignSystemComponent.analogClock.frontendComponentName == "hui-clock-card-analog")
        #expect(DesignSystemComponent.sparkline.frontendComponentName == "hui-graph-base")
        #expect(DesignSystemComponent.historyChart.frontendComponentName == "state-history-chart-line")
        #expect(HATipView.frontendComponentName == "ha-tip")
    }
}
