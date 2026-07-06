import Foundation
import GRDB
import ObjectMapper
import UIKit
#if os(watchOS)
import ClockKit
#endif

/// An Apple Watch complication configuration persisted in GRDB. Replaces the
/// legacy Realm-backed model. ObjectMapper conformance is kept because the
/// phone syncs complications to the watch as JSON via the watch context, and
/// the wire keys must stay stable across app versions.
public final class WatchComplication: Codable, FetchableRecord, PersistableRecord, ImmutableMappable {
    public static let databaseTableName = GRDBDatabaseTable.watchComplication.rawValue

    public var identifier: String = UUID().uuidString
    public var serverIdentifier: String?

    private var rawFamily: String = ""
    public var Family: ComplicationGroupMember {
        get {
            // Current.Log.verbose("GET Family for str '\(rawFamily)'")
            if let f = ComplicationGroupMember(rawValue: rawFamily) {
                return f
            }
            return ComplicationGroupMember.modularSmall
        }
        set {
            rawFamily = newValue.rawValue
        }
    }

    private var rawTemplate: String = ""
    public var Template: ComplicationTemplate {
        get {
            // Current.Log.verbose("GET Template for str '\(rawTemplate)'")
            if let t = ComplicationTemplate(rawValue: rawTemplate) {
                return t
            }
            return Family.templates.first!
        }
        set {
            rawTemplate = newValue.rawValue
        }
    }

