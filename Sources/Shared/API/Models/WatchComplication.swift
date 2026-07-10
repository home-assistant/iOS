import Foundation
import ObjectMapper
import RealmSwift
import UIKit
#if os(watchOS)
import ClockKit
#endif

public class WatchComplication: Object, ImmutableMappable {
    @objc public dynamic var identifier: String = UUID().uuidString
    @objc public dynamic var serverIdentifier: String?

    @objc private dynamic var rawFamily: String = ""
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

    @objc private dynamic var rawTemplate: String = ""
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

    @objc public dynamic var Data: [String: Any] {
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

    @objc fileprivate dynamic var complicationData: Data?
    @objc public dynamic var CreatedAt = Date()

    @objc public dynamic var name: String?
    public var displayName: String {
        name ?? Template.style
    }

    @objc public dynamic var IsPublic: Bool = true

    override public static func primaryKey() -> String? {
        "identifier"
    }

    override public static func ignoredProperties() -> [String] {
        ["Family", "Template"]
    }

    override public required init() {
        super.init()
    }

    public required init(map: ObjectMapper.Map) throws {
        // this is used for watch<->app syncing
        self.CreatedAt = try map.value("CreatedAt", using: DateTransform())
        super.init()
        self.Template = try map.value("Template")
        self.Data = try map.value("Data")
        self.Family = try map.value("Family")
        self.identifier = try map.value("identifier")
        self.name = try map.value("name")
        self.IsPublic = try map.value("IsPublic")
        self.serverIdentifier = try map.value("serverIdentifier")
    }

    public func mapping(map: ObjectMapper.Map) {
        Template >>> map["Template"]
        Data >>> map["Data"]
        CreatedAt >>> (map["CreatedAt"], DateTransform())
        Family >>> map["Family"]
        identifier >>> map["identifier"]
        name >>> map["name"]
        IsPublic >>> map["IsPublic"]
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
            guard let iconProvider else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateCircularSmallRingImage(
                imageProvider: iconProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleImage:
            guard let iconProvider else {
                return nil
            }
            return CLKComplicationTemplateCircularSmallSimpleImage(imageProvider: iconProvider)
        case .CircularSmallStackImage:
            guard let iconProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateCircularSmallStackImage(
                line1ImageProvider: iconProvider,
                line2TextProvider: textProvider
            )
        case .CircularSmallRingText:
            guard let textProvider = textDataProviders["InsideRing"] else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateCircularSmallRingText(
                textProvider: textProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleText:
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateCircularSmallSimpleText(textProvider: textProvider)
        case .CircularSmallStackText:
            guard let line1TextProvider = textDataProviders["Line1"],
                  let line2TextProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateCircularSmallStackText(
                line1TextProvider: line1TextProvider,
                line2TextProvider: line2TextProvider
            )
        case .ExtraLargeRingImage:
            guard let iconProvider else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateExtraLargeRingImage(
                imageProvider: iconProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleImage:
            guard let iconProvider else {
                return nil
            }
            return CLKComplicationTemplateExtraLargeSimpleImage(imageProvider: iconProvider)
        case .ExtraLargeStackImage:
            guard let iconProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateExtraLargeStackImage(
                line1ImageProvider: iconProvider,
                line2TextProvider: textProvider
            )
        case .ExtraLargeColumnsText:
            guard let row1Column1TextProvider = textDataProviders["Row1Column1"],
                  let row1Column2TextProvider = textDataProviders["Row1Column2"],
                  let row2Column1TextProvider = textDataProviders["Row2Column1"],
                  let row2Column2TextProvider = textDataProviders["Row2Column2"] else {
                return nil
            }
            let template = CLKComplicationTemplateExtraLargeColumnsText(
                row1Column1TextProvider: row1Column1TextProvider,
                row1Column2TextProvider: row1Column2TextProvider,
                row2Column1TextProvider: row2Column1TextProvider,
                row2Column2TextProvider: row2Column2TextProvider
            )
            template.column2Alignment = column2Alignment
            return template
        case .ExtraLargeRingText:
            guard let textProvider = textDataProviders["InsideRing"] else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateExtraLargeRingText(
                textProvider: textProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleText:
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateExtraLargeSimpleText(textProvider: textProvider)
        case .ExtraLargeStackText:
            guard let line1TextProvider = textDataProviders["Line1"],
                  let line2TextProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateExtraLargeStackText(
                line1TextProvider: line1TextProvider,
                line2TextProvider: line2TextProvider
            )
        case .ModularSmallRingImage:
            guard let iconProvider else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateModularSmallRingImage(
                imageProvider: iconProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleImage:
            guard let iconProvider else {
                return nil
            }
            return CLKComplicationTemplateModularSmallSimpleImage(imageProvider: iconProvider)
        case .ModularSmallStackImage:
            guard let iconProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateModularSmallStackImage(
                line1ImageProvider: iconProvider,
                line2TextProvider: textProvider
            )
        case .ModularSmallColumnsText:
            guard let row1Column1TextProvider = textDataProviders["Row1Column1"],
                  let row1Column2TextProvider = textDataProviders["Row1Column2"],
                  let row2Column1TextProvider = textDataProviders["Row2Column1"],
                  let row2Column2TextProvider = textDataProviders["Row2Column2"] else {
                return nil
            }
            let template = CLKComplicationTemplateModularSmallColumnsText(
                row1Column1TextProvider: row1Column1TextProvider,
                row1Column2TextProvider: row1Column2TextProvider,
                row2Column1TextProvider: row2Column1TextProvider,
                row2Column2TextProvider: row2Column2TextProvider
            )
            template.column2Alignment = column2Alignment
            return template
        case .ModularSmallRingText:
            guard let textProvider = textDataProviders["InsideRing"] else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateModularSmallRingText(
                textProvider: textProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleText:
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateModularSmallSimpleText(textProvider: textProvider)
        case .ModularSmallStackText:
            guard let line1TextProvider = textDataProviders["Line1"],
                  let line2TextProvider = textDataProviders["Line2"] else {
                return nil
            }
            return CLKComplicationTemplateModularSmallStackText(
                line1TextProvider: line1TextProvider,
                line2TextProvider: line2TextProvider
            )
        case .ModularLargeStandardBody:
            guard let headerTextProvider = textDataProviders["Header"],
                  let body1TextProvider = textDataProviders["Body1"] else {
                return nil
            }
            // body2TextProvider is optional, allowed to be nil and makes body1 wrap
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: headerTextProvider,
                body1TextProvider: body1TextProvider,
                body2TextProvider: textDataProviders["Body2"]
            )
        case .ModularLargeTallBody:
            guard let headerTextProvider = textDataProviders["Header"],
                  let bodyTextProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateModularLargeTallBody(
                headerTextProvider: headerTextProvider,
                bodyTextProvider: bodyTextProvider
            )
        case .ModularLargeColumns:
            guard let row1Column1TextProvider = textDataProviders["Row1Column1"],
                  let row1Column2TextProvider = textDataProviders["Row1Column2"],
                  let row2Column1TextProvider = textDataProviders["Row2Column1"],
                  let row2Column2TextProvider = textDataProviders["Row2Column2"] else {
                return nil
            }
            // only two rows are configurable; the initializer requires row 3, so pass empty providers to
            // keep it blank like the previous no-argument initializer did
            let template = CLKComplicationTemplateModularLargeColumns(
                row1Column1TextProvider: row1Column1TextProvider,
                row1Column2TextProvider: row1Column2TextProvider,
                row2Column1TextProvider: row2Column1TextProvider,
                row2Column2TextProvider: row2Column2TextProvider,
                row3Column1TextProvider: CLKSimpleTextProvider(text: ""),
                row3Column2TextProvider: CLKSimpleTextProvider(text: "")
            )
            template.column2Alignment = column2Alignment
            return template
        case .ModularLargeTable:
            guard let headerTextProvider = textDataProviders["Header"],
                  let row1Column1TextProvider = textDataProviders["Row1Column1"],
                  let row1Column2TextProvider = textDataProviders["Row1Column2"],
                  let row2Column1TextProvider = textDataProviders["Row2Column1"],
                  let row2Column2TextProvider = textDataProviders["Row2Column2"] else {
                return nil
            }
            let template = CLKComplicationTemplateModularLargeTable(
                headerTextProvider: headerTextProvider,
                row1Column1TextProvider: row1Column1TextProvider,
                row1Column2TextProvider: row1Column2TextProvider,
                row2Column1TextProvider: row2Column1TextProvider,
                row2Column2TextProvider: row2Column2TextProvider
            )
            template.column2Alignment = column2Alignment
            return template
        case .UtilitarianSmallFlat:
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            // imageProvider is optional
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: textProvider,
                imageProvider: iconProvider
            )
        case .UtilitarianSmallRingImage:
            guard let iconProvider else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateUtilitarianSmallRingImage(
                imageProvider: iconProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallRingText:
            guard let textProvider = textDataProviders["InsideRing"] else {
                return nil
            }
            let ringData = ringData
            let template = CLKComplicationTemplateUtilitarianSmallRingText(
                textProvider: textProvider,
                fillFraction: ringData.fraction,
                ringStyle: ringData.style
            )
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallSquare:
            guard let iconProvider else {
                return nil
            }
            return CLKComplicationTemplateUtilitarianSmallSquare(imageProvider: iconProvider)
        case .UtilitarianLargeFlat:
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            // imageProvider is optional
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: textProvider,
                imageProvider: iconProvider
            )
        case .GraphicCornerCircularImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            return CLKComplicationTemplateGraphicCornerCircularImage(imageProvider: iconProvider)
        case .GraphicCornerGaugeImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            guard let gaugeProvider else {
                return nil
            }
            // leading and trailing text providers are optional
            return CLKComplicationTemplateGraphicCornerGaugeImage(
                gaugeProvider: gaugeProvider,
                leadingTextProvider: textDataProviders["Leading"],
                trailingTextProvider: textDataProviders["Trailing"],
                imageProvider: iconProvider
            )
        case .GraphicCornerGaugeText:
            guard let gaugeProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Outer"] else {
                return nil
            }
            // leading and trailing text providers are optional
            return CLKComplicationTemplateGraphicCornerGaugeText(
                gaugeProvider: gaugeProvider,
                leadingTextProvider: textDataProviders["Leading"],
                trailingTextProvider: textDataProviders["Trailing"],
                outerTextProvider: textProvider
            )
        case .GraphicCornerStackText:
            guard let outerTextProvider = textDataProviders["Outer"],
                  let innerTextProvider = textDataProviders["Inner"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: innerTextProvider,
                outerTextProvider: outerTextProvider
            )
        case .GraphicCornerTextImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: textProvider,
                imageProvider: iconProvider
            )
        case .GraphicCircularImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularImage(imageProvider: iconProvider)
        case .GraphicCircularClosedGaugeImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            guard let gaugeProvider else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularClosedGaugeImage(
                gaugeProvider: gaugeProvider,
                imageProvider: iconProvider
            )
        case .GraphicCircularOpenGaugeImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            guard let gaugeProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularOpenGaugeImage(
                gaugeProvider: gaugeProvider,
                bottomImageProvider: iconProvider,
                centerTextProvider: textProvider
            )
        case .GraphicCircularClosedGaugeText:
            guard let gaugeProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Center"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularClosedGaugeText(
                gaugeProvider: gaugeProvider,
                centerTextProvider: textProvider
            )
        case .GraphicCircularOpenGaugeSimpleText:
            guard let gaugeProvider else {
                return nil
            }
            guard let centerTextProvider = textDataProviders["Center"],
                  let bottomTextProvider = textDataProviders["Bottom"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(
                gaugeProvider: gaugeProvider,
                bottomTextProvider: bottomTextProvider,
                centerTextProvider: centerTextProvider
            )
        case .GraphicCircularOpenGaugeRangeText:
            guard let gaugeProvider else {
                return nil
            }
            guard let centerTextProvider = textDataProviders["Center"],
                  let leadingTextProvider = textDataProviders["Leading"],
                  let trailingTextProvider = textDataProviders["Trailing"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicCircularOpenGaugeRangeText(
                gaugeProvider: gaugeProvider,
                leadingTextProvider: leadingTextProvider,
                trailingTextProvider: trailingTextProvider,
                centerTextProvider: centerTextProvider
            )
        case .GraphicBezelCircularText:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            // textProvider is optional
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: CLKComplicationTemplateGraphicCircularImage(imageProvider: iconProvider),
                textProvider: textDataProviders["Center"]
            )
        case .GraphicRectangularStandardBody:
            guard let headerTextProvider = textDataProviders["Header"],
                  let body1TextProvider = textDataProviders["Body1"] else {
                return nil
            }
            // body2TextProvider is optional
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: headerTextProvider,
                body1TextProvider: body1TextProvider,
                body2TextProvider: textDataProviders["Body2"]
            )
        case .GraphicRectangularTextGauge:
            guard let gaugeProvider else {
                return nil
            }
            guard let headerTextProvider = textDataProviders["Header"],
                  let body1TextProvider = textDataProviders["Body1"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicRectangularTextGauge(
                headerTextProvider: headerTextProvider,
                body1TextProvider: body1TextProvider,
                gaugeProvider: gaugeProvider
            )
        case .GraphicRectangularLargeImage:
            guard let iconProvider = fullColorImageProvider else {
                return nil
            }
            guard let textProvider = textDataProviders["Header"] else {
                return nil
            }
            return CLKComplicationTemplateGraphicRectangularLargeImage(
                textProvider: textProvider,
                imageProvider: iconProvider
            )
        }
    }

    #endif
}
