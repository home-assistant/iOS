import Foundation
import GRDB

/// AppWatchComplication represents a complication stored in the watch's GRDB database
/// It stores the complete JSON data from the iPhone and handles all template generation
///
/// This struct is fully self-contained and does not depend on Realm for any functionality.
/// All ClockKit template generation is performed directly from the stored GRDB data.
public struct AppWatchComplication: Codable {
    public var identifier: String
    public var serverIdentifier: String?
    public var rawFamily: String
    public var rawTemplate: String
    public var complicationData: [String: Any]
    public var createdAt: Date
    public var name: String?

    enum CodingKeys: String, CodingKey {
        case identifier
        case serverIdentifier
        case rawFamily
        case rawTemplate
        case complicationData
        case createdAt
        case name
    }

    public init(
        identifier: String,
        serverIdentifier: String?,
        rawFamily: String,
        rawTemplate: String,
        complicationData: [String: Any],
        createdAt: Date,
        name: String?
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.rawFamily = rawFamily
        self.rawTemplate = rawTemplate
        self.complicationData = complicationData
        self.createdAt = createdAt
        self.name = name
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.serverIdentifier = try container.decodeIfPresent(String.self, forKey: .serverIdentifier)
        self.rawFamily = try container.decode(String.self, forKey: .rawFamily)
        self.rawTemplate = try container.decode(String.self, forKey: .rawTemplate)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)

        // Decode JSON string to dictionary
        let jsonString = try container.decode(String.self, forKey: .complicationData)
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.complicationData = json
        } else {
            self.complicationData = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeIfPresent(serverIdentifier, forKey: .serverIdentifier)
        try container.encode(rawFamily, forKey: .rawFamily)
        try container.encode(rawTemplate, forKey: .rawTemplate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(name, forKey: .name)

        // Encode dictionary to JSON string for database storage
        let data = try JSONSerialization.data(withJSONObject: complicationData, options: [])
        if let jsonString = String(data: data, encoding: .utf8) {
            try container.encode(jsonString, forKey: .complicationData)
        }
    }
}

// MARK: - GRDB Conformance

extension AppWatchComplication: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String {
        GRDBDatabaseTable.appWatchComplication.rawValue
    }
}

// MARK: - Convenience Methods

public extension AppWatchComplication {
    /// Creates an AppWatchComplication from JSON data received from iPhone
    static func from(jsonData: Data) throws -> AppWatchComplication {
        guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw NSError(
                domain: "AppWatchComplication",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to deserialize JSON data"]
            )
        }

        guard let identifier = json["identifier"] as? String else {
            throw NSError(
                domain: "AppWatchComplication",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing identifier in JSON"]
            )
        }

        let serverIdentifier = json["serverIdentifier"] as? String
        let rawFamily = json["Family"] as? String ?? ""
        let rawTemplate = json["Template"] as? String ?? ""
        let name = json["name"] as? String
        let complicationData = json["Data"] as? [String: Any] ?? [:]

        // Parse CreatedAt date
        let createdAt: Date
        if let timestamp = json["CreatedAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = json["CreatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }

        return AppWatchComplication(
            identifier: identifier,
            serverIdentifier: serverIdentifier,
            rawFamily: rawFamily,
            rawTemplate: rawTemplate,
            complicationData: complicationData,
            createdAt: createdAt,
            name: name
        )
    }

    /// Fetches all complications from the database
    static func fetchAll(from database: Database) throws -> [AppWatchComplication] {
        try AppWatchComplication.fetchAll(database)
    }

    /// Fetches a specific complication by identifier
    static func fetch(identifier: String, from database: Database) throws -> AppWatchComplication? {
        try AppWatchComplication
            .filter(Column(DatabaseTables.AppWatchComplication.identifier.rawValue) == identifier)
            .fetchOne(database)
    }

    /// Deletes all complications from the database
    static func deleteAll(from database: Database) throws {
        try AppWatchComplication.deleteAll(database)
    }
}

// MARK: - watchOS Complication Support

#if os(watchOS)
import ClockKit
import UIKit

public extension AppWatchComplication {
    /// Display name for the complication
    var displayName: String {
        name ?? template.style
    }

    /// Whether the complication should be shown on lock screen
    /// Default to true since we don't store this yet
    var isPublic: Bool {
        // TODO: Add isPublic field to database schema if needed
        true
    }

