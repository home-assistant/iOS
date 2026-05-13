import Foundation
import PromiseKit
import RealmSwift
import Shared
import SwiftUI
import UIKit

/// Holds the mutable state displayed by `ComplicationEditView`. Decoupled from
/// the view so we can keep the editor readable despite its many inputs.
final class ComplicationEditViewModel: ObservableObject {
    // Mutable editor state
    @Published var name: String
    @Published var isPublic: Bool
    @Published var serverIdentifier: String?
    @Published var displayTemplate: ComplicationTemplate

    @Published var column2Alignment: Column2Alignment

    @Published var gaugeTemplate: String = ""
    @Published var gaugeColor: Color = .green
    @Published var gaugeType: GaugeType = .open
    @Published var gaugeStyle: GaugeStyle = .fill

    @Published var ringTemplate: String = ""
    @Published var ringColor: Color = .green
    @Published var ringType: RingType = .open

    @Published var icon: MaterialDesignIcons = .init(named: "home-assistant")
    @Published var iconColor: Color = .green

    @Published var textAreaValues: [String: TextAreaState] = [:]

    // Readonly
    let config: WatchComplication
    let isNew: Bool

    var family: ComplicationGroupMember { config.Family }

    // MARK: - Init

    // swiftlint:disable:next cyclomatic_complexity
    init(config: WatchComplication, isNew: Bool) {
        self.config = config
        self.isNew = isNew
        self.displayTemplate = config.Template

        self.name = config.name ?? ""
        self.isPublic = config.IsPublic

        if let existing = Current.servers.server(forServerIdentifier: config.serverIdentifier) {
            self.serverIdentifier = existing.identifier.rawValue
        } else {
            self.serverIdentifier = Current.servers.all.first?.identifier.rawValue
        }

        let data = config.Data

        // Column 2 alignment
        if let dict = data["column2alignment"] as? [String: Any],
           let value = dict["column2alignment"] as? String,
           let parsed = Column2Alignment(rawValue: value.lowercased()) {
            self.column2Alignment = parsed
        } else {
            self.column2Alignment = .leading
        }

        // Gauge
        if let dict = data["gauge"] as? [String: Any] {
            self.gaugeTemplate = (dict["gauge"] as? String) ?? ""
            if let hex = dict["gauge_color"] as? String {
                self.gaugeColor = Color(uiColor: UIColor(hex: hex))
            }
            if let value = dict["gauge_type"] as? String,
               let parsed = GaugeType(rawValue: value.lowercased()) {
                self.gaugeType = parsed
            }
            if let value = dict["gauge_style"] as? String,
               let parsed = GaugeStyle(rawValue: value.lowercased()) {
                self.gaugeStyle = parsed
            }
        }

        // Ring
        if let dict = data["ring"] as? [String: Any] {
            self.ringTemplate = (dict["ring_value"] as? String) ?? ""
            if let hex = dict["ring_color"] as? String {
                self.ringColor = Color(uiColor: UIColor(hex: hex))
            }
            if let value = dict["ring_type"] as? String,
               let parsed = RingType(rawValue: value.lowercased()) {
                self.ringType = parsed
            }
        }

        // Icon
        if let dict = data["icon"] as? [String: Any] {
            if let iconName = dict["icon"] as? String {
                self.icon = MaterialDesignIcons(named: iconName)
            }
            if let hex = dict["icon_color"] as? String {
                self.iconColor = Color(uiColor: UIColor(hex: hex))
            }
        }

        // Text areas
        let savedAreas = (data["textAreas"] as? [String: [String: Any]]) ?? [:]
        var map: [String: TextAreaState] = [:]
        for area in ComplicationTextAreas.allCases {
            let raw = savedAreas[area.slug] ?? [:]
            let text = (raw["text"] as? String) ?? ""
            let color: Color
            if let hex = raw["color"] as? String {
                color = Color(uiColor: UIColor(hex: hex))
            } else {
                color = .green
            }
            map[area.slug] = TextAreaState(text: text, color: color)
        }
        self.textAreaValues = map

        adjustGaugeTypeIfForced()
    }

    // MARK: - Derived helpers

    var server: Server? {
        guard let serverIdentifier else { return Current.servers.all.first }
        return Current.servers.server(forServerIdentifier: serverIdentifier) ?? Current.servers.all.first
    }

    var activeTextAreas: [ComplicationTextAreas] { displayTemplate.textAreas }
    var hasGauge: Bool { displayTemplate.hasGauge }
    var hasRing: Bool { displayTemplate.hasRing }
    var hasImage: Bool { displayTemplate.hasImage }
    var supportsColumn2Alignment: Bool { displayTemplate.supportsColumn2Alignment }

    /// Some templates force the gauge type to a specific value (open vs closed).
    /// In that case we still show the control but disable it.
    var isGaugeTypeForced: Bool {
        displayTemplate.gaugeIsOpenStyle || displayTemplate.gaugeIsClosedStyle
    }

    func onDisplayTemplateChange() {
        adjustGaugeTypeIfForced()
    }

    private func adjustGaugeTypeIfForced() {
        guard displayTemplate.hasGauge else { return }
        if displayTemplate.gaugeIsOpenStyle {
            gaugeType = .open
        } else if displayTemplate.gaugeIsClosedStyle {
            gaugeType = .closed
        }
    }

