//
//  WatchComplication.swift
//  Shared
//
//  Created by Robert Trencheny on 9/26/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import ObjectMapper
import UIColor_Hex_Swift
#if os(watchOS)
import ClockKit
#endif

// swiftlint:disable:next type_body_length
public class WatchComplication: Object, ImmutableMappable {
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
            return self.Family.templates.first!
        }
        set {
            rawTemplate = newValue.rawValue
        }
    }
    @objc dynamic public var Data: [String: Any] {
        get {
            guard let dictionaryData = complicationData else {
                return [String: Any]()
            }
            do {
                let dict = try JSONSerialization.jsonObject(with: dictionaryData, options: []) as? [String: Any]
                return dict!
            } catch {
                return [String: Any]()
            }
        }

        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue, options: [])
                complicationData = data
            } catch {
                complicationData = nil
            }
        }
    }
    @objc fileprivate dynamic var complicationData: Data?
    @objc dynamic public var CreatedAt = Date()

    override public static func primaryKey() -> String? {
        return "rawFamily"
    }

    override public static func ignoredProperties() -> [String] {
        return ["Family", "Template"]
    }

    public required init() {

    }

    public required init(map: Map) throws {
        // this is used for watch<->app syncing
        self.CreatedAt = try map.value("CreatedAt", using: DateTransform())
        super.init()
        self.Template  = try map.value("Template")
        self.Data      = try map.value("Data")
        self.Family    = try map.value("Family")
    }

    public func mapping(map: Map) {
        Template  >>> map["Template"]
        Data      >>> map["Data"]
        CreatedAt >>> (map["CreatedAt"], DateTransform())
        Family    >>> map["Family"]
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
            case .textArea(let value): return "textArea,\(value)"
            case .gauge: return "gauge"
            case .ring: return "ring"
            }
        }
    }

    func renderedValues() -> [RenderedValueType: Any] {
        return (Data["rendered"] as? [String: Any] ?? [:])
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

        if let ringDict = self.Data["ring"] as? [String: String],
           let ringValue = ringDict["ring_value"], ringValue.containsJinjaTemplate {
            renders[.ring] = ringValue
        }

        return renders.mapKeys { $0.stringValue }
    }

    #if os(watchOS)

    private static func percentileNumber(from value: Any) -> Float? {
        switch value {
        case let value as String:
            // a bit more forgiving than Float(_:)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.number(from: value)?.floatValue
        case let value as Int:
            return Float(value)
        case let value as Double:
            return Float(value)
        case let value as Float:
            return value
        default:
            Current.Log.info("unsure how to float-ify \(type(of: value)), trying as a string")
            return Self.percentileNumber(from: String(describing: value))
        }
    }

    public var textDataProviders: [String: CLKTextProvider] {
        var providers: [String: CLKTextProvider] = [String: CLKTextProvider]()

        if let textAreas = self.Data["textAreas"] as? [String: [String: Any]] {
            let rendered = renderedValues()
            for (key, textArea) in textAreas {
                let renderedText = rendered[.textArea(key)].flatMap(String(describing:))

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
        if let iconDict = self.Data["icon"] as? [String: String], let iconName = iconDict["icon"],
            let iconColor = iconDict["icon_color"], let iconSize = self.Template.imageSize {
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
        if let iconDict = self.Data["icon"] as? [String: String], let iconName = iconDict["icon"],
            let iconColor = iconDict["icon_color"], let iconSize = self.Template.imageSize {
            let icon = MaterialDesignIcons(named: iconName)
            let image = icon.image(ofSize: iconSize, color: UIColor(iconColor))
            return CLKFullColorImageProvider(fullColorImage: image)
        }

        return nil
    }

    public var gaugeProvider: CLKSimpleGaugeProvider? {
        guard let info = self.Data["gauge"] as? [String: String] else {
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func CLKComplicationTemplate(family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        if self.Template.groupMember != ComplicationGroupMember(family: family) {
            Current.Log.warning("Would have returned template (\(self.Template)) outside expected family (\(family)")
            return nil
        }
        switch self.Template {
        case .CircularSmallRingImage:
            let template = CLKComplicationTemplateCircularSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleImage:
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .CircularSmallStackImage:
            let template = CLKComplicationTemplateCircularSmallStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .CircularSmallRingText:
            let template = CLKComplicationTemplateCircularSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .CircularSmallSimpleText:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .CircularSmallStackText:
            let template = CLKComplicationTemplateCircularSmallStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ExtraLargeRingImage:
            let template = CLKComplicationTemplateExtraLargeRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleImage:
            let template = CLKComplicationTemplateExtraLargeSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ExtraLargeStackImage:
            let template = CLKComplicationTemplateExtraLargeStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ExtraLargeColumnsText:
            let template = CLKComplicationTemplateExtraLargeColumnsText()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            template.column2Alignment = column2Alignment
            return template
        case .ExtraLargeRingText:
            let template = CLKComplicationTemplateExtraLargeRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ExtraLargeSimpleText:
            let template = CLKComplicationTemplateExtraLargeSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .ExtraLargeStackText:
            let template = CLKComplicationTemplateExtraLargeStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularSmallRingImage:
            let template = CLKComplicationTemplateModularSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleImage:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ModularSmallStackImage:
            let template = CLKComplicationTemplateModularSmallStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularSmallColumnsText:
            let template = CLKComplicationTemplateModularSmallColumnsText()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            template.column2Alignment = column2Alignment
            return template
        case .ModularSmallRingText:
            let template = CLKComplicationTemplateModularSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .ModularSmallSimpleText:
            let template = CLKComplicationTemplateModularSmallSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .ModularSmallStackText:
            let template = CLKComplicationTemplateModularSmallStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularLargeStandardBody:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            }
            return template
        case .ModularLargeTallBody:
            let template = CLKComplicationTemplateModularLargeTallBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.bodyTextProvider = textProvider
            }
            return template
        case .ModularLargeColumns:
            let template = CLKComplicationTemplateModularLargeColumns()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            template.column2Alignment = column2Alignment
            return template
        case .ModularLargeTable:
            let template = CLKComplicationTemplateModularLargeTable()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            template.column2Alignment = column2Alignment
            return template
        case .UtilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .UtilitarianSmallRingImage:
            let template = CLKComplicationTemplateUtilitarianSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallRingText:
            let template = CLKComplicationTemplateUtilitarianSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            let ringData = self.ringData
            template.fillFraction = ringData.fraction
            template.ringStyle = ringData.style
            template.tintColor = ringData.color
            return template
        case .UtilitarianSmallSquare:
            let template = CLKComplicationTemplateUtilitarianSmallSquare()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            } else {
                return nil
            }
            return template
        case .UtilitarianLargeFlat:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicCornerCircularImage:
            let template = CLKComplicationTemplateGraphicCornerCircularImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .GraphicCornerGaugeImage:
            let template = CLKComplicationTemplateGraphicCornerGaugeImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicCornerGaugeText:
            let template = CLKComplicationTemplateGraphicCornerGaugeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicCornerStackText:
            let template = CLKComplicationTemplateGraphicCornerStackText()
            if let textProvider = self.textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Inner"] {
                template.innerTextProvider = textProvider
            }
            return template
        case .GraphicCornerTextImage:
            let template = CLKComplicationTemplateGraphicCornerTextImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicCircularImage:
            let template = CLKComplicationTemplateGraphicCircularImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .GraphicCircularClosedGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            return template
        case .GraphicCircularOpenGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeImage()
            if let iconProvider = self.fullColorImageProvider {
                template.bottomImageProvider = iconProvider
            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            return template
        case .GraphicCircularClosedGaugeText:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            guard let textProvider = self.textDataProviders["Center"] else {
                Current.Log.warning("No center text set for GraphicCircularClosedGaugeText, returning nil!")
                return nil
            }
            template.centerTextProvider = textProvider
            return template
        case .GraphicCircularOpenGaugeSimpleText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Bottom"] {
                template.bottomTextProvider = textProvider
            }
            return template
        case .GraphicCircularOpenGaugeRangeText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicBezelCircularText:
            let template = CLKComplicationTemplateGraphicBezelCircularText()
            if let iconProvider = self.fullColorImageProvider {
                template.circularTemplate = with(CLKComplicationTemplateGraphicCircularImage()) {
                    $0.imageProvider = iconProvider
                }
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicRectangularStandardBody:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            }
            return template
        case .GraphicRectangularTextGauge:
            let template = CLKComplicationTemplateGraphicRectangularTextGauge()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            return template
        case .GraphicRectangularLargeImage:
            let template = CLKComplicationTemplateGraphicRectangularLargeImage()
            if let iconProvider = self.fullColorImageProvider {
                template.imageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Header"] {
                template.textProvider = textProvider
            }
            return template
        }
    }

    #endif
// swiftlint:disable:next file_length
}