    /// The Family enum from rawFamily string
    var family: ComplicationGroupMember {
        ComplicationGroupMember(rawValue: rawFamily) ?? .modularSmall
    }

    /// The Template enum from rawTemplate string
    var template: ComplicationTemplate {
        ComplicationTemplate(rawValue: rawTemplate) ?? family.templates.first!
    }

    // MARK: - Rendered Values Support

    /// Enum representing different types of renderable values in a complication
    enum RenderedValueType: Hashable {
        case textArea(String)
        case gauge
        case ring

        init?(stringValue: String) {
            let values = stringValue.components(separatedBy: ",")

            guard values.count >= 1 else {
                return nil
            }

            switch values[0] {
            case "textArea" where values.count >= 2:
                self = .textArea(values[1])
            case "gauge":
                self = .gauge
            case "ring":
                self = .ring
            default:
                return nil
            }
        }

        var stringValue: String {
            switch self {
            case let .textArea(value): return "textArea,\(value)"
            case .gauge: return "gauge"
            case .ring: return "ring"
            }
        }
    }

    /// Returns the rendered values dictionary from server template rendering
    func renderedValues() -> [RenderedValueType: Any] {
        (complicationData["rendered"] as? [String: Any] ?? [:])
            .compactMapKeys(RenderedValueType.init(stringValue:))
    }

    /// Updates the rendered values with response from server
    /// - Parameter response: Dictionary of rendered template values from webhook
    mutating func updateRenderedValues(from response: [String: Any]) {
        complicationData["rendered"] = response
    }

    /// Returns the raw unrendered template strings that need server-side rendering
    /// Used by webhook system to request template rendering from Home Assistant
    func rawRendered() -> [String: String] {
        var renders = [RenderedValueType: String]()

        if let textAreas = complicationData["textAreas"] as? [String: [String: Any]], textAreas.isEmpty == false {
            let toAdd = textAreas.compactMapValues { $0["text"] as? String }
                .filter { $1.containsJinjaTemplate } // Note: Requires String extension from Shared module
                .mapKeys { RenderedValueType.textArea($0) }
            renders.merge(toAdd, uniquingKeysWith: { a, _ in a })
        }

        if let gaugeDict = complicationData["gauge"] as? [String: String],
           let gauge = gaugeDict["gauge"], gauge.containsJinjaTemplate {
            renders[.gauge] = gauge
        }

        if let ringDict = complicationData["ring"] as? [String: String],
           let ringValue = ringDict["ring_value"], ringValue.containsJinjaTemplate {
            renders[.ring] = ringValue
        }

        return renders.mapKeys { $0.stringValue }
    }

    /// Complication descriptor for ClockKit
    var complicationDescriptor: CLKComplicationDescriptor {
        CLKComplicationDescriptor(
            identifier: identifier,
            displayName: displayName,
            supportedFamilies: [family.family]
        )
    }

    /// Generate CLKComplicationTemplate for display
    /// This generates the template directly from GRDB data without using Realm
    func clkComplicationTemplate(family complicationFamily: CLKComplicationFamily) -> CLKComplicationTemplate? {
        // Create the template based on the stored template type and family
        let templateGenerator = ComplicationTemplateGenerator(
            family: complicationFamily,
            rawTemplate: rawTemplate,
            data: complicationData,
            renderedValues: renderedValues()
        )

        return templateGenerator.generate()
    }
}

// MARK: - Template Generation

/// Handles generation of CLKComplicationTemplates from stored data
private struct ComplicationTemplateGenerator {
    let family: CLKComplicationFamily
    let rawTemplate: String
    let data: [String: Any]
    let renderedValues: [AppWatchComplication.RenderedValueType: Any]

    func generate() -> CLKComplicationTemplate? {
        // Generate template based on family
        switch family {
        case .graphicRectangular:
            return generateGraphicRectangular()
        case .graphicCircular:
            return generateGraphicCircular()
        case .graphicCorner:
            return generateGraphicCorner()
        case .graphicBezel:
            return generateGraphicBezel()
        case .modularSmall:
            return generateModularSmall()
        case .modularLarge:
            return generateModularLarge()
        case .utilitarianSmall, .utilitarianSmallFlat:
            return generateUtilitarianSmall()
        case .utilitarianLarge:
            return generateUtilitarianLarge()
        case .circularSmall:
            return generateCircularSmall()
        case .extraLarge:
            return generateExtraLarge()
        case .graphicExtraLarge:
            return generateGraphicExtraLarge()
        @unknown default:
            return nil
        }
    }