    public var Data: [String: Any] {
        get {
            guard let dictionaryData = complicationData else {
                return [String: Any]()
            }
            do {
                let dict = try JSONSerialization.jsonObject(with: dictionaryData) as? [String: Any]
                return dict!
            } catch {
                return [String: Any]()
            }
        }

        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue)
                complicationData = data
            } catch {
                complicationData = nil
            }
        }
    }

    fileprivate var complicationData: Data?
    public var createdAt = Date()

    public var name: String?
    public var displayName: String {
        name ?? Template.style
    }

    public var isPublic: Bool = true

    enum CodingKeys: String, CodingKey {
        case identifier
        case serverIdentifier
        case rawFamily
        case rawTemplate
        case complicationData
        case createdAt
        case name
        case isPublic
    }

    public init() {}

    /// Used by `RealmToGRDBMigration` to import legacy rows without going
    /// through the (validating) computed accessors.
    init(
        identifier: String,
        serverIdentifier: String?,
        rawFamily: String,
        rawTemplate: String,
        complicationData: Data?,
        createdAt: Date,
        name: String?,
        isPublic: Bool
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.rawFamily = rawFamily
        self.rawTemplate = rawTemplate
        self.complicationData = complicationData
        self.createdAt = createdAt
        self.name = name
        self.isPublic = isPublic
    }

    public init(map: ObjectMapper.Map) throws {
        // this is used for watch<->app syncing
        self.createdAt = try map.value("CreatedAt", using: DateTransform())
        self.Template = try map.value("Template")
        self.Data = try map.value("Data")
        self.Family = try map.value("Family")
        self.identifier = try map.value("identifier")
        self.name = try map.value("name")
        self.isPublic = try map.value("IsPublic")
        self.serverIdentifier = try map.value("serverIdentifier")
    }

    public func mapping(map: ObjectMapper.Map) {
        Template >>> map["Template"]
        Data >>> map["Data"]
        createdAt >>> (map["CreatedAt"], DateTransform())
        Family >>> map["Family"]
        identifier >>> map["identifier"]
        name >>> map["name"]
        isPublic >>> map["IsPublic"]
        serverIdentifier >>> map["serverIdentifier"]
    }

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

    func renderedValues() -> [RenderedValueType: Any] {
        (Data["rendered"] as? [String: Any] ?? [:])
            .compactMapKeys(RenderedValueType.init(stringValue:))
    }

    func updateRawRendered(from response: [String: Any]) {
        Data["rendered"] = response
    }

    func rawRendered() -> [String: String] {
        var renders = [RenderedValueType: String]()

        if let textAreas = Data["textAreas"] as? [String: [String: Any]], textAreas.isEmpty == false {
            let toAdd = textAreas.compactMapValues { $0["text"] as? String }
                .filter { $1.containsJinjaTemplate }
                .mapKeys { RenderedValueType.textArea($0) }
            renders.merge(toAdd, uniquingKeysWith: { a, _ in a })
        }

        if let gaugeDict = Data["gauge"] as? [String: String],
           let gauge = gaugeDict["gauge"], gauge.containsJinjaTemplate {
            renders[.gauge] = gauge
        }

        if let ringDict = Data["ring"] as? [String: String],
           let ringValue = ringDict["ring_value"], ringValue.containsJinjaTemplate {
            renders[.ring] = ringValue
        }

        return renders.mapKeys { $0.stringValue }
    }

    public static func percentileNumber(from value: Any) -> Float? {
        switch value {
        case let value as String:
            // a bit more forgiving than Float(_:)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal

            for locale in [
                // in HA prior to 0.117 (which returns floats), the return type of a float is a string in templates
                // but it's a non-locale-aware string, so we need to parse `0.33` even if the locale expects `0,33`
                Locale(identifier: "en_US_POSIX"),
                // but since it's free-form text, the user may also have typed `0,33` expecting it to work
                Locale.current,
            ] {
                formatter.locale = locale
                if let value = formatter.number(from: value)?.floatValue {
                    return value
                }
            }

            return nil
        case let value as Int:
            return Float(value)
        case let value as Double:
            return Float(value)
        case let value as Float:
            return value
        default:
            Current.Log.info("unsure how to float-ify \(type(of: value)), trying as a string")
            return percentileNumber(from: String(describing: value))
        }
    }

    #if os(watchOS)

    public var complicationDescriptor: CLKComplicationDescriptor {
        CLKComplicationDescriptor(
            identifier: identifier,
            displayName: displayName,
            supportedFamilies: [
                Family.family,
            ]
        )
    }

    public var textDataProviders: [String: CLKTextProvider] {
        var providers = [String: CLKTextProvider]()

        if let textAreas = Data["textAreas"] as? [String: [String: Any]] {
            let rendered = renderedValues()
            for (key, textArea) in textAreas {
                let renderedText = rendered[.textArea(key)].flatMap(String.init(describing:))

                guard let text = renderedText ?? textArea["text"] as? String else {
                    Current.Log.warning("TextArea \(key) doesn't have any text!")
                    continue
                }
                guard let color = textArea["color"] as? String else {
                    Current.Log.warning("TextArea \(key) doesn't have a text color!")
                    continue
                }
                providers[key] = with(CLKSimpleTextProvider(text: text)) {
                    $0.tintColor = UIColor(color)
                }
            }
        }

        return providers
    }

    public var iconProvider: CLKImageProvider? {
        if let iconDict = Data["icon"] as? [String: String], let iconName = iconDict["icon"],
           let iconColor = iconDict["icon_color"], let iconSize = Template.imageSize {
            let iconColor = UIColor(iconColor)
            let icon = MaterialDesignIcons(named: iconName)
            let image = icon.image(ofSize: iconSize, color: iconColor)
            let provider = CLKImageProvider(onePieceImage: image)
            provider.tintColor = iconColor
            return provider
        }

        return nil
    }

    public var fullColorImageProvider: CLKFullColorImageProvider? {
        if let iconDict = Data["icon"] as? [String: String], let iconName = iconDict["icon"],
           let iconColor = iconDict["icon_color"], let iconSize = Template.imageSize {
            let icon = MaterialDesignIcons(named: iconName)
            let image = icon.image(ofSize: iconSize, color: UIColor(iconColor))
            return CLKFullColorImageProvider(fullColorImage: image)
        }

        return nil
    }

    public var gaugeProvider: CLKSimpleGaugeProvider? {
        guard let info = Data["gauge"] as? [String: String] else {
            return nil
        }

        let fraction: Float

        if let renderedFraction = renderedValues()[.gauge], let value = Self.percentileNumber(from: renderedFraction) {
            fraction = value
        } else if let stringFraction = info["gauge"], let value = Self.percentileNumber(from: stringFraction) {
            fraction = value
        } else {
            fraction = 0
        }

        let color: UIColor

        if let string = info["gauge_color"] {
            color = UIColor(string)
        } else {
            color = .red
        }

        let style: CLKGaugeProviderStyle

        if info["gauge_style"]?.lowercased() == "fill" {
            style = .fill
        } else {
            style = .ring
        }

        return CLKSimpleGaugeProvider(
            style: style,
            gaugeColor: color,
            fillFraction: fraction
        )
    }

    public typealias RingData = (fraction: Float, style: CLKComplicationRingStyle, color: UIColor)
    public var ringData: RingData {
        guard let info = Data["ring"] as? [String: String] else {
            return (fraction: 0, style: .closed, color: .red)
        }

        let fraction: Float

        if let renderedFraction = renderedValues()[.ring], let value = Self.percentileNumber(from: renderedFraction) {
            fraction = value
        } else if let stringFraction = info["ring_value"], let value = Self.percentileNumber(from: stringFraction) {
            fraction = value
        } else {
            fraction = 0
        }

        let color: UIColor

        if let string = info["ring_color"] {
            color = UIColor(string)
        } else {
            color = .red
        }

        let style: CLKComplicationRingStyle

        if info["ring_type"]?.lowercased() == "open" {
            style = .open
        } else {
            style = .closed
        }

        return (fraction: fraction, style: style, color: color)
    }

    public var column2Alignment: CLKComplicationColumnAlignment {
        let alignment: CLKComplicationColumnAlignment

        if let info = Data["column2alignment"] as? [String: String], let value = info["column2alignment"] {
            alignment = value.lowercased() == "leading" ? .leading : .trailing
        } else {
            alignment = .leading
        }

        return alignment
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func CLKComplicationTemplate(family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        if Template.groupMember != ComplicationGroupMember(family: family) {
            Current.Log.warning("Would have returned template (\(Template)) outside expected family (\(family)")
            return nil
        }
        switch Template {
        case .CircularSmallRingImage:
            let template = CLKComplicationTemplateCircularSmallRingImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleImage:
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .CircularSmallStackImage:
            let template = CLKComplicationTemplateCircularSmallStackImage()
            if let iconProvider {
                template.line1ImageProvider = iconProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .CircularSmallRingText:
            let template = CLKComplicationTemplateCircularSmallRingText()
            if let textProvider = textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleText:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        case .CircularSmallStackText:
            let template = CLKComplicationTemplateCircularSmallStackText()
            if let textProvider = textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ExtraLargeRingImage:
            let template = CLKComplicationTemplateExtraLargeRingImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleImage:
            let template = CLKComplicationTemplateExtraLargeSimpleImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .ExtraLargeStackImage:
            let template = CLKComplicationTemplateExtraLargeStackImage()
            if let iconProvider {
                template.line1ImageProvider = iconProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ExtraLargeColumnsText:
            let template = CLKComplicationTemplateExtraLargeColumnsText()
            if let textProvider = textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            } else {
                return nil
            }
            template.column2Alignment = column2Alignment
            return template
        case .ExtraLargeRingText:
            let template = CLKComplicationTemplateExtraLargeRingText()
            if let textProvider = textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleText:
            let template = CLKComplicationTemplateExtraLargeSimpleText()
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ExtraLargeStackText:
            let template = CLKComplicationTemplateExtraLargeStackText()
            if let textProvider = textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ModularSmallRingImage:
            let template = CLKComplicationTemplateModularSmallRingImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleImage:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .ModularSmallStackImage:
            let template = CLKComplicationTemplateModularSmallStackImage()
            if let iconProvider {
                template.line1ImageProvider = iconProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ModularSmallColumnsText:
            let template = CLKComplicationTemplateModularSmallColumnsText()
            if let textProvider = textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            } else {
                return nil
            }
            template.column2Alignment = column2Alignment
            return template
        case .ModularSmallRingText:
            let template = CLKComplicationTemplateModularSmallRingText()
            if let textProvider = textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleText:
            let template = CLKComplicationTemplateModularSmallSimpleText()
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ModularSmallStackText:
            let template = CLKComplicationTemplateModularSmallStackText()
            if let textProvider = textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ModularLargeStandardBody:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            if let textProvider = textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            } else {
                // optional, allowed to be nil and makes body1 wrap
            }
            return template
        case .ModularLargeTallBody:
            let template = CLKComplicationTemplateModularLargeTallBody()
            if let textProvider = textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.bodyTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .ModularLargeColumns:
            let template = CLKComplicationTemplateModularLargeColumns()
            if let textProvider = textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            } else {
                return nil
            }
            template.column2Alignment = column2Alignment
            return template
        case .ModularLargeTable:
            let template = CLKComplicationTemplateModularLargeTable()
            if let textProvider = textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            } else {
                return nil
            }
            template.column2Alignment = column2Alignment
            return template
        case .UtilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                // optional
            }
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        case .UtilitarianSmallRingImage:
            let template = CLKComplicationTemplateUtilitarianSmallRingImage()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallRingText:
            let template = CLKComplicationTemplateUtilitarianSmallRingText()
            if let textProvider = textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            let ringData = ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallSquare:
            let template = CLKComplicationTemplateUtilitarianSmallSquare()
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .UtilitarianLargeFlat:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            if let iconProvider {
                template.imageProvider = iconProvider
            } else {
                // optional
            }
            return template
        case .GraphicCornerCircularImage:
            let template = CLKComplicationTemplateGraphicCornerCircularImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .GraphicCornerGaugeImage:
            let template = CLKComplicationTemplateGraphicCornerGaugeImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            } else {
                // optional
            }
            if let textProvider = textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            } else {
                // optional
            }
            return template
        case .GraphicCornerGaugeText:
            let template = CLKComplicationTemplateGraphicCornerGaugeText()
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            } else {
                // optional
            }
            if let textProvider = textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            } else {
                // optional
            }
            return template
        case .GraphicCornerStackText:
            let template = CLKComplicationTemplateGraphicCornerStackText()
            if let textProvider = textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Inner"] {
                template.innerTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicCornerTextImage:
            let template = CLKComplicationTemplateGraphicCornerTextImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularImage:
            let template = CLKComplicationTemplateGraphicCircularImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularClosedGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularOpenGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeImage()
            if let iconProvider = fullColorImageProvider {
                template.bottomImageProvider = iconProvider
            } else {
                return nil
            }
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularClosedGaugeText:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularOpenGaugeSimpleText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Bottom"] {
                template.bottomTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicCircularOpenGaugeRangeText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicBezelCircularText:
            let template = CLKComplicationTemplateGraphicBezelCircularText()
            if let iconProvider = fullColorImageProvider {
                template.circularTemplate = with(CLKComplicationTemplateGraphicCircularImage()) {
                    $0.imageProvider = iconProvider
                }
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Center"] {
                template.textProvider = textProvider
            } else {
                // optional
            }
            return template
        case .GraphicRectangularStandardBody:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            if let textProvider = textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            } else {
                // optional
            }
            return template
        case .GraphicRectangularTextGauge:
            let template = CLKComplicationTemplateGraphicRectangularTextGauge()
            if let gaugeProvider {
                template.gaugeProvider = gaugeProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            } else {
                return nil
            }
            return template
        case .GraphicRectangularLargeImage:
            let template = CLKComplicationTemplateGraphicRectangularLargeImage()
            if let iconProvider = fullColorImageProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            if let textProvider = textDataProviders["Header"] {
                template.textProvider = textProvider
            } else {
                return nil
            }
            return template
        }
    }

    #endif
}