    // MARK: - Save / Delete

    /// Persists to Realm then asks the API to push the change. Returns once
    /// the Realm write is committed; the API update is fired-and-forget like
    /// the original Eureka controller.
    func save() {
        let realm = Current.realm()
        let server = server
        let payload = serializedData()
        let nameValue = name.isEmpty ? nil : name
        let isPublicValue = isPublic
        let template = displayTemplate
        let serverIdentifierValue = server?.identifier.rawValue

        realm.reentrantWrite {
            config.name = nameValue
            config.IsPublic = isPublicValue
            config.serverIdentifier = serverIdentifierValue
            config.Template = template
            config.Data = payload
            realm.add(config, update: .all)
        }.then(on: nil) { () -> Promise<Void> in
            if let server {
                return Current.api(for: server)?
                    .updateComplications(passively: false) ??
                    .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            } else {
                return .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            }
        }.cauterize()
    }

    func delete() {
        let realm = Current.realm()
        let server = server
        realm.reentrantWrite {
            realm.delete(config)
        }.then(on: nil) { () -> Promise<Void> in
            if let server {
                return Current.api(for: server)?
                    .updateComplications(passively: false) ??
                    .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            } else {
                return .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            }
        }.cauterize()
    }

    // MARK: - Serialization

    private func serializedData() -> [String: Any] {
        var result: [String: Any] = [:]

        if supportsColumn2Alignment {
            result["column2alignment"] = ["column2alignment": column2Alignment.rawValue]
        }

        if hasGauge {
            result["gauge"] = [
                "gauge": gaugeTemplate,
                "gauge_color": UIColor(gaugeColor).hexString(true),
                "gauge_type": gaugeType.rawValue,
                "gauge_style": gaugeStyle.rawValue,
            ]
        }

        if hasRing {
            result["ring"] = [
                "ring_value": ringTemplate,
                "ring_color": UIColor(ringColor).hexString(true),
                "ring_type": ringType.rawValue,
            ]
        }

        if hasImage {
            result["icon"] = [
                "icon": icon.name,
                "icon_color": UIColor(iconColor).hexString(true),
            ]
        }

        var textAreas: [String: [String: Any]] = [:]
        for area in activeTextAreas {
            guard let state = textAreaValues[area.slug] else { continue }
            textAreas[area.slug] = [
                "text": state.text,
                "color": UIColor(state.color).hexString(true),
            ]
        }
        result["textAreas"] = textAreas

        return result
    }

    // MARK: - Validation

    /// Returns true when required inputs are filled for the current template.
    var isValid: Bool {
        if hasGauge, gaugeTemplate.isEmpty { return false }
        if hasRing, ringTemplate.isEmpty { return false }
        for area in activeTextAreas where (textAreaValues[area.slug]?.text ?? "").isEmpty {
            return false
        }
        return true
    }

    // MARK: - Template preview validation

    static func validatePercentile(_ value: Any) throws -> String {
        if let number = WatchComplication.percentileNumber(from: value) {
            if !(0 ... 1 ~= number) {
                throw RenderValueError.outOfRange(value: number)
            }
        } else {
            throw RenderValueError.expectedFloat(value: value)
        }
        return String(describing: value)
    }

    static func validateText(_ value: Any) throws -> String {
        String(describing: value)
    }
}

// MARK: - Nested types

extension ComplicationEditViewModel {
    struct TextAreaState: Equatable {
        var text: String
        var color: Color
    }

    enum Column2Alignment: String, CaseIterable, Identifiable {
        case leading
        case trailing

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .leading: return L10n.Watch.Configurator.Rows.Column2Alignment.Options.leading
            case .trailing: return L10n.Watch.Configurator.Rows.Column2Alignment.Options.trailing
            }
        }
    }

    enum GaugeType: String, CaseIterable, Identifiable {
        case open
        case closed

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .open: return L10n.Watch.Configurator.Rows.Gauge.GaugeType.Options.open
            case .closed: return L10n.Watch.Configurator.Rows.Gauge.GaugeType.Options.closed
            }
        }
    }

    enum GaugeStyle: String, CaseIterable, Identifiable {
        case fill
        case ring

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .fill: return L10n.Watch.Configurator.Rows.Gauge.Style.Options.fill
            case .ring: return L10n.Watch.Configurator.Rows.Gauge.Style.Options.ring
            }
        }
    }

    enum RingType: String, CaseIterable, Identifiable {
        case open
        case closed

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .open: return L10n.Watch.Configurator.Rows.Ring.RingType.Options.open
            case .closed: return L10n.Watch.Configurator.Rows.Ring.RingType.Options.closed
            }
        }
    }

    enum RenderValueError: LocalizedError {
        case expectedFloat(value: Any)
        case outOfRange(value: Float)

        var errorDescription: String? {
            switch self {
            case let .expectedFloat(value):
                var displayType = String(describing: type(of: value))
                if displayType.lowercased().contains("string") {
                    displayType = "string"
                }
                return L10n.Watch.Configurator.PreviewError.notNumber(displayType, value)
            case let .outOfRange(value):
                return L10n.Watch.Configurator.PreviewError.outOfRange(value)
            }
        }
    }
}