    // MARK: - Graphic Templates

    private func generateGraphicRectangular() -> CLKComplicationTemplate {
        // Use string matching instead of enum cases
        if rawTemplate.contains("TextGauge") {
            return generateGraphicRectangularTextGauge()
        } else if rawTemplate.contains("LargeImage") {
            return generateGraphicRectangularLargeImage()
        } else {
            return generateGraphicRectangularStandardBody()
        }
    }

    private func generateGraphicCircular() -> CLKComplicationTemplate {
        if rawTemplate.contains("OpenGauge") {
            return generateGraphicCircularOpenGaugeImage()
        } else if rawTemplate.contains("ClosedGauge") {
            return generateGraphicCircularClosedGaugeImage()
        } else {
            return generateGraphicCircularImage()
        }
    }

    private func generateGraphicCorner() -> CLKComplicationTemplate {
        if rawTemplate.contains("GaugeImage") {
            return generateGraphicCornerGaugeImage()
        } else if rawTemplate.contains("CircularImage") {
            return generateGraphicCornerCircularImage()
        } else {
            return generateGraphicCornerTextImage()
        }
    }

    private func generateGraphicBezel() -> CLKComplicationTemplate {
        // Graphic bezel wraps a circular template
        let circularTemplate = generateGraphicCircular()

        guard let circularGraphicTemplate = circularTemplate as? CLKComplicationTemplateGraphicCircular else {
            // Fallback: create a simple circular template
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .white, fillFraction: 0.5)
            let centerTextProvider = CLKSimpleTextProvider(text: "HA")
            let fallbackCircular = CLKComplicationTemplateGraphicCircularClosedGaugeText(
                gaugeProvider: gaugeProvider,
                centerTextProvider: centerTextProvider
            )
            let textProvider = self.textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Home Assistant")
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: fallbackCircular,
                textProvider: textProvider
            )
        }

        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Home Assistant")

        return CLKComplicationTemplateGraphicBezelCircularText(
            circularTemplate: circularGraphicTemplate,
            textProvider: textProvider
        )
    }

    // MARK: - Modular Templates

    private func generateModularSmall() -> CLKComplicationTemplate {
        if rawTemplate.contains("SimpleText") {
            return generateModularSmallSimpleText()
        } else if rawTemplate.contains("RingImage") {
            return generateModularSmallRingImage()
        } else if rawTemplate.contains("StackImage") {
            return generateModularSmallStackImage()
        } else {
            return generateModularSmallSimpleImage()
        }
    }

    private func generateModularLarge() -> CLKComplicationTemplate {
        if rawTemplate.contains("TallBody") {
            return generateModularLargeTallBody()
        } else if rawTemplate.contains("Table") {
            return generateModularLargeTable()
        } else {
            return generateModularLargeStandardBody()
        }
    }

    // MARK: - Utilitarian Templates

    private func generateUtilitarianSmall() -> CLKComplicationTemplate {
        let imageProvider = imageProvider(for: "icon")
        let textProvider = textProvider(for: "line1")

        if let imageProvider {
            return CLKComplicationTemplateUtilitarianSmallSquare(imageProvider: imageProvider)
        } else if let textProvider {
            return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: textProvider)
        }

        return CLKComplicationTemplateUtilitarianSmallFlat(
            textProvider: CLKSimpleTextProvider(text: "HA")
        )
    }

    private func generateUtilitarianLarge() -> CLKComplicationTemplate {
        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Home Assistant")
        return CLKComplicationTemplateUtilitarianLargeFlat(textProvider: textProvider)
    }

    // MARK: - Circular Templates

    private func generateCircularSmall() -> CLKComplicationTemplate {
        if let imageProvider = imageProvider(for: "icon") {
            return CLKComplicationTemplateCircularSmallSimpleImage(imageProvider: imageProvider)
        }

        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "HA")
        return CLKComplicationTemplateCircularSmallSimpleText(textProvider: textProvider)
    }

    private func generateExtraLarge() -> CLKComplicationTemplate {
        if let imageProvider = imageProvider(for: "icon") {
            return CLKComplicationTemplateExtraLargeSimpleImage(imageProvider: imageProvider)
        }

        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "HA")
        return CLKComplicationTemplateExtraLargeSimpleText(textProvider: textProvider)
    }

    private func generateGraphicExtraLarge() -> CLKComplicationTemplate {
        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicExtraLargeCircularImage(imageProvider: imageProvider)
        }

        let textProvider = textProvider(for: "center") ?? CLKSimpleTextProvider(text: "HA")
        return CLKComplicationTemplateGraphicExtraLargeCircularStackText(
            line1TextProvider: textProvider,
            line2TextProvider: self.textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "")
        )
    }

    // MARK: - Specific Template Implementations

    private func generateGraphicRectangularStandardBody() -> CLKComplicationTemplate {
        let headerTextProvider = textProvider(for: "header") ?? CLKSimpleTextProvider(text: "Home Assistant")
        let body1TextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Ready")

        return CLKComplicationTemplateGraphicRectangularStandardBody(
            headerTextProvider: headerTextProvider,
            body1TextProvider: body1TextProvider
        )
    }

    private func generateGraphicRectangularTextGauge() -> CLKComplicationTemplate {
        let headerTextProvider = textProvider(for: "header") ?? CLKSimpleTextProvider(text: "Home Assistant")
        let body1TextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Status")
        let gaugeProvider = gaugeProvider() ?? CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: .white,
            fillFraction: 0.5
        )

        return CLKComplicationTemplateGraphicRectangularTextGauge(
            headerTextProvider: headerTextProvider,
            body1TextProvider: body1TextProvider,
            gaugeProvider: gaugeProvider
        )
    }

    private func generateGraphicRectangularLargeImage() -> CLKComplicationTemplate {
        if let imageProvider = fullColorImageProvider(for: "image") {
            // GraphicRectangularLargeImage requires non-optional textProvider
            let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "")
            return CLKComplicationTemplateGraphicRectangularLargeImage(
                textProvider: textProvider,
                imageProvider: imageProvider
            )
        }

        // Fallback to standard body if no image
        return generateGraphicRectangularStandardBody()
    }

    private func generateGraphicCircularImage() -> CLKComplicationTemplate {
        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCircularImage(imageProvider: imageProvider)
        }

        // Fallback: create a simple closed gauge with text
        let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .white, fillFraction: 0.5)
        let centerTextProvider = CLKSimpleTextProvider(text: "HA")
        return CLKComplicationTemplateGraphicCircularClosedGaugeText(
            gaugeProvider: gaugeProvider,
            centerTextProvider: centerTextProvider
        )
    }

    private func generateGraphicCircularOpenGaugeImage() -> CLKComplicationTemplate {
        let gaugeProvider = gaugeProvider() ?? CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: .white,
            fillFraction: 0.5
        )

        let bottomTextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "50%")
        let centerTextProvider = textProvider(for: "center") ?? CLKSimpleTextProvider(text: "")

        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCircularOpenGaugeImage(
                gaugeProvider: gaugeProvider,
                bottomImageProvider: imageProvider,
                centerTextProvider: centerTextProvider
            )
        }

        return CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(
            gaugeProvider: gaugeProvider,
            bottomTextProvider: bottomTextProvider,
            centerTextProvider: centerTextProvider
        )
    }

    private func generateGraphicCircularClosedGaugeImage() -> CLKComplicationTemplate {
        let gaugeProvider = gaugeProvider() ?? CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: .white,
            fillFraction: 0.5
        )

        let centerTextProvider = textProvider(for: "center") ?? CLKSimpleTextProvider(text: "50%")

        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCircularClosedGaugeImage(
                gaugeProvider: gaugeProvider,
                imageProvider: imageProvider
            )
        }

        return CLKComplicationTemplateGraphicCircularClosedGaugeText(
            gaugeProvider: gaugeProvider,
            centerTextProvider: centerTextProvider
        )
    }

    private func generateGraphicCornerGaugeImage() -> CLKComplicationTemplate {
        let gaugeProvider = gaugeProvider() ?? CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: .white,
            fillFraction: 0.5
        )

        let outerTextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "HA")

        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCornerGaugeImage(
                gaugeProvider: gaugeProvider,
                leadingTextProvider: nil,
                trailingTextProvider: nil,
                imageProvider: imageProvider
            )
        }

        return CLKComplicationTemplateGraphicCornerGaugeText(
            gaugeProvider: gaugeProvider,
            leadingTextProvider: nil,
            trailingTextProvider: nil,
            outerTextProvider: outerTextProvider
        )
    }

    private func generateGraphicCornerTextImage() -> CLKComplicationTemplate {
        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Home")

        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: textProvider,
                imageProvider: imageProvider
            )
        }

        // Fallback to text-only corner template
        return CLKComplicationTemplateGraphicCornerStackText(
            innerTextProvider: textProvider,
            outerTextProvider: CLKSimpleTextProvider(text: "HA")
        )
    }

    private func generateGraphicCornerCircularImage() -> CLKComplicationTemplate {
        if let imageProvider = fullColorImageProvider(for: "icon") {
            return CLKComplicationTemplateGraphicCornerCircularImage(imageProvider: imageProvider)
        }

        // Fallback to text image
        return generateGraphicCornerTextImage()
    }

    private func generateModularSmallSimpleImage() -> CLKComplicationTemplate {
        if let imageProvider = imageProvider(for: "icon") {
            return CLKComplicationTemplateModularSmallSimpleImage(imageProvider: imageProvider)
        }

        // Fallback to text
        return generateModularSmallSimpleText()
    }

    private func generateModularSmallSimpleText() -> CLKComplicationTemplate {
        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "HA")
        return CLKComplicationTemplateModularSmallSimpleText(textProvider: textProvider)
    }

    private func generateModularSmallRingImage() -> CLKComplicationTemplate {
        let fillFraction = ringFillFraction()
        let ringStyle: CLKComplicationRingStyle = fillFraction > 0 ? .closed : .open

        if let imageProvider = imageProvider(for: "icon") {
            return CLKComplicationTemplateModularSmallRingImage(
                imageProvider: imageProvider,
                fillFraction: fillFraction,
                ringStyle: ringStyle
            )
        }

        // Fallback to ring text
        let textProvider = CLKSimpleTextProvider(text: String(format: "%.0f%%", fillFraction * 100))
        return CLKComplicationTemplateModularSmallRingText(
            textProvider: textProvider,
            fillFraction: fillFraction,
            ringStyle: ringStyle
        )
    }

    private func generateModularSmallStackImage() -> CLKComplicationTemplate {
        let textProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "HA")

        if let imageProvider = imageProvider(for: "icon") {
            return CLKComplicationTemplateModularSmallStackImage(
                line1ImageProvider: imageProvider,
                line2TextProvider: textProvider
            )
        }

        // Fallback to stack text
        return CLKComplicationTemplateModularSmallStackText(
            line1TextProvider: CLKSimpleTextProvider(text: "HA"),
            line2TextProvider: textProvider
        )
    }

    private func generateModularLargeStandardBody() -> CLKComplicationTemplate {
        let headerTextProvider = textProvider(for: "header") ?? CLKSimpleTextProvider(text: "Home Assistant")
        let body1TextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Ready")

        let body2TextProvider = textProvider(for: "line2")

        if let imageProvider = imageProvider(for: "icon"), let body2 = body2TextProvider {
            return CLKComplicationTemplateModularLargeStandardBody(
                headerImageProvider: imageProvider,
                headerTextProvider: headerTextProvider,
                body1TextProvider: body1TextProvider,
                body2TextProvider: body2
            )
        }

        return CLKComplicationTemplateModularLargeStandardBody(
            headerTextProvider: headerTextProvider,
            body1TextProvider: body1TextProvider
        )
    }

    private func generateModularLargeTallBody() -> CLKComplicationTemplate {
        let headerTextProvider = textProvider(for: "header") ?? CLKSimpleTextProvider(text: "Home Assistant")
        let bodyTextProvider = textProvider(for: "line1") ?? CLKSimpleTextProvider(text: "Status: Ready")

        return CLKComplicationTemplateModularLargeTallBody(
            headerTextProvider: headerTextProvider,
            bodyTextProvider: bodyTextProvider
        )
    }

    private func generateModularLargeTable() -> CLKComplicationTemplate {
        let headerTextProvider = textProvider(for: "header") ?? CLKSimpleTextProvider(text: "Home Assistant")
        let row1Column1TextProvider = textProvider(for: "row1col1") ?? CLKSimpleTextProvider(text: "Status")
        let row1Column2TextProvider = textProvider(for: "row1col2") ?? CLKSimpleTextProvider(text: "Ready")
        let row2Column1TextProvider = textProvider(for: "row2col1") ?? CLKSimpleTextProvider(text: "")
        let row2Column2TextProvider = textProvider(for: "row2col2") ?? CLKSimpleTextProvider(text: "")

        return CLKComplicationTemplateModularLargeTable(
            headerTextProvider: headerTextProvider,
            row1Column1TextProvider: row1Column1TextProvider,
            row1Column2TextProvider: row1Column2TextProvider,
            row2Column1TextProvider: row2Column1TextProvider,
            row2Column2TextProvider: row2Column2TextProvider
        )
    }

    // MARK: - Helper Methods

    /// Extract text provider for a given key
    private func textProvider(for key: String) -> CLKTextProvider? {
        // Check rendered values first
        let renderedKey = AppWatchComplication.RenderedValueType.textArea(key)
        if let renderedText = renderedValues[renderedKey] as? String {
            return CLKSimpleTextProvider(text: renderedText)
        }

        // Fall back to text areas in data
        if let textAreas = data["textAreas"] as? [String: [String: Any]],
           let textArea = textAreas[key],
           let text = textArea["text"] as? String {
            return CLKSimpleTextProvider(text: text)
        }

        // Check direct key
        if let text = data[key] as? String {
            return CLKSimpleTextProvider(text: text)
        }

        return nil
    }

    /// Extract image provider for a given key
    private func imageProvider(for key: String) -> CLKImageProvider? {
        guard let icon = data[key] as? [String: Any],
              let iconName = icon["icon"] as? String else {
            return nil
        }

        // Create MaterialDesignIcons icon
        // MaterialDesignIcons initializer doesn't return optional, it returns the icon or uses a fallback
        let mdiIcon = MaterialDesignIcons(named: iconName)

        // Generate image from icon
        let image = mdiIcon.image(ofSize: CGSize(width: 32, height: 32), color: .white)
        return CLKImageProvider(onePieceImage: image)
    }

    /// Extract full color image provider for a given key
    private func fullColorImageProvider(for key: String) -> CLKFullColorImageProvider? {
        guard let icon = data[key] as? [String: Any],
              let iconName = icon["icon"] as? String else {
            return nil
        }

        // Create MaterialDesignIcons icon
        // MaterialDesignIcons initializer doesn't return optional, it returns the icon or uses a fallback
        let mdiIcon = MaterialDesignIcons(named: iconName)

        // Get color if specified, otherwise use white
        let color: UIColor
        if let colorHex = icon["color"] as? String {
            color = UIColor(hex: colorHex) ?? .white
        } else {
            color = .white
        }

        // Generate full-color image from icon
        let image = mdiIcon.image(ofSize: CGSize(width: 48, height: 48), color: color)
        return CLKFullColorImageProvider(fullColorImage: image)
    }

    /// Extract gauge provider
    private func gaugeProvider() -> CLKGaugeProvider? {
        // Check rendered gauge value
        if let gaugeValue = renderedValues[.gauge] as? Double {
            return CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: gaugeColor(),
                fillFraction: Float(max(0, min(1, gaugeValue)))
            )
        }

        // Check data
        if let gaugeDict = data["gauge"] as? [String: Any],
           let gaugeValue = gaugeDict["gauge"] as? Double {
            return CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: gaugeColor(),
                fillFraction: Float(max(0, min(1, gaugeValue)))
            )
        }

        return nil
    }

    /// Extract gauge color
    private func gaugeColor() -> UIColor {
        if let gaugeDict = data["gauge"] as? [String: Any],
           let colorHex = gaugeDict["gauge_color"] as? String {
            return UIColor(hex: colorHex) ?? .white
        }
        return .white
    }

    /// Extract ring fill fraction
    private func ringFillFraction() -> Float {
        // Check rendered ring value
        if let ringValue = renderedValues[.ring] as? Double {
            return Float(max(0, min(1, ringValue)))
        }

        // Check data
        if let ringDict = data["ring"] as? [String: Any],
           let ringValue = ringDict["ring_value"] as? Double {
            return Float(max(0, min(1, ringValue)))
        }

        return 0.5
    }
}

// MARK: - UIColor Hex Extension

private extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let r, g, b, a: CGFloat

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF00_0000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF_0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000_FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x0000_00FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Dictionary Helpers

fileprivate extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result = [T: Value]()
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }

    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result = [T: Value]()
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}
#endif