// MARK: - Equatable & Hashable

extension WatchComplication: Equatable, Hashable {
    public static func == (lhs: WatchComplication, rhs: WatchComplication) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

// MARK: - Queries

public extension WatchComplication {
    /// All persisted complications, across all servers.
    static func all() -> [WatchComplication] {
        do {
            return try Current.database().read { db in
                try WatchComplication.fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch watch complications: \(error.localizedDescription)")
            return []
        }
    }

    static func fetch(identifier: String) -> WatchComplication? {
        do {
            return try Current.database().read { db in
                try WatchComplication
                    .filter(Column(DatabaseTables.WatchComplication.identifier.rawValue) == identifier)
                    .fetchOne(db)
            }
        } catch {
            Current.Log.error("Failed to fetch watch complication \(identifier): \(error.localizedDescription)")
            return nil
        }
    }

    static func complications(serverIdentifier: String) -> [WatchComplication] {
        do {
            return try Current.database().read { db in
                try WatchComplication
                    .filter(Column(DatabaseTables.WatchComplication.serverIdentifier.rawValue) == serverIdentifier)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch watch complications: \(error.localizedDescription)")
            return []
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try self.save(db)
            }
        } catch {
            Current.Log.error("Failed to save watch complication \(identifier): \(error.localizedDescription)")
        }
    }

    func delete() {
        do {
            _ = try Current.database().write { db in
                try self.delete(db)
            }
        } catch {
            Current.Log.error("Failed to delete watch complication \(identifier): \(error.localizedDescription)")
        }
    }

    /// Replaces every persisted complication, used when the watch receives the
    /// full set from the paired phone.
    static func replaceAll(with complications: [WatchComplication]) {
        do {
            try Current.database().write { db in
                try WatchComplication.deleteAll(db)
                for complication in complications {
                    try complication.save(db)
                }
            }
        } catch {
            Current.Log.error("Failed to replace watch complications: \(error.localizedDescription)")
        }
    }
}

// MARK: - Table

final class WatchComplicationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.watchComplication.rawValue }

    var definedColumns: [String] { DatabaseTables.WatchComplication.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.WatchComplication.identifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.serverIdentifier.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.rawFamily.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.rawTemplate.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.complicationData.rawValue, .blob)
                    t.column(DatabaseTables.WatchComplication.createdAt.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.WatchComplication.name.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.isPublic.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
